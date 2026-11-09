package api

import (
	"crypto/subtle"
	_ "embed"
	"errors"
	"net/http"
	"strings"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

//go:embed static/admin.html
var adminPage []byte

// WithAdmin enables the moderation queue behind a separate admin token.
// Expose /admin and /v1/admin/* only on the internal network (Caddy).
func WithAdmin(token string) Option { return func(h *handler) { h.adminToken = token } }

func (h *handler) routesAdmin(mux *http.ServeMux) {
	if h.adminToken == "" || h.svc.Admin == nil {
		return // disabled: routes do not exist
	}
	mux.HandleFunc("GET /admin", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' blob:")
		w.Header().Set("X-Frame-Options", "DENY")
		_, _ = w.Write(adminPage)
	})
	mux.HandleFunc("GET /v1/admin/reports", h.withAdmin(h.adminReports))
	mux.HandleFunc("POST /v1/admin/reports/{id}/resolve", h.withAdmin(h.adminResolve))
	mux.HandleFunc("GET /v1/admin/users/{id}/photo", h.withAdmin(h.photo))
}

func (h *handler) withAdmin(next http.HandlerFunc) http.HandlerFunc {
	want := []byte(h.adminToken)
	return func(w http.ResponseWriter, r *http.Request) {
		got, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || subtle.ConstantTimeCompare([]byte(got), want) != 1 {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next(w, r)
	}
}

func (h *handler) adminReports(w http.ResponseWriter, r *http.Request) {
	rs, err := h.svc.OpenReports(r.Context())
	if err != nil {
		h.internal(w, "admin reports", err)
		return
	}
	if rs == nil {
		rs = []service.ReportView{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"reports": rs})
}

func (h *handler) adminResolve(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r, "id")
	if !ok {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	var req struct {
		Action string `json:"action"`
	}
	if !decode(w, r, &req) {
		return
	}
	err := h.svc.ResolveReport(r.Context(), id, req.Action)
	switch {
	case errors.Is(err, service.ErrBadAction):
		writeErr(w, http.StatusBadRequest, "bad action")
	case err != nil:
		h.internal(w, "admin resolve", err)
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}
