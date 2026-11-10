package store

import (
	"context"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
)

func TestRatingsInDB(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	star := seedUser(t, pool, "HIGH", false, false)
	a := seedUser(t, pool, "MID", false, false)
	b := seedUser(t, pool, "LOW", false, false)
	t0 := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)

	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(s.RateFace(ctx, a, star, "photos/x/f1.jpg", 1, t0))
	must(s.RateFace(ctx, a, star, "photos/x/f1.jpg", -1, t0.Add(time.Second))) // change, not a second row
	must(s.RateFace(ctx, b, star, "photos/x/f1.jpg", 1, t0))
	must(s.RateFace(ctx, a, star, "photos/x/f2.jpg", 0, t0.Add(time.Hour)))
	if err := s.RateFace(ctx, a, a, "photos/a/f.jpg", 1, t0); err == nil {
		t.Fatal("self rating accepted by the DB")
	}
	if err := s.RateFace(ctx, a, star, "photos/x/f3.jpg", 2, t0); err == nil {
		t.Fatal("value 2 accepted by the DB")
	}

	mine, err := s.RatingsByRater(ctx, a, []string{"photos/x/f1.jpg", "photos/x/f9.jpg"})
	if err != nil || len(mine) != 1 || mine["photos/x/f1.jpg"] != -1 {
		t.Fatalf("mine=%v err=%v", mine, err)
	}
	st, err := s.FaceStats(ctx, star)
	if err != nil || len(st) != 2 || st[0].PhotoKey != "photos/x/f2.jpg" {
		t.Fatalf("stats=%+v err=%v", st, err)
	}
	if f1 := st[1]; f1.Likes != 1 || f1.Dislikes != 1 || f1.Seen != 2 {
		t.Fatalf("f1=%+v", f1)
	}
	if st[0].Seen != 1 || st[0].Likes != 0 {
		t.Fatalf("f2=%+v", st[0])
	}

	liked, err := s.LikedTargets(ctx, b)
	if err != nil || len(liked) != 1 || liked[0].UserID != star {
		t.Fatalf("liked=%+v err=%v", liked, err)
	}
	must(s.Block(ctx, star, b, t0))
	if liked, _ := s.LikedTargets(ctx, b); len(liked) != 0 {
		t.Fatalf("blocked target still liked: %+v", liked)
	}
	if l, err := s.OwnLevel(ctx, b); err != nil || l != mood.LevelLow {
		t.Fatalf("level=%q err=%v", l, err)
	}

	// Deleting either side removes the ratings.
	if _, err := s.DeleteAccount(ctx, a); err != nil {
		t.Fatal(err)
	}
	st, _ = s.FaceStats(ctx, star)
	if len(st) != 1 || st[0].Seen != 1 {
		t.Fatalf("rater's ratings survived deletion: %+v", st)
	}
	if _, err := s.DeleteAccount(ctx, star); err != nil {
		t.Fatal(err)
	}
	var n int
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM face_ratings`).Scan(&n)
	if n != 0 {
		t.Fatalf("%d ratings left after deleting the target", n)
	}
}
