package store

import (
	"context"
	"errors"
	"slices"
	"testing"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func TestWallsInDB(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	seedCatalog(t, s, 2)
	a := seedUser(t, pool, "HIGH", false, false)
	b := seedUser(t, pool, "HIGH", false, false)
	l1 := seedUser(t, pool, "LOW", true, true)
	l2 := seedUser(t, pool, "LOW", true, true)

	// The wall path goes through the DB guard too.
	if _, _, err := s.CreateMatchWithWall(ctx, l1, l2, matching.Encourage); err == nil {
		t.Fatal("LOW x LOW wall created")
	}

	_ = s.SetProfilePlaces(ctx, a, []string{"stop:pid:A", "poi:osm:n0"}, tNow)
	_ = s.SetProfilePlaces(ctx, b, []string{"stop:pid:A", "poi:osm:n1"}, tNow)
	_ = s.AddWave(ctx, a, b, tNow)
	_ = s.AddWave(ctx, a, b, tNow) // duplicate ignored
	if n, _ := s.CountWavesSince(ctx, a, tNow.Add(-1)); n != 1 {
		t.Fatalf("waves=%d", n)
	}
	if ok, _ := s.HasWave(ctx, b, a); ok {
		t.Fatal("reverse wave invented")
	}
	mid, wall, err := s.CreateMatchWithWall(ctx, a, b, matching.Match)
	if err != nil {
		t.Fatal(err)
	}
	if m2, w2, _ := s.CreateMatchWithWall(ctx, b, a, matching.Match); m2 != mid || w2 != wall {
		t.Fatal("second create must return the existing wall")
	}
	ms, err := s.ListMatches(ctx, b)
	if err != nil || len(ms) != 1 || ms[0].OtherID != a || len(ms[0].SharedPlaces) != 1 || ms[0].SharedPlaces[0] != "Anděl" {
		t.Fatalf("matches=%+v err=%v (shared place must be revealed by name)", ms, err)
	}

	ink := []byte(`{"aspect":1,"strokes":[{"c":0,"w":0.01,"p":[0,0,1,1]}]}`)
	st := service.Sticker{WallID: wall, AuthorID: a, ClientID: "0f8fad5b-d9cb-469f-a165-70867728950e", Kind: "ink", Ink: ink, Scale: 1}
	x1, err := s.InsertSticker(ctx, st, tNow)
	if err != nil {
		t.Fatal(err)
	}
	x2, _ := s.InsertSticker(ctx, st, tNow)
	if x1.ID != x2.ID {
		t.Fatal("client_id not idempotent")
	}
	p, err := s.InsertSticker(ctx, service.Sticker{WallID: wall, AuthorID: b, ClientID: "1f8fad5b-d9cb-469f-a165-70867728950e", Kind: "preset", Preset: "heart", Scale: 1}, tNow)
	if err != nil || p.Preset != "heart" || p.Z <= x1.Z {
		t.Fatalf("preset=%+v err=%v", p, err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO stickers (wall_id, author_id, client_id, kind, x, y) VALUES ($1, $2, gen_random_uuid(), 'ink', 0, 0)`, wall, a); err == nil {
		t.Fatal("ink sticker without ink accepted")
	}
	if err := s.MoveSticker(ctx, service.Sticker{ID: x1.ID, WallID: wall, AuthorID: b, Scale: 1}); !errors.Is(err, service.ErrNotYours) {
		t.Fatalf("move other's: %v", err)
	}
	if _, err := s.HideSticker(ctx, x1.ID, a); !errors.Is(err, service.ErrNotMember) {
		t.Fatalf("self hide: %v", err)
	}
	if w, err := s.HideSticker(ctx, x1.ID, b); err != nil || w != wall {
		t.Fatalf("hide: %d %v", w, err)
	}
	vis, _ := s.ListStickers(ctx, wall, 0)
	if len(vis) != 1 || vis[0].ID != p.ID {
		t.Fatalf("visible=%+v", vis)
	}
	if err := s.PeelSticker(ctx, wall, p.ID, b, tNow); err != nil {
		t.Fatal(err)
	}

	ex, _ := s.RadarExclusions(ctx, a)
	if !slices.Contains(ex, b) {
		t.Fatalf("matched user not excluded: %v", ex)
	}
	if err := s.Block(ctx, a, b, tNow); err != nil {
		t.Fatal(err)
	}
	if _, err := s.WallMember(ctx, wall, b); !errors.Is(err, service.ErrNotMember) {
		t.Fatalf("wall open after block: %v", err)
	}
	if ex, _ := s.RadarExclusions(ctx, b); !slices.Contains(ex, a) {
		t.Fatalf("block not symmetric on radar: %v", ex)
	}
	if ok, _ := s.HasEntitlement(ctx, a, "signal_plus", tNow); ok {
		t.Fatal("phantom entitlement")
	}
	_, _ = pool.Exec(ctx, `INSERT INTO entitlements (user_id, product, source) VALUES ($1, 'signal_plus', 'ol1n_pass')`, a)
	if ok, _ := s.HasEntitlement(ctx, a, "signal_plus", tNow); !ok {
		t.Fatal("Ol1n Pass lifetime entitlement not honoured")
	}
}
