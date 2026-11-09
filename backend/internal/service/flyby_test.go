package service_test

import (
	"bytes"
	"context"
	"errors"
	"testing"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

func key16(b byte) []byte { return bytes.Repeat([]byte{b}, 16) }

const yesterday = "2026-11-08" // wNow is 2026-11-09 12:00 UTC

func flybyWorld(t *testing.T, levels map[string]mood.Level) (*Service, *servicetest.Flyby) {
	t.Helper()
	s, _, _ := world(t, levels)
	fb := servicetest.NewFlyby()
	s.Flyby = fb
	return s, fb
}

func TestFlybyOptInAndYesterdayOnly(t *testing.T) {
	s, _ := flybyWorld(t, map[string]mood.Level{"a": mood.LevelHigh})
	ctx := context.Background()
	if err := s.UploadTEK(ctx, "a", yesterday, key16(1)); !errors.Is(err, ErrFlybyOff) {
		t.Fatalf("opt-in required: %v", err)
	}
	_ = s.SetFlyby(ctx, "a", true)
	for _, d := range []string{"2026-11-09", "2026-11-07", "2026-11-10"} {
		if err := s.UploadTEK(ctx, "a", d, key16(1)); !errors.Is(err, ErrNotYesterday) {
			t.Errorf("day %s accepted: %v", d, err)
		}
	}
	if err := s.UploadTEK(ctx, "a", yesterday, key16(1)[:8]); !errors.Is(err, ErrBadTEK) {
		t.Fatalf("short key: %v", err)
	}
	if err := s.UploadTEK(ctx, "a", yesterday, key16(1)); err != nil {
		t.Fatal(err)
	}
	if err := s.UploadTEK(ctx, "a", yesterday, key16(2)); !errors.Is(err, ErrBadTEK) {
		t.Fatalf("second key for the same day: %v", err)
	}
}

func TestFlybyCometNeedsBothKeysAndBothWaves(t *testing.T) {
	s, fb := flybyWorld(t, map[string]mood.Level{"a": mood.LevelHigh, "b": mood.LevelHigh})
	ctx := context.Background()
	for _, u := range []string{"a", "b"} {
		_ = s.SetFlyby(ctx, u, true)
	}
	_ = s.UploadTEK(ctx, "b", yesterday, key16(2))
	keys, err := s.DownloadTEKs(ctx, "a")
	if err != nil || len(keys) != 1 || !bytes.Equal(keys[0].TEK, key16(2)) {
		t.Fatalf("download: %+v %v", keys, err)
	}
	if own, _ := s.DownloadTEKs(ctx, "b"); len(own) != 0 {
		t.Fatalf("own key returned: %+v", own)
	}
	comet := func(u, other string) string {
		es, _ := s.Radar(ctx, u)
		for _, e := range es {
			if e.Candidate.Profile.ID == other {
				return e.Comet
			}
		}
		return "missing"
	}
	// a waves at b's key, but a has no key of their own uploaded yet.
	if err := s.WaveFlyby(ctx, "a", key16(2), yesterday, "vehicle"); err != nil {
		t.Fatal(err)
	}
	if c := comet("b", "a"); c != "" {
		t.Fatalf("one-sided fly-by shown to b: %q", c)
	}
	_ = s.UploadTEK(ctx, "a", yesterday, key16(1))
	if err := s.WaveFlyby(ctx, "b", key16(1), yesterday, "vehicle"); err != nil {
		t.Fatal(err)
	}
	if c := comet("a", "b"); c != "vehicle" {
		t.Fatalf("comet for a: %q", c)
	}
	if c := comet("b", "a"); c != "vehicle" {
		t.Fatalf("comet for b: %q", c)
	}
	// Opting out wipes keys and encounters at once.
	_ = s.SetFlyby(ctx, "b", false)
	if len(fb.Enc) != 0 {
		t.Fatal("encounters survive opt-out")
	}
	if c := comet("a", "b"); c != "" {
		t.Fatalf("comet after opt-out: %q", c)
	}
}

func TestFlybyRevealsNothingForUnknownKeys(t *testing.T) {
	s, fb := flybyWorld(t, map[string]mood.Level{"a": mood.LevelHigh})
	ctx := context.Background()
	_ = s.SetFlyby(ctx, "a", true)
	if err := s.WaveFlyby(ctx, "a", key16(9), yesterday, "stop"); err != nil {
		t.Fatalf("unknown key must look like success: %v", err)
	}
	if len(fb.Enc) != 0 {
		t.Fatal("encounter invented")
	}
	if err := s.WaveFlyby(ctx, "a", key16(9), yesterday, "bedroom"); !errors.Is(err, ErrBadTEK) {
		t.Fatalf("unknown kind: %v", err)
	}
	if err := s.WaveFlyby(ctx, "a", key16(9), "2026-10-01", "stop"); !errors.Is(err, ErrBadTEK) {
		t.Fatalf("day outside retention: %v", err)
	}
}

func TestFlybyNeverConnectsLowLow(t *testing.T) {
	s, _ := flybyWorld(t, map[string]mood.Level{"a": mood.LevelLow, "b": mood.LevelLow})
	ctx := context.Background()
	for _, u := range []string{"a", "b"} {
		_ = s.SetFlyby(ctx, u, true)
	}
	_ = s.UploadTEK(ctx, "a", yesterday, key16(1))
	_ = s.UploadTEK(ctx, "b", yesterday, key16(2))
	_ = s.WaveFlyby(ctx, "a", key16(2), yesterday, "vehicle")
	_ = s.WaveFlyby(ctx, "b", key16(1), yesterday, "vehicle")
	for _, u := range []string{"a", "b"} {
		if es, _ := s.Radar(ctx, u); len(es) != 0 {
			t.Fatalf("LOW x LOW visible through a fly-by: %+v", es)
		}
	}
}
