// Package api is the HTTP surface of mimo-api.
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

	"github.com/lioilsources/Mimo/backend/internal/matching"
	"github.com/lioilsources/Mimo/backend/internal/mood"
	"github.com/lioilsources/Mimo/backend/internal/service"
)

// Authenticator resolves the calling user. Real auth (magic link, Apple,
// Google) comes in phase 2; DevAuth exists only for local development.
type Authenticator interface {
	UserID(r *http.Request) (string, bool)
}

// DevAuth trusts the X-Mimo-User header. Never enable in production.
type DevAuth struct{}

func (DevAuth) UserID(r *http.Request) (string, bool) {
	u := r.Header.Get("X-Mimo-User")
	return u, u != ""
}

// Handler builds the router.
func Handler(svc *service.Service, auth Authenticator, log *slog.Logger) http.Handler {
	h := &handler{svc: svc, auth: auth, log: log}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("POST /v1/checkins", h.withUser(h.checkin))
	mux.HandleFunc("GET /v1/radar", h.withUser(h.radar))
	return mux
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
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "bad json")
		return
	}
	res, err := h.svc.Checkin(r.Context(), userOf(r), req.Self, req.VL)
	switch {
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
}

func (h *handler) radar(w http.ResponseWriter, r *http.Request) {
	cs, err := h.svc.Radar(r.Context(), userOf(r))
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeJSON(w, http.StatusOK, map[string]any{"off_radar": true, "planets": []RadarPlanet{}})
		return
	case err != nil:
		h.log.Error("radar", "err", err)
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	out := make([]RadarPlanet, 0, len(cs))
	for _, c := range cs {
		out = append(out, RadarPlanet{
			UserID: c.Profile.ID, Kind: c.Result.String(),
			Level: c.Profile.State.Level, Trend: c.Profile.State.Trend,
			Intents: c.SharedIntents,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"off_radar": false, "planets": out})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}
