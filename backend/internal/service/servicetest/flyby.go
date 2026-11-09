package servicetest

import (
	"context"
	"encoding/hex"
	"sync"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

type tekRow struct {
	user, region string
	day          time.Time
	tek          []byte
}

type enc struct {
	kind           string
	day            time.Time
	aWaved, bWaved bool
}

// Flyby is an in-memory service.FlybyStore.
type Flyby struct {
	mu      sync.Mutex
	On      map[string]bool
	Keys    []tekRow
	Enc     map[pair]*enc
	Regions map[string]string
}

// NewFlyby returns an empty fly-by store.
func NewFlyby() *Flyby { return &Flyby{On: map[string]bool{}, Enc: map[pair]*enc{}} }

var _ service.FlybyStore = (*Flyby)(nil)

func (f *Flyby) SetFlyby(_ context.Context, u string, on bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.On[u] = on
	if !on {
		keep := f.Keys[:0]
		for _, k := range f.Keys {
			if k.user != u {
				keep = append(keep, k)
			}
		}
		f.Keys = keep
		for p := range f.Enc {
			if p.a == u || p.b == u {
				delete(f.Enc, p)
			}
		}
	}
	return nil
}

func (f *Flyby) FlybyEnabled(_ context.Context, u string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.On[u], nil
}

func (f *Flyby) InsertTEK(_ context.Context, u string, day time.Time, tek []byte, region string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, k := range f.Keys {
		if (k.user == u && k.day.Equal(day)) || (hex.EncodeToString(k.tek) == hex.EncodeToString(tek) && k.day.Equal(day)) {
			return false, nil
		}
	}
	f.Keys = append(f.Keys, tekRow{user: u, region: region, day: day, tek: tek})
	return true, nil
}

func (f *Flyby) RegionTEKs(_ context.Context, region string, since time.Time, me string) ([]service.DayKey, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []service.DayKey
	for _, k := range f.Keys {
		if k.region == region && !k.day.Before(since) && k.user != me && f.On[k.user] {
			out = append(out, service.DayKey{Day: k.day.Format(time.DateOnly), TEK: k.tek})
		}
	}
	return out, nil
}

func (f *Flyby) OwnerOfTEK(_ context.Context, tek []byte, day time.Time) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, k := range f.Keys {
		if hex.EncodeToString(k.tek) == hex.EncodeToString(tek) && k.day.Equal(day) && f.On[k.user] {
			return k.user, nil
		}
	}
	return "", service.ErrNotFound
}

func (f *Flyby) HasTEKSince(_ context.Context, u string, since time.Time) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, k := range f.Keys {
		if k.user == u && !k.day.Before(since) {
			return true, nil
		}
	}
	return false, nil
}

func (f *Flyby) WaveEncounter(_ context.Context, me, other, kind string, day time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	p := key(me, other)
	e, ok := f.Enc[p]
	if !ok {
		e = &enc{kind: kind, day: day}
		f.Enc[p] = e
	}
	if me == p.a {
		e.aWaved = true
	} else {
		e.bWaved = true
	}
	return nil
}

func (f *Flyby) Comets(_ context.Context, me string) (map[string]string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := map[string]string{}
	for p, e := range f.Enc {
		if !e.aWaved || !e.bWaved || (p.a != me && p.b != me) {
			continue
		}
		other := p.a
		if other == me {
			other = p.b
		}
		out[other] = e.kind
	}
	return out, nil
}
