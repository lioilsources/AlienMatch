package store

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lioilsources/Mimo/backend/internal/db"
	"github.com/lioilsources/Mimo/backend/internal/matching"
)

// Runs only with MIMO_TEST_DATABASE_URL pointing at a throwaway database.
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("MIMO_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("MIMO_TEST_DATABASE_URL not set")
	}
	if err := db.Migrate(url); err != nil {
		t.Fatal(err)
	}
	pool, err := pgxpool.New(context.Background(), url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	return pool
}

func seedUser(t *testing.T, pool *pgxpool.Pool, level string, beacon, wants bool) string {
	t.Helper()
	ctx := context.Background()
	var id string
	err := pool.QueryRow(ctx, `INSERT INTO users (adult_confirmed_at) VALUES ('2026-11-01') RETURNING id::text`).Scan(&id)
	if err != nil {
		t.Fatal(err)
	}
	_, err = pool.Exec(ctx, `INSERT INTO profiles (user_id, photo_key, generation, status, region, can_be_beacon, wants_encouragement)
		VALUES ($1, 'p.webp', 'genz', 'single', 'CZ-PHA', $2, $3)`, id, beacon, wants)
	if err != nil {
		t.Fatal(err)
	}
	_, err = pool.Exec(ctx, `INSERT INTO mood_state (user_id, level, trend, mood, last_checkin_at, computed_at)
		VALUES ($1, $2, 'FLAT', 0.5, '2026-11-09', '2026-11-09')`, id, level)
	if err != nil {
		t.Fatal(err)
	}
	return id
}

func TestDBGuardLowTimesLow(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	a := seedUser(t, pool, "LOW", true, true)
	b := seedUser(t, pool, "LOW", true, true)
	s := New(pool)
	for _, k := range []matching.Result{matching.Match, matching.Encourage} {
		if _, err := s.CreateMatch(ctx, a, b, k); err == nil || !strings.Contains(err.Error(), "LOW x LOW") {
			t.Fatalf("kind %v: err=%v, want LOW x LOW rejection", k, err)
		}
	}
	// Raw SQL, bypassing the app, must fail too.
	_, err := pool.Exec(ctx, `INSERT INTO matches (user_a, user_b, kind) VALUES (LEAST($1::uuid,$2::uuid), GREATEST($1::uuid,$2::uuid), 'encourage')`, a, b)
	if err == nil {
		t.Fatal("raw insert of LOW x LOW succeeded")
	}
}

func TestDBGuardRomanceAndEncouragement(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	high := seedUser(t, pool, "HIGH", true, false)
	low := seedUser(t, pool, "LOW", false, true)
	lowNoOptIn := seedUser(t, pool, "LOW", false, false)
	high2 := seedUser(t, pool, "HIGH", false, false)

	if _, err := s.CreateMatch(ctx, high, low, matching.Match); err == nil {
		t.Fatal("romantic match with LOW user succeeded")
	}
	if _, err := s.CreateMatch(ctx, high, lowNoOptIn, matching.Encourage); err == nil {
		t.Fatal("encouragement without seeker opt-in succeeded")
	}
	if _, err := s.CreateMatch(ctx, high2, low, matching.Encourage); err == nil {
		t.Fatal("encouragement without beacon opt-in succeeded")
	}
	if _, err := s.CreateMatch(ctx, low, high, matching.Encourage); err != nil {
		t.Fatalf("valid encouragement rejected: %v", err)
	}
	if _, err := s.CreateMatch(ctx, high, high2, matching.Match); err != nil {
		t.Fatalf("valid match rejected: %v", err)
	}
	// Updating an existing encouragement into romance while one side is LOW must fail.
	_, err := pool.Exec(ctx, `UPDATE matches SET kind = 'match' WHERE user_a = LEAST($1::uuid,$2::uuid) AND user_b = GREATEST($1::uuid,$2::uuid)`, low, high)
	if err == nil {
		t.Fatal("update encourage->match with LOW user succeeded")
	}
}

func TestPoolScansEnumArrays(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	id := seedUser(t, pool, "HIGH", false, false)
	if _, err := pool.Exec(ctx, `UPDATE profiles SET region = 'CZ-POOL', seek_generations = '{genz,genx}', seek_statuses = '{single}' WHERE user_id = $1`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO profile_tags VALUES ($1, 'coffee')`, id); err != nil {
		t.Fatal(err)
	}
	ps, err := New(pool).Pool(ctx, "CZ-POOL", time.Date(2026, 11, 8, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	if len(ps) != 1 || len(ps[0].SeekGens) != 2 || ps[0].SeekStatus[0] != matching.StatusSingle || ps[0].Intents[0] != matching.IntentCafe {
		t.Fatalf("pool=%+v", ps)
	}
}
