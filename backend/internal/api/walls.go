package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/coder/websocket"

	"github.com/lioilsources/AlienMatch/backend/internal/realtime"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Realtime bundles the hub and ticket store for the wall endpoints.
type Realtime struct {
	Hub     *realtime.Hub
	Tickets *realtime.Tickets
	// OriginPatterns for browser clients (Flutter web); mobile sends no Origin.
	OriginPatterns []string
}

func (h *handler) routesWalls(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/waves", h.withUser(h.wave))
	mux.HandleFunc("GET /v1/matches", h.withUser(h.matches))
	mux.HandleFunc("GET /v1/walls/{id}/stickers", h.withUser(h.stickers))
	mux.HandleFunc("POST /v1/walls/{id}/stickers", h.withUser(h.stick))
	mux.HandleFunc("PATCH /v1/walls/{id}/stickers/{sid}", h.withUser(h.move))
	mux.HandleFunc("DELETE /v1/walls/{id}/stickers/{sid}", h.withUser(h.peel))
	mux.HandleFunc("POST /v1/walls/{id}/ticket", h.withUser(h.ticket))
	mux.HandleFunc("GET /v1/walls/{id}/ws", h.ws)
	mux.HandleFunc("POST /v1/reports", h.withUser(h.report))
}

func (h *handler) wallErr(w http.ResponseWriter, what string, err error) {
	switch {
	case errors.Is(err, service.ErrNotOnRadar):
		writeErr(w, http.StatusForbidden, "not on your radar")
	case errors.Is(err, service.ErrWaveLimit):
		writeErr(w, http.StatusTooManyRequests, "daily wave limit")
	case errors.Is(err, service.ErrNotMember):
		writeErr(w, http.StatusNotFound, "not found")
	case errors.Is(err, service.ErrNotYours):
		writeErr(w, http.StatusForbidden, "not your sticker")
	case errors.Is(err, service.ErrBadSticker), errors.Is(err, service.ErrSelfReport):
		writeErr(w, http.StatusBadRequest, "bad request")
	default:
		h.internal(w, what, err)
	}
}

func pathID(r *http.Request, name string) (int64, bool) {
	v, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	return v, err == nil && v > 0
}

func (h *handler) wave(w http.ResponseWriter, r *http.Request) {
	var req struct {
		To string `json:"to"`
	}
	if !decode(w, r, &req) {
		return
	}
	res, err := h.svc.Wave(r.Context(), userOf(r), req.To)
	if err != nil {
		h.wallErr(w, "wave", err)
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (h *handler) matches(w http.ResponseWriter, r *http.Request) {
	ms, err := h.svc.Matches(r.Context(), userOf(r))
	if err != nil {
		h.wallErr(w, "matches", err)
		return
	}
	if ms == nil {
		ms = []service.MatchView{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"matches": ms})
}

func (h *handler) stickers(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r, "id")
	if !ok {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	after, _ := strconv.ParseInt(r.URL.Query().Get("after"), 10, 64)
	st, err := h.svc.Stickers(r.Context(), userOf(r), id, after)
	if err != nil {
		h.wallErr(w, "stickers", err)
		return
	}
	if st == nil {
		st = []service.Sticker{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"stickers": st})
}

func (h *handler) stick(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r, "id")
	if !ok {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	var in service.StickerInput
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, service.MaxInkBytes+4<<10))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		writeErr(w, http.StatusBadRequest, "bad json")
		return
	}
	st, err := h.svc.Stick(r.Context(), userOf(r), id, in)
	if err != nil {
		h.wallErr(w, "stick", err)
		return
	}
	writeJSON(w, http.StatusCreated, st)
}

func (h *handler) move(w http.ResponseWriter, r *http.Request) {
	id, ok1 := pathID(r, "id")
	sid, ok2 := pathID(r, "sid")
	if !ok1 || !ok2 {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	var req struct {
		X, Y, Rotation, Scale float64
		Z                     int
	}
	if !decode(w, r, &req) {
		return
	}
	if err := h.svc.Move(r.Context(), userOf(r), id, sid, req.X, req.Y, req.Rotation, req.Scale, req.Z); err != nil {
		h.wallErr(w, "move", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *handler) peel(w http.ResponseWriter, r *http.Request) {
	id, ok1 := pathID(r, "id")
	sid, ok2 := pathID(r, "sid")
	if !ok1 || !ok2 {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	if err := h.svc.Peel(r.Context(), userOf(r), id, sid); err != nil {
		h.wallErr(w, "peel", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ReportRequest: a sticker (hidden at once) and/or a user; block ends the wall.
type ReportRequest struct {
	StickerID int64  `json:"sticker_id,omitempty"`
	UserID    string `json:"user_id,omitempty"`
	Block     bool   `json:"block"`
}

func (h *handler) report(w http.ResponseWriter, r *http.Request) {
	var req ReportRequest
	if !decode(w, r, &req) {
		return
	}
	me := userOf(r)
	var err error
	switch {
	case req.StickerID > 0:
		err = h.svc.ReportSticker(r.Context(), me, req.StickerID, req.Block)
	case req.UserID != "" && req.Block:
		err = h.svc.BlockUser(r.Context(), me, req.UserID)
	case req.UserID != "":
		err = h.svc.Walls.Report(r.Context(), me, &req.UserID, nil, false, h.svc.Now())
	default:
		writeErr(w, http.StatusBadRequest, "nothing to report")
		return
	}
	if err != nil {
		h.wallErr(w, "report", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *handler) ticket(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r, "id")
	if !ok || h.rt == nil {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	if _, err := h.svc.Walls.WallMember(r.Context(), id, userOf(r)); err != nil {
		h.wallErr(w, "ticket", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"ticket": h.rt.Tickets.Issue(userOf(r), id)})
}

// ws streams wall events. Clients write through REST; this is push only.
func (h *handler) ws(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r, "id")
	if !ok || h.rt == nil {
		writeErr(w, http.StatusBadRequest, "bad id")
		return
	}
	user, ok := h.rt.Tickets.Redeem(r.URL.Query().Get("ticket"), id)
	if !ok {
		writeErr(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if _, err := h.svc.Walls.WallMember(r.Context(), id, user); err != nil {
		h.wallErr(w, "ws", err)
		return
	}
	c, err := websocket.Accept(w, r, &websocket.AcceptOptions{OriginPatterns: h.rt.OriginPatterns})
	if err != nil {
		return
	}
	defer c.CloseNow()
	events, cancel := h.rt.Hub.Subscribe(id)
	defer cancel()
	ctx := c.CloseRead(r.Context())
	ping := time.NewTicker(25 * time.Second)
	defer ping.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case ev, ok := <-events:
			if !ok {
				return
			}
			b, _ := json.Marshal(ev)
			wctx, done := context.WithTimeout(ctx, 5*time.Second)
			err := c.Write(wctx, websocket.MessageText, b)
			done()
			if err != nil {
				return
			}
			if ev.Type == "ended" {
				c.Close(websocket.StatusNormalClosure, "ended")
				return
			}
		case <-ping.C:
			pctx, done := context.WithTimeout(ctx, 5*time.Second)
			err := c.Ping(pctx)
			done()
			if err != nil {
				return
			}
		}
	}
}
