// Package servicetest provides an in-memory service.Store for tests.
package servicetest

import (
	"context"
	"slices"
	"strings"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Fake is an in-memory store. Fields are exported for test setup.
type Fake struct {
	Settings_ map[string]service.Settings
	Checkins  map[string][]mood.Point
	Records   []service.CheckinRecord
	States    map[string]mood.State
	Pauses    map[string]bool
	Profiles  map[string]matching.Profile
	Catalog   map[string]service.CatalogPlace
	Counts    map[string]int
	TEK       map[string]int
}

// New returns an empty fake.
func New() *Fake {
	return &Fake{
		Settings_: map[string]service.Settings{}, Checkins: map[string][]mood.Point{},
		States: map[string]mood.State{}, Pauses: map[string]bool{}, Profiles: map[string]matching.Profile{},
		Catalog: map[string]service.CatalogPlace{}, Counts: map[string]int{}, TEK: map[string]int{},
	}
}

var _ service.Store = (*Fake)(nil)

func (f *Fake) Settings(_ context.Context, u string) (service.Settings, error) {
	s, ok := f.Settings_[u]
	if !ok {
		return s, service.ErrNotFound
	}
	return s, nil
}

func (f *Fake) InsertCheckin(_ context.Context, c service.CheckinRecord) (int64, error) {
	f.Records = append(f.Records, c)
	v := c.Fused.Mood
	if c.VL != nil {
		v = c.VL.Valence
	}
	f.Checkins[c.UserID] = append(f.Checkins[c.UserID], mood.Point{At: c.At, Mood: c.Fused.Mood, Valence: v})
	return int64(len(f.Records)), nil
}

// ApplyCheckinVL updates record id (1-based) and the user's history point.
func (f *Fake) ApplyCheckinVL(_ context.Context, u string, id int64, vl mood.VLScore, fused mood.Fused) error {
	if id < 1 || int(id) > len(f.Records) || f.Records[id-1].UserID != u {
		return service.ErrNotFound
	}
	r := &f.Records[id-1]
	r.VL, r.Fused = &vl, fused
	pts := f.Checkins[u]
	for i := range pts {
		if pts[i].At.Equal(r.At) {
			pts[i].Mood, pts[i].Valence = fused.Mood, vl.Valence
		}
	}
	return nil
}

func (f *Fake) RecentCheckins(_ context.Context, u string, _ int) ([]mood.Point, error) {
	return f.Checkins[u], nil
}

func (f *Fake) SaveState(_ context.Context, u string, s mood.State, p bool) error {
	f.States[u], f.Pauses[u] = s, p
	return nil
}

func (f *Fake) Region(_ context.Context, u string) (string, error) {
	p, ok := f.Profiles[u]
	if !ok {
		return "", service.ErrNotFound
	}
	return p.Region, nil
}

func (f *Fake) Pool(_ context.Context, region string, after time.Time) ([]matching.Profile, error) {
	ids := make([]string, 0, len(f.Profiles))
	for id := range f.Profiles {
		ids = append(ids, id)
	}
	slices.Sort(ids)
	var out []matching.Profile
	for _, id := range ids {
		p := f.Profiles[id]
		s, ok := f.States[id]
		if !ok || p.Region != region || !s.LastAt.After(after) {
			continue
		}
		p.State = s
		p.Party.SupportPause = f.Pauses[id]
		out = append(out, p)
	}
	return out, nil
}

func (f *Fake) SearchPlaces(_ context.Context, _ string, key string, _ time.Time, limit int) ([]service.CatalogPlace, error) {
	var out []service.CatalogPlace
	for _, p := range f.Catalog {
		if strings.Contains(places.SearchKey(p.Name), key) {
			out = append(out, p)
		}
	}
	slices.SortFunc(out, func(a, b service.CatalogPlace) int { return strings.Compare(a.ID, b.ID) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (f *Fake) SetProfilePlaces(_ context.Context, u string, ids []string, _ time.Time) error {
	for _, id := range ids {
		if _, ok := f.Catalog[id]; !ok {
			return service.ErrUnknownPlace
		}
	}
	p := f.Profiles[u]
	p.Places = slices.Clone(ids)
	f.Profiles[u] = p
	return nil
}

func (f *Fake) ProfilePlaces(_ context.Context, u string) ([]service.CatalogPlace, error) {
	var out []service.CatalogPlace
	for _, id := range f.Profiles[u].Places {
		c := f.Catalog[id]
		c.Lat, c.Lon = nil, nil
		out = append(out, c)
	}
	return out, nil
}

func (f *Fake) PlaceCounts(_ context.Context, ids []string) (map[string]int, error) {
	out := map[string]int{}
	for _, id := range ids {
		if n, ok := f.Counts[id]; ok {
			out[id] = n
		}
	}
	return out, nil
}

func (f *Fake) ActiveTEKCount(_ context.Context, u string) (int, error) { return f.TEK[u], nil }

func (f *Fake) ActiveVenueCheckins(context.Context, string, time.Time) ([]string, error) {
	return nil, nil
}

func (f *Fake) RefreshPlaceCounts(context.Context, time.Time, time.Time) error { return nil }

func (f *Fake) PurgeExpired(context.Context, time.Time) (service.PurgeStats, error) {
	return service.PurgeStats{}, nil
}
