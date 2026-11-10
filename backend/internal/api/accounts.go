package api

import (
	"errors"
	"io"
	"net/http"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// CreateAccountRequest: no e-mail, no phone, no name.
type CreateAccountRequest struct {
	AdultConfirmed bool `json:"adult_confirmed"` // 18+ checkbox, mandatory
	MoodConsent    bool `json:"mood_consent"`    // GDPR art. 9, separate and optional
}

// CreateAccountResponse carries the only copy of the token; the server keeps a hash.
type CreateAccountResponse struct {
	UserID string `json:"user_id"`
	Token  string `json:"token"`
}

func (h *handler) createAccount(w http.ResponseWriter, r *http.Request) {
	var req CreateAccountRequest
	if !decode(w, r, &req) {
		return
	}
	id, tok, err := h.svc.CreateAccount(r.Context(), req.AdultConfirmed, req.MoodConsent)
	switch {
	case errors.Is(err, service.ErrNoAdultConfirmation):
		writeErr(w, http.StatusBadRequest, "18+ confirmation required")
	case err != nil:
		h.internal(w, "create account", err)
	default:
		writeJSON(w, http.StatusCreated, CreateAccountResponse{UserID: id, Token: tok})
	}
}

func (h *handler) me(w http.ResponseWriter, r *http.Request) {
	me, err := h.svc.Accounts.Me(r.Context(), userOf(r))
	if err != nil {
		h.internal(w, "me", err)
		return
	}
	writeJSON(w, http.StatusOK, me)
}

func (h *handler) saveProfile(w http.ResponseWriter, r *http.Request) {
	var p service.ProfileInput
	if !decode(w, r, &p) {
		return
	}
	err := h.svc.SaveProfile(r.Context(), userOf(r), p)
	switch {
	case errors.Is(err, service.ErrInvalid):
		writeErr(w, http.StatusBadRequest, err.Error())
	case err != nil:
		h.internal(w, "save profile", err)
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}

func (h *handler) setPhoto(w http.ResponseWriter, r *http.Request) {
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, service.MaxPhotoBytes+1))
	if err != nil {
		writeErr(w, http.StatusRequestEntityTooLarge, "photo too large")
		return
	}
	id, err := h.svc.SetPhoto(r.Context(), userOf(r), data)
	switch {
	case errors.Is(err, service.ErrBadPhoto):
		writeErr(w, http.StatusBadRequest, "bad photo")
	case errors.Is(err, service.ErrNotFound):
		writeErr(w, http.StatusConflict, "create the profile first")
	case err != nil:
		h.internal(w, "set photo", err)
	default:
		writeJSON(w, http.StatusOK, map[string]string{"photo_id": id})
	}
}

// photo serves a profile photo to signed-in users.
// TODO(phase 3): restrict to self, current radar planets and matches.
func (h *handler) photo(w http.ResponseWriter, r *http.Request) {
	b, err := h.svc.Photo(r.Context(), r.PathValue("id"))
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeErr(w, http.StatusNotFound, "not found")
	case err != nil:
		h.internal(w, "photo", err)
	default:
		w.Header().Set("Content-Type", http.DetectContentType(b))
		w.Header().Set("Cache-Control", "private, max-age=3600")
		_, _ = w.Write(b)
	}
}

// deleteMe removes the account and every row and file belonging to it.
func (h *handler) deleteMe(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.DeleteAccount(r.Context(), userOf(r)); err != nil {
		h.internal(w, "delete account", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *handler) internal(w http.ResponseWriter, what string, err error) {
	if errors.Is(err, service.ErrNotFound) {
		writeErr(w, http.StatusNotFound, "not found")
		return
	}
	h.log.Error(what, "err", err)
	writeErr(w, http.StatusInternalServerError, "internal")
}
