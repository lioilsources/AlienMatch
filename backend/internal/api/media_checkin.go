package api

import (
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Limits for a 10-20 s check-in: up to 3 key frames and the voice track.
const (
	maxFrames     = 3
	maxFrameBytes = 600 << 10
	maxAudioBytes = 2 << 20
	maxMediaBody  = maxFrames*maxFrameBytes + maxAudioBytes + 64<<10
)

func (h *handler) routesMedia(mux *http.ServeMux) {
	mux.HandleFunc("GET /v1/config", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"mood_scoring": h.svc.MoodScoringAvailable(), "regions": service.Regions})
	})
	mux.HandleFunc("POST /v1/checkins/media", h.withUser(h.mediaCheckin))
	// Opening the check-in screen asks SPARK to start the models on demand.
	mux.HandleFunc("POST /v1/checkins/warmup", h.withUser(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"scoring": h.svc.WarmUp(r.Context(), userOf(r))})
	}))
}

// mediaCheckin reads multipart parts straight into memory. Deliberately not
// ParseMultipartForm: it spills large parts into temp files on disk, and
// check-in media must never touch a disk.
func (h *handler) mediaCheckin(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxMediaBody)
	mr, err := r.MultipartReader()
	if err != nil {
		writeErr(w, http.StatusBadRequest, "multipart expected")
		return
	}
	var in moodscore.Input
	var mode service.Mode
	self := -1.0
	for {
		p, err := mr.NextPart()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			writeErr(w, http.StatusBadRequest, "bad multipart")
			return
		}
		read := func(limit int64) ([]byte, bool) {
			b, err := io.ReadAll(io.LimitReader(p, limit+1))
			return b, err == nil && int64(len(b)) <= limit
		}
		switch p.FormName() {
		case "mode":
			b, ok := read(16)
			if !ok {
				writeErr(w, http.StatusBadRequest, "bad mode")
				return
			}
			mode = service.Mode(b)
		case "self":
			b, ok := read(32)
			v, err := strconv.ParseFloat(string(b), 64)
			if !ok || err != nil {
				writeErr(w, http.StatusBadRequest, "bad self")
				return
			}
			self = v
		case "lang":
			b, _ := read(16)
			in.Lang = string(b)
		case "frame":
			b, ok := read(maxFrameBytes)
			if !ok || len(in.Frames) >= maxFrames || len(b) < 3 || b[0] != 0xFF || b[1] != 0xD8 {
				writeErr(w, http.StatusBadRequest, "bad frame")
				return
			}
			in.Frames = append(in.Frames, b)
		case "audio":
			b, ok := read(maxAudioBytes)
			if !ok || in.Audio != nil {
				writeErr(w, http.StatusBadRequest, "bad audio")
				return
			}
			in.Audio = b
		default:
			writeErr(w, http.StatusBadRequest, "unknown part")
			return
		}
		p.Close()
	}
	if mode == service.ModeVideo && len(in.Frames) == 0 {
		writeErr(w, http.StatusBadRequest, "video check-in needs frames")
		return
	}
	res, err := h.svc.CheckinWithMedia(r.Context(), userOf(r), mode, self, in)
	switch {
	case errors.Is(err, service.ErrBadMode):
		writeErr(w, http.StatusBadRequest, "bad mode")
		return
	case errors.Is(err, mood.ErrOutOfRange):
		writeErr(w, http.StatusBadRequest, "score out of range")
		return
	case err != nil:
		h.internal(w, "media checkin", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"level": res.State.Level, "trend": res.State.Trend,
		"support_card": res.SupportPause, "ask_again_soon": res.AskAgain, "signal": res.Signal,
		"signal_pending": res.Pending,
	})
}
