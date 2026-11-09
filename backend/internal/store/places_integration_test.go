package store

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/catalog"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var tNow = time.Date(2026, 11, 9, 10, 0, 0, 0, time.UTC)

func fptr(f float64) *float64 { return &f }

func seedCatalog(t *testing.T, s *PG, n int) {
	t.Helper()
	ps := []catalog.Place{{ID: "stop:pid:A", Kind: places.KindStop, Name: "Anděl", Lat: fptr(50.07), Lon: fptr(14.40), Region: "CZ-PHA", Source: "gtfs:pid"}}
	for i := range n {
		ps = append(ps, catalog.Place{ID: fmt.Sprintf("poi:osm:n%d", i), Kind: places.KindPOI, Name: fmt.Sprintf("Kavárna %d", i), Region: "CZ-PHA", Source: "osm"})
	}
	if err := s.UpsertCatalog(context.Background(), ps); err != nil {
		t.Fatal(err)
	}
}

// Audit: no column that could hold a coordinate exists outside the public catalog.
func TestNoCoordinateColumnsOutsideCatalog(t *testing.T) {
	pool := testPool(t)
	rows, err := pool.Query(context.Background(), `
		SELECT table_name || '.' || column_name FROM information_schema.columns
		WHERE table_schema = 'public' AND table_name <> 'places'
		  AND column_name ~* '(^|_)(lat|lon|lng|latitude|longitude|geohash|geom|geog|gps|coord|coords|position)($|_)'`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	for rows.Next() {
		var c string
		_ = rows.Scan(&c)
		t.Errorf("coordinate-like column outside places: %s", c)
	}
}

func TestProfilePlacesLimitAndAtomicity(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	seedCatalog(t, s, 9)
	u := seedUser(t, pool, "HIGH", false, false)

	eight := []string{"stop:pid:A"}
	for i := range 7 {
		eight = append(eight, fmt.Sprintf("poi:osm:n%d", i))
	}
	if err := s.SetProfilePlaces(ctx, u, eight, tNow); err != nil {
		t.Fatal(err)
	}
	// The DB trigger refuses a 9th place even with raw SQL.
	if _, err := pool.Exec(ctx, `INSERT INTO profile_places (user_id, place_id) VALUES ($1, 'poi:osm:n8')`, u); err == nil {
		t.Fatal("9th place accepted by DB")
	}
	// Unknown id: nothing changes.
	if err := s.SetProfilePlaces(ctx, u, []string{"stop:pid:A", "stop:pid:ghost"}, tNow); !errors.Is(err, service.ErrUnknownPlace) {
		t.Fatalf("err=%v", err)
	}
	got, err := s.ProfilePlaces(ctx, u)
	if err != nil || len(got) != 8 {
		t.Fatalf("places after failed update = %d, err=%v", len(got), err)
	}
}

func TestSearchIgnoresDiacritics(t *testing.T) {
	pool := testPool(t)
	s := New(pool)
	seedCatalog(t, s, 1)
	got, err := s.SearchPlaces(context.Background(), "CZ-PHA", places.SearchKey("ANDEL"), tNow, 10)
	if err != nil || len(got) != 1 || got[0].ID != "stop:pid:A" || got[0].Lat == nil {
		t.Fatalf("got %+v err=%v", got, err)
	}
	if got, _ := s.SearchPlaces(context.Background(), "CZ-JHM", "andel", tNow, 10); len(got) != 0 {
		t.Fatalf("other region leaked: %+v", got)
	}
}

func TestPlaceCountsCountOnlyActiveMembers(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	seedCatalog(t, s, 0)
	for range 4 {
		u := seedUser(t, pool, "HIGH", false, false)
		if err := s.SetProfilePlaces(ctx, u, []string{"stop:pid:A"}, tNow); err != nil {
			t.Fatal(err)
		}
	}
	stale := seedUser(t, pool, "HIGH", false, false)
	_ = s.SetProfilePlaces(ctx, stale, []string{"stop:pid:A"}, tNow)
	if _, err := pool.Exec(ctx, `UPDATE mood_state SET last_checkin_at = $2 WHERE user_id = $1`, stale, tNow.Add(-40*time.Hour)); err != nil {
		t.Fatal(err)
	}
	// seedUser sets last_checkin_at to 2026-11-09 00:00 local; refresh with 36 h window.
	if err := s.RefreshPlaceCounts(ctx, tNow, tNow.Add(-36*time.Hour)); err != nil {
		t.Fatal(err)
	}
	c, err := s.PlaceCounts(ctx, []string{"stop:pid:A"})
	if err != nil || c["stop:pid:A"] != 4 {
		t.Fatalf("count=%v err=%v, want 4 (stale member excluded)", c, err)
	}
	if places.Shared([]string{"stop:pid:A"}, []string{"stop:pid:A"}, c).Star != "" {
		t.Fatal("4 members must not reveal the place")
	}
	// Members leave: the count row disappears.
	if _, err := pool.Exec(ctx, `DELETE FROM profile_places`); err != nil {
		t.Fatal(err)
	}
	_ = s.RefreshPlaceCounts(ctx, tNow, tNow.Add(-36*time.Hour))
	if c, _ := s.PlaceCounts(ctx, []string{"stop:pid:A"}); len(c) != 0 {
		t.Fatalf("stale count kept: %v", c)
	}
}

func TestTTLPurge(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	seedCatalog(t, s, 0)
	a := seedUser(t, pool, "HIGH", false, false)
	b := seedUser(t, pool, "HIGH", false, false)
	tek := make([]byte, 16)
	exec := func(q string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, q, args...); err != nil {
			t.Fatal(err)
		}
	}
	exec(`INSERT INTO tek_uploads VALUES ($1, '2026-10-25', $2, 'CZ-PHA'), ($1, '2026-11-08', $2, 'CZ-PHA')`, a, tek)
	exec(`INSERT INTO encounters (user_a, user_b, kind, day) VALUES (LEAST($1::uuid,$2::uuid), GREATEST($1::uuid,$2::uuid), 'vehicle', '2026-10-25'),
		(LEAST($1::uuid,$2::uuid), GREATEST($1::uuid,$2::uuid), 'stop', '2026-11-08')`, a, b)
	exec(`INSERT INTO venue_checkins VALUES ($1, 'stop:pid:A', '2026-11-09 02:00Z', '2026-11-09 08:00Z')`, a)
	exec(`INSERT INTO places (place_id, kind, name, name_search, region, source, expires_at)
		VALUES ('event:fest', 'event', 'Fest', 'fest', 'CZ-PHA', 'curated', '2026-11-09 09:00Z')`)

	st, err := s.PurgeExpired(ctx, tNow)
	if err != nil {
		t.Fatal(err)
	}
	if st != (service.PurgeStats{TEK: 1, Encounters: 1, VenueCheckins: 1, Events: 1}) {
		t.Fatalf("stats=%+v", st)
	}
	// 14 days later everything dynamic is gone.
	st, _ = s.PurgeExpired(ctx, tNow.AddDate(0, 0, 15))
	var n int
	_ = pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM tek_uploads) + (SELECT count(*) FROM encounters)`).Scan(&n)
	if n != 0 || st.TEK != 1 || st.Encounters != 1 {
		t.Fatalf("left=%d stats=%+v", n, st)
	}
}
