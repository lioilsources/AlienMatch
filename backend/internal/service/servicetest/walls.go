package servicetest

import (
	"context"
	"slices"
	"sync"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

type pair struct{ a, b string }

func key(a, b string) pair {
	if a > b {
		a, b = b, a
	}
	return pair{a, b}
}

type match struct {
	id, wall int64
	kind     matching.Result
	ended    bool
}

// Walls is an in-memory service.WallStore.
type Walls struct {
	mu       sync.Mutex
	Waves    map[pair]time.Time // directed: {from,to}
	matches  map[pair]*match
	Stickers map[int64]*service.Sticker
	hidden   map[int64]bool
	Blocks   map[pair]bool // directed
	Reports  int
	Plus     map[string]bool
	n        int64
}

// NewWalls returns an empty wall store.
func NewWalls() *Walls {
	return &Walls{Waves: map[pair]time.Time{}, matches: map[pair]*match{}, Stickers: map[int64]*service.Sticker{},
		hidden: map[int64]bool{}, Blocks: map[pair]bool{}, Plus: map[string]bool{}}
}

var _ service.WallStore = (*Walls)(nil)

func (w *Walls) CountWavesSince(_ context.Context, from string, since time.Time) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	n := 0
	for p, t := range w.Waves {
		if p.a == from && !t.Before(since) {
			n++
		}
	}
	return n, nil
}

func (w *Walls) AddWave(_ context.Context, from, to string, now time.Time) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if _, ok := w.Waves[pair{from, to}]; !ok {
		w.Waves[pair{from, to}] = now
	}
	return nil
}

func (w *Walls) HasWave(_ context.Context, from, to string) (bool, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	_, ok := w.Waves[pair{from, to}]
	return ok, nil
}

func (w *Walls) CreateMatchWithWall(_ context.Context, a, b string, kind matching.Result) (int64, int64, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if m, ok := w.matches[key(a, b)]; ok && !m.ended {
		return m.id, m.wall, nil
	}
	w.n++
	m := &match{id: w.n, wall: 100 + w.n, kind: kind}
	w.matches[key(a, b)] = m
	return m.id, m.wall, nil
}

func (w *Walls) ActiveMatchBetween(_ context.Context, a, b string) (int64, int64, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if m, ok := w.matches[key(a, b)]; ok && !m.ended {
		return m.id, m.wall, nil
	}
	return 0, 0, service.ErrNotFound
}

func (w *Walls) ListMatches(_ context.Context, me string) ([]service.MatchView, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	var out []service.MatchView
	for p, m := range w.matches {
		if m.ended || (p.a != me && p.b != me) {
			continue
		}
		other := p.a
		if other == me {
			other = p.b
		}
		out = append(out, service.MatchView{MatchID: m.id, WallID: m.wall, Kind: m.kind.String(), OtherID: other, SharedPlaces: []string{}})
	}
	return out, nil
}

func (w *Walls) WallMember(_ context.Context, wallID int64, me string) (service.Wall, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	for p, m := range w.matches {
		if m.wall == wallID && !m.ended && (p.a == me || p.b == me) {
			other := p.a
			if other == me {
				other = p.b
			}
			return service.Wall{ID: wallID, Gentle: m.kind == matching.Encourage, OtherID: other}, nil
		}
	}
	return service.Wall{}, service.ErrNotMember
}

func (w *Walls) ListStickers(_ context.Context, wallID, after int64) ([]service.Sticker, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	var out []service.Sticker
	for id, s := range w.Stickers {
		if s.WallID == wallID && id > after && !w.hidden[id] {
			out = append(out, *s)
		}
	}
	slices.SortFunc(out, func(a, b service.Sticker) int { return int(a.ID - b.ID) })
	return out, nil
}

func (w *Walls) InsertSticker(_ context.Context, s service.Sticker, now time.Time) (service.Sticker, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	for _, x := range w.Stickers {
		if x.AuthorID == s.AuthorID && x.ClientID == s.ClientID {
			return *x, nil
		}
	}
	w.n++
	s.ID, s.Created, s.Z = w.n, now, int(w.n)
	w.Stickers[s.ID] = &s
	return s, nil
}

func (w *Walls) MoveSticker(_ context.Context, s service.Sticker) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	x, ok := w.Stickers[s.ID]
	if !ok || x.AuthorID != s.AuthorID || x.WallID != s.WallID {
		return service.ErrNotYours
	}
	x.X, x.Y, x.Rotation, x.Scale, x.Z = s.X, s.Y, s.Rotation, s.Scale, s.Z
	return nil
}

func (w *Walls) PeelSticker(_ context.Context, wallID, id int64, author string, _ time.Time) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	x, ok := w.Stickers[id]
	if !ok || x.AuthorID != author || x.WallID != wallID {
		return service.ErrNotYours
	}
	delete(w.Stickers, id)
	return nil
}

func (w *Walls) HideSticker(_ context.Context, id int64, me string) (int64, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	x, ok := w.Stickers[id]
	if !ok || x.AuthorID == me {
		return 0, service.ErrNotMember
	}
	w.hidden[id] = true
	return x.WallID, nil
}

func (w *Walls) Report(context.Context, string, *string, *int64, bool, time.Time) error {
	w.mu.Lock()
	w.Reports++
	w.mu.Unlock()
	return nil
}

func (w *Walls) Block(_ context.Context, me, other string, _ time.Time) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.Blocks[pair{me, other}] = true
	if m, ok := w.matches[key(me, other)]; ok {
		m.ended = true
	}
	return nil
}

func (w *Walls) RadarExclusions(_ context.Context, me string) ([]string, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	var out []string
	for p := range w.Blocks {
		if p.a == me {
			out = append(out, p.b)
		}
		if p.b == me {
			out = append(out, p.a)
		}
	}
	for p, m := range w.matches {
		if !m.ended && (p.a == me || p.b == me) {
			if p.a == me {
				out = append(out, p.b)
			} else {
				out = append(out, p.a)
			}
		}
	}
	return out, nil
}

func (w *Walls) HasEntitlement(_ context.Context, user, _ string, _ time.Time) (bool, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.Plus[user], nil
}
