package store

import (
	"bytes"
	"context"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func TestFlybyInDB(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	a := seedUser(t, pool, "HIGH", false, false)
	b := seedUser(t, pool, "HIGH", false, false)
	day := time.Date(2026, 11, 8, 0, 0, 0, 0, time.UTC)
	ka, kb := bytes.Repeat([]byte{1}, 16), bytes.Repeat([]byte{2}, 16)
	for _, u := range []string{a, b} {
		if err := s.SetFlyby(ctx, u, true); err != nil {
			t.Fatal(err)
		}
	}
	if ok, err := s.InsertTEK(ctx, a, day, ka, "CZ-PHA"); !ok || err != nil {
		t.Fatalf("insert: %v %v", ok, err)
	}
	if ok, _ := s.InsertTEK(ctx, a, day, kb, "CZ-PHA"); ok {
		t.Fatal("two keys for one day")
	}
	_, _ = s.InsertTEK(ctx, b, day, kb, "CZ-PHA")
	keys, err := s.RegionTEKs(ctx, "CZ-PHA", day.AddDate(0, 0, -14), a)
	if err != nil || len(keys) != 1 || !bytes.Equal(keys[0].TEK, kb) || keys[0].Day != "2026-11-08" {
		t.Fatalf("keys=%+v err=%v", keys, err)
	}
	if owner, err := s.OwnerOfTEK(ctx, kb, day); err != nil || owner != b {
		t.Fatalf("owner=%q err=%v", owner, err)
	}
	if err := s.WaveEncounter(ctx, a, b, "stop", day); err != nil {
		t.Fatal(err)
	}
	if c, _ := s.Comets(ctx, a); len(c) != 0 {
		t.Fatalf("one-sided comet: %v", c)
	}
	_ = s.WaveEncounter(ctx, b, a, "stop", day)
	_ = s.WaveEncounter(ctx, b, a, "stop", day) // idempotent
	if c, _ := s.Comets(ctx, a); c[b] != "stop" {
		t.Fatalf("comets=%v", c)
	}
	var cols int
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM information_schema.columns WHERE table_name = 'encounters' AND data_type LIKE 'timestamp%'`).Scan(&cols)
	if cols != 0 {
		t.Fatal("encounters must store a day, never a timestamp")
	}
	if err := s.SetFlyby(ctx, b, false); err != nil {
		t.Fatal(err)
	}
	if _, err := s.OwnerOfTEK(ctx, kb, day); err != service.ErrNotFound {
		t.Fatalf("key survives opt-out: %v", err)
	}
	if c, _ := s.Comets(ctx, a); len(c) != 0 {
		t.Fatalf("encounter survives opt-out: %v", c)
	}
}
