package api

import (
	"errors"
	"net/http"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func (h *handler) routesFlyby(mux *http.ServeMux) {
	mux.HandleFunc("PUT /v1/me/flyby", h.withUser(h.setFlyby))
	mux.HandleFunc("POST /v1/flyby/keys", h.withUser(h.uploadTEK))
	mux.HandleFunc("GET /v1/flyby/keys", h.withUser(h.downloadTEKs))
	mux.HandleFunc("POST /v1/flyby/waves", h.withUser(h.waveFlyby))
}

func (h *handler) flybyErr(w http.ResponseWriter, what string, err error) {
	switch {
	case errors.Is(err, service.ErrFlybyOff):
		writeErr(w, http.StatusForbidden, "fly-by is off")
	case errors.Is(err, service.ErrBadTEK), errors.Is(err, service.ErrNotYesterday):
		writeErr(w, http.StatusBadRequest, "bad key")
	default:
		h.internal(w, what, err)
	}
}

func (h *handler) setFlyby(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Enabled bool `json:"enabled"`
	}
	if !decode(w, r, &req) {
		return
	}
	if err := h.svc.SetFlyby(r.Context(), userOf(r), req.Enabled); err != nil {
		h.flybyErr(w, "set flyby", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// TEKUpload: yesterday's key only. []byte is base64 in JSON.
type TEKUpload struct {
	Day string `json:"day"`
	TEK []byte `json:"tek"`
}

func (h *handler) uploadTEK(w http.ResponseWriter, r *http.Request) {
	var req TEKUpload
	if !decode(w, r, &req) {
		return
	}
	if err := h.svc.UploadTEK(r.Context(), userOf(r), req.Day, req.TEK); err != nil {
		h.flybyErr(w, "upload tek", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *handler) downloadTEKs(w http.ResponseWriter, r *http.Request) {
	keys, err := h.svc.DownloadTEKs(r.Context(), userOf(r))
	if err != nil {
		h.flybyErr(w, "download teks", err)
		return
	}
	if keys == nil {
		keys = []service.DayKey{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"keys": keys})
}

// FlybyWave: "I was near key K on day D and want to meet them".
type FlybyWave struct {
	Day  string `json:"day"`
	TEK  []byte `json:"tek"`
	Kind string `json:"kind"`
}

func (h *handler) waveFlyby(w http.ResponseWriter, r *http.Request) {
	var req FlybyWave
	if !decode(w, r, &req) {
		return
	}
	if err := h.svc.WaveFlyby(r.Context(), userOf(r), req.TEK, req.Day, req.Kind); err != nil {
		h.flybyErr(w, "flyby wave", err)
		return
	}
	// Same answer whether the key exists or not: nothing is revealed.
	w.WriteHeader(http.StatusAccepted)
}
