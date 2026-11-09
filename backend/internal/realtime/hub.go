// Package realtime fans wall events out to connected clients (WebSocket).
// Single process for now; split into its own service only under load.
package realtime

import (
	"crypto/rand"
	"encoding/base64"
	"sync"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Hub keeps per-wall subscribers.
type Hub struct {
	mu   sync.Mutex
	subs map[int64]map[chan service.WallEvent]struct{}
}

var _ service.Publisher = (*Hub)(nil)

// NewHub returns an empty hub.
func NewHub() *Hub { return &Hub{subs: map[int64]map[chan service.WallEvent]struct{}{}} }

// Subscribe returns a buffered event channel and a cancel func.
func (h *Hub) Subscribe(wallID int64) (<-chan service.WallEvent, func()) {
	ch := make(chan service.WallEvent, 64)
	h.mu.Lock()
	if h.subs[wallID] == nil {
		h.subs[wallID] = map[chan service.WallEvent]struct{}{}
	}
	h.subs[wallID][ch] = struct{}{}
	h.mu.Unlock()
	return ch, func() {
		h.mu.Lock()
		if _, ok := h.subs[wallID][ch]; ok {
			delete(h.subs[wallID], ch)
			close(ch)
		}
		if len(h.subs[wallID]) == 0 {
			delete(h.subs, wallID)
		}
		h.mu.Unlock()
	}
}

// Publish delivers to every subscriber; a slow client drops events and
// catches up through GET /stickers?after=.
func (h *Hub) Publish(wallID int64, ev service.WallEvent) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for ch := range h.subs[wallID] {
		select {
		case ch <- ev:
		default:
		}
	}
}

// Subscribers counts connections on a wall (tests, metrics).
func (h *Hub) Subscribers(wallID int64) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.subs[wallID])
}

// Tickets are single-use, short-lived WebSocket credentials, so the bearer
// token never appears in a URL (browsers cannot set WS headers).
type Tickets struct {
	mu  sync.Mutex
	m   map[string]ticket
	TTL time.Duration
	Now func() time.Time
}

type ticket struct {
	user    string
	wall    int64
	expires time.Time
}

// NewTickets returns a ticket store with a 60 s TTL.
func NewTickets(now func() time.Time) *Tickets {
	return &Tickets{m: map[string]ticket{}, TTL: time.Minute, Now: now}
}

// Issue creates a ticket for user on wall.
func (t *Tickets) Issue(user string, wall int64) string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	k := base64.RawURLEncoding.EncodeToString(b)
	t.mu.Lock()
	defer t.mu.Unlock()
	now := t.Now()
	for key, v := range t.m {
		if now.After(v.expires) {
			delete(t.m, key)
		}
	}
	t.m[k] = ticket{user: user, wall: wall, expires: now.Add(t.TTL)}
	return k
}

// Redeem consumes a ticket; ok is false if unknown, used, expired or for another wall.
func (t *Tickets) Redeem(k string, wall int64) (user string, ok bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	v, found := t.m[k]
	delete(t.m, k)
	if !found || v.wall != wall || t.Now().After(v.expires) {
		return "", false
	}
	return v.user, true
}
