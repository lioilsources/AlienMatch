package servicetest

import (
	"context"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Accounts is an in-memory service.AccountStore.
type Accounts struct {
	Tokens   map[string]string // hex(hash) → user id
	Users    map[string]*service.Me
	Photos   map[string]string
	Profiles map[string]service.ProfileInput
	n        int
}

// NewAccounts returns an empty account store.
func NewAccounts() *Accounts {
	return &Accounts{Tokens: map[string]string{}, Users: map[string]*service.Me{}, Photos: map[string]string{}, Profiles: map[string]service.ProfileInput{}}
}

var _ service.AccountStore = (*Accounts)(nil)

func (a *Accounts) CreateAccount(_ context.Context, h []byte, _ time.Time, consent bool) (string, error) {
	a.n++
	id := fmt.Sprintf("00000000-0000-0000-0000-%012d", a.n)
	a.Tokens[hex.EncodeToString(h)] = id
	a.Users[id] = &service.Me{UserID: id, MoodConsent: consent, VLEnabled: consent}
	return id, nil
}

func (a *Accounts) UserByTokenHash(_ context.Context, h []byte) (string, error) {
	id, ok := a.Tokens[hex.EncodeToString(h)]
	if !ok {
		return "", service.ErrNotFound
	}
	return id, nil
}

func (a *Accounts) Me(_ context.Context, id string) (service.Me, error) {
	u, ok := a.Users[id]
	if !ok {
		return service.Me{}, service.ErrNotFound
	}
	me := *u
	if p, ok := a.Profiles[id]; ok {
		me.HasProfile, me.Profile = true, &p
	}
	me.HasPhoto = a.Photos[id] != ""
	return me, nil
}

func (a *Accounts) SaveProfile(_ context.Context, id string, p service.ProfileInput, _ time.Time) error {
	a.Profiles[id] = p
	return nil
}

func (a *Accounts) SwapPhoto(_ context.Context, id, key string, _ time.Time) (string, error) {
	if _, ok := a.Profiles[id]; !ok {
		return "", service.ErrNotFound
	}
	prev := a.Photos[id]
	a.Photos[id] = key
	return prev, nil
}

func (a *Accounts) PhotoKey(_ context.Context, id string) (string, error) { return a.Photos[id], nil }

func (a *Accounts) DeleteAccount(_ context.Context, id string) (string, error) {
	k := a.Photos[id]
	delete(a.Users, id)
	delete(a.Profiles, id)
	delete(a.Photos, id)
	for t, u := range a.Tokens {
		if u == id {
			delete(a.Tokens, t)
		}
	}
	return k, nil
}

// Media is an in-memory service.MediaStore.
type Media map[string][]byte

func (m Media) Put(_ context.Context, k string, b []byte) error { m[k] = b; return nil }
func (m Media) Get(_ context.Context, k string) ([]byte, error) {
	b, ok := m[k]
	if !ok {
		return nil, service.ErrNotFound
	}
	return b, nil
}
func (m Media) Delete(_ context.Context, k string) error { delete(m, k); return nil }
