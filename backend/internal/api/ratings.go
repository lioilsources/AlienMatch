package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func (h *handler) routesRatings(mux *http.ServeMux) {
	mux.HandleFunc("GET /v1/stars", h.withUser(h.stars))
	mux.HandleFunc("PUT /v1/stars/{id}/rating", h.withUser(h.rateStar))
	mux.HandleFunc("GET /v1/me/face-stats", h.withUser(h.faceStats))
	mux.HandleFunc("GET /v1/me/liked", h.withUser(h.liked))
}

// StarCard is one face in the rating deck. Like the radar, no mood numbers.
type StarCard struct {
	UserID  string `json:"user_id"`
	PhotoID string `json:"photo_id"`
	Level   string `json:"level"`
	Trend   string `json:"trend"`
	Rating  *int   `json:"rating"`
}

func (h *handler) stars(w http.ResponseWriter, r *http.Request) {
	st, err := h.svc.Stars(r.Context(), userOf(r))
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeJSON(w, http.StatusOK, map[string]any{"off_radar": true, "stars": []StarCard{}})
		return
	case err != nil:
		h.internal(w, "stars", err)
		return
	}
	out := make([]StarCard, len(st))
	for i, s := range st {
		out[i] = StarCard{UserID: s.UserID, PhotoID: s.PhotoID, Level: string(s.Level), Trend: string(s.Trend), Rating: s.Rating}
	}
	writeJSON(w, http.StatusOK, map[string]any{"off_radar": false, "stars": out})
}

type rateRequest struct {
	Value *int `json:"value"`
}

func (h *handler) rateStar(w http.ResponseWriter, r *http.Request) {
	var req rateRequest
	if !decode(w, r, &req) {
		return
	}
	if req.Value == nil {
		writeErr(w, http.StatusBadRequest, "value required")
		return
	}
	err := h.svc.Rate(r.Context(), userOf(r), r.PathValue("id"), *req.Value)
	switch {
	case errors.Is(err, service.ErrBadRating):
		writeErr(w, http.StatusBadRequest, "value must be -1, 0 or 1")
	case errors.Is(err, service.ErrNotAStar):
		writeErr(w, http.StatusNotFound, "not a star on your radar")
	case err != nil:
		h.internal(w, "rate", err)
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

// FaceStatJSON is the feedback on one of my faces. Dislikes is null while
// the owner is in LOW.
type FaceStatJSON struct {
	PhotoID  string    `json:"photo_id"`
	Current  bool      `json:"current"`
	Likes    int       `json:"likes"`
	Dislikes *int      `json:"dislikes"`
	Seen     int       `json:"seen"`
	Since    time.Time `json:"since"`
}

func (h *handler) faceStats(w http.ResponseWriter, r *http.Request) {
	res, err := h.svc.MyFaceStats(r.Context(), userOf(r))
	if err != nil {
		h.internal(w, "face stats", err)
		return
	}
	out := make([]FaceStatJSON, len(res.Faces))
	for i, f := range res.Faces {
		j := FaceStatJSON{PhotoID: service.PhotoID(f.PhotoKey), Current: f.PhotoKey == res.CurrentKey, Likes: f.Likes, Seen: f.Seen, Since: f.FirstAt}
		if !res.DislikesHidden {
			d := f.Dislikes
			j.Dislikes = &d
		}
		out[i] = j
	}
	writeJSON(w, http.StatusOK, map[string]any{"faces": out, "dislikes_hidden": res.DislikesHidden})
}

// LikedJSON is someone whose face I liked.
type LikedJSON struct {
	UserID  string    `json:"user_id"`
	At      time.Time `json:"at"`
	OnRadar bool      `json:"on_radar"`
}

func (h *handler) liked(w http.ResponseWriter, r *http.Request) {
	ls, err := h.svc.MyLiked(r.Context(), userOf(r))
	if err != nil {
		h.internal(w, "liked", err)
		return
	}
	out := make([]LikedJSON, len(ls))
	for i, l := range ls {
		out[i] = LikedJSON{UserID: l.UserID, At: l.At, OnRadar: l.OnRadar}
	}
	writeJSON(w, http.StatusOK, map[string]any{"liked": out})
}
