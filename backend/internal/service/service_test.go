package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time { return c.t }

func TestCheckinRespectsVLOff(t *testing.T) {
	f := servicetest.New()
	f.Settings_["u"] = Settings{VLEnabled: false, Weights: mood.DefaultWeights()}
	c := &clock{time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)}
	s := &Service{Store: f, Now: c.now}
	res, err := s.Checkin(context.Background(), "u", ModeVideo, 0.8, &mood.VLScore{Energy: 0, Valence: 0, Confidence: 1})
	if err != nil {
		t.Fatal(err)
	}
	if f.Records[len(f.Records)-1].VL != nil {
		t.Fatal("VL stored although user disabled it")
	}
	if res.State.Level != mood.LevelHigh || res.AskAgain {
		t.Fatalf("got %+v", res)
	}
}

func TestCheckinSupportPauseAfterFiveLowDays(t *testing.T) {
	f := servicetest.New()
	f.Settings_["u"] = Settings{VLEnabled: true, Weights: mood.DefaultWeights()}
	c := &clock{time.Date(2026, 11, 1, 8, 0, 0, 0, time.UTC)}
	s := &Service{Store: f, Now: c.now}
	var res CheckinResult
	for range 5 {
		var err error
		res, err = s.Checkin(context.Background(), "u", ModeVideo, 0.1, &mood.VLScore{Energy: 0.1, Valence: 0.1, Confidence: 0.9})
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
	f := servicetest.New()
	base := time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)
	c := &clock{base}
	s := &Service{Store: f, Now: c.now}
	for _, id := range []string{"a", "b"} {
		f.Settings_[id] = Settings{Weights: mood.DefaultWeights()}
		f.Profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ, Status: matching.StatusSingle, Intents: []matching.Intent{matching.IntentCafe}}
		if _, err := s.Checkin(context.Background(), id, ModeVoice, 0.9, nil); err != nil {
			t.Fatal(err)
		}
	}
	cs, err := s.Radar(context.Background(), "a")
	if err != nil || len(cs) != 1 || cs[0].Candidate.Profile.ID != "b" {
		t.Fatalf("radar=%+v err=%v", cs, err)
	}
	c.t = base.Add(37 * time.Hour)
	if _, err := s.Radar(context.Background(), "a"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("stale user should be off radar, err=%v", err)
	}
}

func TestCheckinRejectsUnknownMode(t *testing.T) {
	f := servicetest.New()
	f.Settings_["u"] = Settings{Weights: mood.DefaultWeights()}
	s := &Service{Store: f, Now: (&clock{}).now}
	if _, err := s.Checkin(context.Background(), "u", "photo", 0.5, nil); !errors.Is(err, ErrBadMode) {
		t.Fatalf("err=%v", err)
	}
}
