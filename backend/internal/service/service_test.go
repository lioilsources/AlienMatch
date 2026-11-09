package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/lioilsources/Mimo/backend/internal/matching"
	"github.com/lioilsources/Mimo/backend/internal/mood"
)

type fakeStore struct {
	settings map[string]Settings
	checkins map[string][]mood.Point
	states   map[string]mood.State
	pauses   map[string]bool
	profiles map[string]matching.Profile
	lastVL   *mood.VLScore
}

func newFake() *fakeStore {
	return &fakeStore{
		settings: map[string]Settings{}, checkins: map[string][]mood.Point{},
		states: map[string]mood.State{}, pauses: map[string]bool{}, profiles: map[string]matching.Profile{},
	}
}

func (f *fakeStore) Settings(_ context.Context, u string) (Settings, error) {
	s, ok := f.settings[u]
	if !ok {
		return s, ErrNotFound
	}
	return s, nil
}

func (f *fakeStore) InsertCheckin(_ context.Context, c CheckinRecord) error {
	f.lastVL = c.VL
	v := c.Fused.Mood
	if c.VL != nil {
		v = c.VL.Valence
	}
	f.checkins[c.UserID] = append(f.checkins[c.UserID], mood.Point{At: c.At, Mood: c.Fused.Mood, Valence: v})
	return nil
}

func (f *fakeStore) RecentCheckins(_ context.Context, u string, _ int) ([]mood.Point, error) {
	return f.checkins[u], nil
}

func (f *fakeStore) SaveState(_ context.Context, u string, s mood.State, p bool) error {
	f.states[u], f.pauses[u] = s, p
	return nil
}

func (f *fakeStore) Region(_ context.Context, u string) (string, error) {
	p, ok := f.profiles[u]
	if !ok {
		return "", ErrNotFound
	}
	return p.Region, nil
}

func (f *fakeStore) Pool(_ context.Context, region string, after time.Time) ([]matching.Profile, error) {
	var out []matching.Profile
	for id, p := range f.profiles {
		s, ok := f.states[id]
		if !ok || p.Region != region || !s.LastAt.After(after) {
			continue
		}
		p.State = s
		p.Party.SupportPause = f.pauses[id]
		out = append(out, p)
	}
	return out, nil
}

type clock struct{ t time.Time }

func (c *clock) now() time.Time { return c.t }

func TestCheckinRespectsVLOff(t *testing.T) {
	f := newFake()
	f.settings["u"] = Settings{VLEnabled: false, Weights: mood.DefaultWeights()}
	c := &clock{time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)}
	s := &Service{Store: f, Now: c.now}
	res, err := s.Checkin(context.Background(), "u", 0.8, &mood.VLScore{Energy: 0, Valence: 0, Confidence: 1})
	if err != nil {
		t.Fatal(err)
	}
	if f.lastVL != nil {
		t.Fatal("VL stored although user disabled it")
	}
	if res.State.Level != mood.LevelHigh || res.AskAgain {
		t.Fatalf("got %+v", res)
	}
}

func TestCheckinSupportPauseAfterFiveLowDays(t *testing.T) {
	f := newFake()
	f.settings["u"] = Settings{VLEnabled: true, Weights: mood.DefaultWeights()}
	c := &clock{time.Date(2026, 11, 1, 8, 0, 0, 0, time.UTC)}
	s := &Service{Store: f, Now: c.now}
	var res CheckinResult
	for range 5 {
		var err error
		res, err = s.Checkin(context.Background(), "u", 0.1, &mood.VLScore{Energy: 0.1, Valence: 0.1, Confidence: 0.9})
		if err != nil {
			t.Fatal(err)
		}
		c.t = c.t.Add(24 * time.Hour)
	}
	if !res.SupportPause {
		t.Fatal("expected support pause after 5 LOW days")
	}
}

func TestRadarOffWhenStale(t *testing.T) {
	f := newFake()
	base := time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)
	c := &clock{base}
	s := &Service{Store: f, Now: c.now}
	for _, id := range []string{"a", "b"} {
		f.settings[id] = Settings{Weights: mood.DefaultWeights()}
		f.profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ, Status: matching.StatusSingle, Intents: []matching.Intent{matching.IntentCafe}}
		if _, err := s.Checkin(context.Background(), id, 0.9, nil); err != nil {
			t.Fatal(err)
		}
	}
	cs, err := s.Radar(context.Background(), "a")
	if err != nil || len(cs) != 1 || cs[0].Profile.ID != "b" {
		t.Fatalf("radar=%+v err=%v", cs, err)
	}
	c.t = base.Add(37 * time.Hour)
	if _, err := s.Radar(context.Background(), "a"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("stale user should be off radar, err=%v", err)
	}
}
