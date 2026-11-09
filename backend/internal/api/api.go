// Package api is the HTTP surface of alienmatch-api.
//
// Product rule: no endpoint accepts free text from users except the moderated
// nickname. Messages are stickers (media keys), never strings.
package api

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"slices"
	"strings"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Authenticator resolves the calling user. BearerAuth is the real one
// (anonymous account tokens); DevAuth exists only for local development.
type Authenticator interface {
	UserID(r *http.Request) (string, bool)
}

// DevAuth trusts the X-AlienMatch-User header. Never enable in production.
type DevAuth struct{}

func (DevAuth) UserID(r *http.Request) (string, bool) {
	u := r.Header.Get("X-AlienMatch-User")
	return u, u != ""
}

// BearerAuth resolves "Authorization: Bearer <token>" via the token hash.
type BearerAuth struct {
	Lookup func(ctx context.Context, tokenHash []byte) (string, error)
}

func (b BearerAuth) UserID(r *http.Request) (string, bool) {
	tok, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok || len(tok) < 32 || len(tok) > 128 {
		return "", false
	}
	id, err := b.Lookup(r.Context(), service.HashToken(tok))
	return id, err == nil && id != ""
}

// Handler builds the router.
func Handler(svc *service.Service, auth Authenticator, log *slog.Logger) http.Handler {
	h := &handler{svc: svc, auth: auth, log: log}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("POST /v1/checkins", h.withUser(h.checkin))
	mux.HandleFunc("GET /v1/radar", h.withUser(h.radar))
	mux.HandleFunc("GET /v1/places", h.withUser(h.searchPlaces))
	mux.HandleFunc("PUT /v1/me/places", h.withUser(h.setPlaces))
	mux.HandleFunc("GET /v1/me/location-data", h.withUser(h.locationData))
	mux.HandleFunc("GET /v1/regions", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"regions": service.Regions})
	})
	mux.HandleFunc("POST /v1/accounts", h.createAccount)
	mux.HandleFunc("GET /v1/me", h.withUser(h.me))
	mux.HandleFunc("DELETE /v1/me", h.withUser(h.deleteMe))
	mux.HandleFunc("PUT /v1/me/profile", h.withUser(h.saveProfile))
	mux.HandleFunc("PUT /v1/me/photo", h.withUser(h.setPhoto))
	mux.HandleFunc("GET /v1/users/{id}/photo", h.withUser(h.photo))
	return noCoordinates(mux)
}

type handler struct {
	svc  *service.Service
	auth Authenticator
	log  *slog.Logger
}

type userKey struct{}

func (h *handler) withUser(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		u, ok := h.auth.UserID(r)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userKey{}, u)))
	}
}

func userOf(r *http.Request) string { return r.Context().Value(userKey{}).(string) }

// CheckinRequest comes from the mood-worker result plus the self scale.
// The app never uploads media here; video/audio go to SPARK and are discarded.
type CheckinRequest struct {
	Mode service.Mode  `json:"mode"` // video (default) | voice
	Self float64       `json:"self"`
	VL   *mood.VLScore `json:"vl,omitempty"`
}

// CheckinResponse deliberately exposes no numbers: the app renders an aura.
type CheckinResponse struct {
	Level        mood.Level `json:"level"`
	Trend        mood.Trend `json:"trend"`
	SupportCard  bool       `json:"support_card"`
	AskAgainSoon bool       `json:"ask_again_soon"`
}

func (h *handler) checkin(w http.ResponseWriter, r *http.Request) {
	var req CheckinRequest
	if !decode(w, r, &req) {
		return
	}
	if req.Mode == "" {
		req.Mode = service.ModeVideo
	}
	res, err := h.svc.Checkin(r.Context(), userOf(r), req.Mode, req.Self, req.VL)
	switch {
	case errors.Is(err, service.ErrBadMode):
		writeErr(w, http.StatusBadRequest, "bad mode")
		return
	case errors.Is(err, mood.ErrOutOfRange):
		writeErr(w, http.StatusBadRequest, "score out of range")
		return
	case errors.Is(err, service.ErrNotFound):
		writeErr(w, http.StatusNotFound, "not found")
		return
	case err != nil:
		h.log.Error("checkin", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	writeJSON(w, http.StatusOK, CheckinResponse{
		Level: res.State.Level, Trend: res.State.Trend,
		SupportCard: res.SupportPause, AskAgainSoon: res.AskAgain,
	})
}

// RadarPlanet is one visible profile on the star map.
type RadarPlanet struct {
	UserID  string            `json:"user_id"`
	Kind    string            `json:"kind"` // match | encourage
	Level   mood.Level        `json:"level"`
	Trend   mood.Trend        `json:"trend"`
	Intents []matching.Intent `json:"intents"`
	// Star is one of the caller's own places shared with this planet (k >= 5).
	// The client already knows its own places; nothing about the other
	// user's list is revealed beyond this one id.
	Star       string `json:"star,omitempty"`
	WeakSignal bool   `json:"weak_signal,omitempty"`
}

func (h *handler) radar(w http.ResponseWriter, r *http.Request) {
	es, err := h.svc.Radar(r.Context(), userOf(r))
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeJSON(w, http.StatusOK, map[string]any{"off_radar": true, "planets": []RadarPlanet{}})
		return
	case err != nil:
		h.log.Error("radar", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	out := make([]RadarPlanet, 0, len(es))
	for _, e := range es {
		c := e.Candidate
		out = append(out, RadarPlanet{
			UserID: c.Profile.ID, Kind: c.Result.String(),
			Level: c.Profile.State.Level, Trend: c.Profile.State.Trend,
			Intents: c.SharedIntents,
			Star:    e.Constellation.Star, WeakSignal: e.Constellation.WeakSignal,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"off_radar": false, "planets": out})
}

func (h *handler) searchPlaces(w http.ResponseWriter, r *http.Request) {
	ps, err := h.svc.SearchPlaces(r.Context(), userOf(r), r.URL.Query().Get("q"))
	switch {
	case errors.Is(err, service.ErrShortQuery):
		writeErr(w, http.StatusBadRequest, "query too short")
		return
	case errors.Is(err, service.ErrNotFound):
		writeErr(w, http.StatusNotFound, "not found")
		return
	case err != nil:
		h.log.Error("search places", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	if ps == nil {
		ps = []service.CatalogPlace{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"places": ps})
}

// SetPlacesRequest replaces the caller's constellation. Only catalog ids.
type SetPlacesRequest struct {
	PlaceIDs []string `json:"place_ids"`
}

func (h *handler) setPlaces(w http.ResponseWriter, r *http.Request) {
	var req SetPlacesRequest
	if !decode(w, r, &req) {
		return
	}
	err := h.svc.SetPlaces(r.Context(), userOf(r), req.PlaceIDs)
	switch {
	case errors.Is(err, places.ErrTooMany):
		writeErr(w, http.StatusBadRequest, "too many places")
	case errors.Is(err, places.ErrBadID), errors.Is(err, service.ErrUnknownPlace):
		writeErr(w, http.StatusBadRequest, "unknown place")
	case err != nil:
		h.log.Error("set places", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

func (h *handler) locationData(w http.ResponseWriter, r *http.Request) {
	d, err := h.svc.LocationData(r.Context(), userOf(r))
	if err != nil {
		h.log.Error("location data", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	writeJSON(w, http.StatusOK, d)
}

// decode reads a small JSON body strictly: unknown fields (e.g. "lat") are rejected.
func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		writeErr(w, http.StatusBadRequest, "bad json")
		return false
	}
	return true
}

// coordinateParams are query keys that must never reach the server.
var coordinateParams = []string{"lat", "lon", "lng", "latitude", "longitude", "geohash", "gps", "location", "coords"}

// noCoordinates rejects requests that try to send a position in the query
// string. JSON bodies are covered by strict decoding. Defense in depth for
// Prompts/01-GPS.md §0.1: the server never receives a GPS coordinate.
func noCoordinates(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		for k := range q {
			if slices.Contains(coordinateParams, strings.ToLower(k)) {
				writeErr(w, http.StatusBadRequest, "coordinates are not accepted")
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}
