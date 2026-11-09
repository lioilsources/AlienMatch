package service_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

var wNow = time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC)

// world: users with given levels, all fresh, same region, sharing coffee.
func world(t *testing.T, levels map[string]mood.Level) (*Service, *servicetest.Walls, *servicetest.Fake) {
	t.Helper()
	f, w := servicetest.New(), servicetest.NewWalls()
	for id, l := range levels {
		f.Profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ, Status: matching.StatusSingle,
			Intents: []matching.Intent{matching.IntentCafe, matching.IntentTea}}
		f.States[id] = mood.State{Level: l, Trend: mood.TrendRising, LastAt: wNow.Add(-time.Hour)}
	}
	return &Service{Store: f, Walls: w, Now: func() time.Time { return wNow }}, w, f
}

func TestWaveOnlyToRadarAndMutualOpensWall(t *testing.T) {
	s, _, _ := world(t, map[string]mood.Level{"a": mood.LevelHigh, "b": mood.LevelHigh, "low": mood.LevelLow})
	ctx := context.Background()
	if _, err := s.Wave(ctx, "a", "low"); !errors.Is(err, ErrNotOnRadar) {
		t.Fatalf("wave to LOW without opt-ins: %v", err)
	}
	if _, err := s.Wave(ctx, "a", "a"); !errors.Is(err, ErrNotOnRadar) {
		t.Fatalf("self wave: %v", err)
	}
	r, err := s.Wave(ctx, "a", "b")
	if err != nil || r.Matched {
		t.Fatalf("first wave: %+v %v", r, err)
	}
	// b sees nothing yet: matches list empty.
	if ms, _ := s.Matches(ctx, "b"); len(ms) != 0 {
		t.Fatalf("one-sided wave leaked: %+v", ms)
	}
	r, err = s.Wave(ctx, "b", "a")
	if err != nil || !r.Matched || r.Kind != "match" || r.WallID == 0 {
		t.Fatalf("mutual wave: %+v %v", r, err)
	}
	// Matched pair leaves each other's radar.
	es, _ := s.Radar(ctx, "a")
	for _, e := range es {
		if e.Candidate.Profile.ID == "b" {
			t.Fatal("matched user still on radar")
		}
	}
}

func TestWaveLimitAndSignalPlus(t *testing.T) {
	levels := map[string]mood.Level{"me": mood.LevelHigh}
	for i := range 7 {
		levels[fmt.Sprintf("p%d", i)] = mood.LevelHigh
	}
	s, w, _ := world(t, levels)
	ctx := context.Background()
	for i := range FreeWavesPerDay {
		if _, err := s.Wave(ctx, "me", fmt.Sprintf("p%d", i)); err != nil {
			t.Fatalf("wave %d: %v", i, err)
		}
	}
	if _, err := s.Wave(ctx, "me", "p5"); !errors.Is(err, ErrWaveLimit) {
		t.Fatalf("6th wave: %v", err)
	}
	w.Plus["me"] = true
	if _, err := s.Wave(ctx, "me", "p5"); err != nil {
		t.Fatalf("Signál+ wave: %v", err)
	}
}

func openWall(t *testing.T, s *Service) int64 {
	t.Helper()
	ctx := context.Background()
	_, _ = s.Wave(ctx, "a", "b")
	r, err := s.Wave(ctx, "b", "a")
	if err != nil || !r.Matched {
		t.Fatalf("open wall: %+v %v", r, err)
	}
	return r.WallID
}

const cid = "0f8fad5b-d9cb-469f-a165-70867728950e"

func ink() json.RawMessage {
	return json.RawMessage(`{"aspect":2,"strokes":[{"c":1,"w":0.02,"p":[0.1,0.2,0.3,0.4,0.5,0.5]}]}`)
}

func TestStickersOnWall(t *testing.T) {
	s, w, _ := world(t, map[string]mood.Level{"a": mood.LevelHigh, "b": mood.LevelHigh, "c": mood.LevelHigh})
	ctx := context.Background()
	wall := openWall(t, s)
	in := StickerInput{ClientID: cid, Kind: "ink", Ink: ink(), X: 10, Y: 20, Scale: 1}
	st, err := s.Stick(ctx, "a", wall, in)
	if err != nil {
		t.Fatal(err)
	}
	again, _ := s.Stick(ctx, "a", wall, in)
	if again.ID != st.ID || len(w.Stickers) != 1 {
		t.Fatal("offline resend must be idempotent")
	}
	if _, err := s.Stick(ctx, "c", wall, in); !errors.Is(err, ErrNotMember) {
		t.Fatalf("outsider stick: %v", err)
	}
	if _, err := s.Stickers(ctx, "c", wall, 0); !errors.Is(err, ErrNotMember) {
		t.Fatalf("outsider read: %v", err)
	}
	if err := s.Move(ctx, "b", wall, st.ID, 0, 0, 0, 1, 9); !errors.Is(err, ErrNotYours) {
		t.Fatalf("move other's: %v", err)
	}
	if err := s.Peel(ctx, "b", wall, st.ID); !errors.Is(err, ErrNotYours) {
		t.Fatalf("peel other's: %v", err)
	}
	p, err := s.Stick(ctx, "b", wall, StickerInput{ClientID: "1f8fad5b-d9cb-469f-a165-70867728950e", Kind: "preset", Preset: "heart", Scale: 1})
	if err != nil || p.Preset != "heart" {
		t.Fatalf("preset: %+v %v", p, err)
	}
	if _, err := s.Stick(ctx, "b", wall, StickerInput{ClientID: "2f8fad5b-d9cb-469f-a165-70867728950e", Kind: "text", Scale: 1}); !errors.Is(err, ErrBadSticker) {
		t.Fatalf("text kind: %v", err)
	}
	// Report hides at once; reporter cannot report own sticker.
	if err := s.ReportSticker(ctx, "a", st.ID, false); !errors.Is(err, ErrNotMember) {
		t.Fatalf("self report: %v", err)
	}
	if err := s.ReportSticker(ctx, "b", st.ID, false); err != nil {
		t.Fatal(err)
	}
	vis, _ := s.Stickers(ctx, "a", wall, 0)
	if len(vis) != 1 || vis[0].ID != p.ID {
		t.Fatalf("reported sticker still visible: %+v", vis)
	}
}

func TestBlockEndsWallAndHidesFromRadar(t *testing.T) {
	s, _, _ := world(t, map[string]mood.Level{"a": mood.LevelHigh, "b": mood.LevelHigh})
	ctx := context.Background()
	wall := openWall(t, s)
	if err := s.BlockUser(ctx, "a", "b"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Stickers(ctx, "b", wall, 0); !errors.Is(err, ErrNotMember) {
		t.Fatalf("wall still open after block: %v", err)
	}
	for _, u := range []string{"a", "b"} {
		es, _ := s.Radar(ctx, u)
		if len(es) != 0 {
			t.Fatalf("%s still sees the other after block: %+v", u, es)
		}
	}
}

func TestGentleWallPresets(t *testing.T) {
	s, _, f := world(t, map[string]mood.Level{"a": mood.LevelHigh, "b": mood.LevelLow})
	pa, pb := f.Profiles["a"], f.Profiles["b"]
	pa.Party.CanBeBeacon, pb.Party.WantsEncouragement = true, true
	f.Profiles["a"], f.Profiles["b"] = pa, pb
	wall := openWall(t, s)
	ctx := context.Background()
	if _, err := s.Stick(ctx, "a", wall, StickerInput{ClientID: cid, Kind: "preset", Preset: "fire", Scale: 1}); !errors.Is(err, ErrBadSticker) {
		t.Fatalf("flirty preset on encouragement wall: %v", err)
	}
	if _, err := s.Stick(ctx, "a", wall, StickerInput{ClientID: cid, Kind: "preset", Preset: "tea", Scale: 1}); err != nil {
		t.Fatal(err)
	}
}

func TestValidateInkRejectsAnythingButGeometry(t *testing.T) {
	if _, err := ValidateInk(ink()); err != nil {
		t.Fatal(err)
	}
	bad := []string{
		`{"aspect":2,"strokes":[{"c":1,"w":0.02,"p":[0.1,0.2]}],"text":"call me 777"}`,
		`{"aspect":2,"strokes":[{"c":1,"w":0.02,"p":[0.1,0.2],"label":"hi"}]}`,
		`{"aspect":2,"strokes":[]}`,
		`{"aspect":2,"strokes":[{"c":9,"w":0.02,"p":[0.1,0.2]}]}`,
		`{"aspect":2,"strokes":[{"c":1,"w":0.02,"p":[0.1]}]}`,
		`{"aspect":2,"strokes":[{"c":1,"w":0.02,"p":[1.5,0.2]}]}`,
		`{"aspect":0,"strokes":[{"c":1,"w":0.02,"p":[0.1,0.2]}]}`,
		`"just text"`,
	}
	for _, b := range bad {
		if _, err := ValidateInk(json.RawMessage(b)); !errors.Is(err, ErrBadSticker) {
			t.Errorf("accepted %s", b)
		}
	}
}
