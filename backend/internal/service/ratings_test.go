package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

// starWorld: the world() radar plus photos and a rating store.
func starWorld(t *testing.T, levels map[string]mood.Level) (*Service, *servicetest.Ratings, *servicetest.Accounts, *servicetest.Walls) {
	t.Helper()
	s, w, _ := world(t, levels)
	acc, rt := servicetest.NewAccounts(), servicetest.NewRatings()
	for id, l := range levels {
		acc.Photos[id] = "photos/" + id + "/face1.jpg"
		rt.Levels[id] = l
	}
	s.Accounts, s.Ratings = acc, rt
	return s, rt, acc, w
}

func deckIDs(st []Star) []string {
	out := make([]string, len(st))
	for i, x := range st {
		out[i] = x.UserID
	}
	return out
}

func TestStarsAreOnlyHighAuraFacesOnMyRadar(t *testing.T) {
	s, _, _, _ := starWorld(t, map[string]mood.Level{
		"me": mood.LevelMid, "bright": mood.LevelHigh, "mid": mood.LevelMid, "low": mood.LevelLow,
	})
	ctx := context.Background()
	st, err := s.Stars(ctx, "me")
	if err != nil {
		t.Fatal(err)
	}
	if got := deckIDs(st); len(got) != 1 || got[0] != "bright" {
		t.Fatalf("deck = %v, want only the HIGH star", got)
	}
	if st[0].PhotoID != "face1" || st[0].Rating != nil {
		t.Fatalf("card = %+v", st[0])
	}
	for _, who := range []string{"mid", "low", "me", "nobody"} {
		if err := s.Rate(ctx, "me", who, RateLike); !errors.Is(err, ErrNotAStar) {
			t.Fatalf("rating %s: %v, want ErrNotAStar", who, err)
		}
	}
	if err := s.Rate(ctx, "me", "bright", 2); !errors.Is(err, ErrBadRating) {
		t.Fatalf("value 2: %v", err)
	}
}

func TestRatingCanChangeAndANewFaceStartsUnrated(t *testing.T) {
	s, _, acc, _ := starWorld(t, map[string]mood.Level{"me": mood.LevelHigh, "star": mood.LevelHigh})
	ctx := context.Background()
	for _, v := range []int{RateSeen, RateLike, RateDislike} {
		if err := s.Rate(ctx, "me", "star", v); err != nil {
			t.Fatal(err)
		}
		st, _ := s.Stars(ctx, "me")
		if st[0].Rating == nil || *st[0].Rating != v {
			t.Fatalf("after %d: %+v", v, st[0].Rating)
		}
	}
	acc.Photos["star"] = "photos/star/face2.jpg"
	st, _ := s.Stars(ctx, "me")
	if st[0].PhotoID != "face2" || st[0].Rating != nil {
		t.Fatalf("new face should be unrated: %+v", st[0])
	}
}

func TestFaceStatsPerFaceAndNoDislikesWhileLow(t *testing.T) {
	s, rt, acc, _ := starWorld(t, map[string]mood.Level{
		"star": mood.LevelHigh, "a": mood.LevelHigh, "b": mood.LevelHigh, "c": mood.LevelHigh,
	})
	ctx := context.Background()
	now := wNow
	s.Now = func() time.Time { return now }
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(s.Rate(ctx, "a", "star", RateLike))
	must(s.Rate(ctx, "b", "star", RateDislike))
	acc.Photos["star"] = "photos/star/face2.jpg"
	now = now.Add(time.Minute)
	must(s.Rate(ctx, "a", "star", RateLike))
	must(s.Rate(ctx, "c", "star", RateSeen))

	res, err := s.MyFaceStats(ctx, "star")
	must(err)
	if res.DislikesHidden || len(res.Faces) != 2 {
		t.Fatalf("stats = %+v", res)
	}
	newest, old := res.Faces[0], res.Faces[1]
	if newest.PhotoKey != res.CurrentKey || newest.Likes != 1 || newest.Dislikes != 0 || newest.Seen != 2 {
		t.Fatalf("current face = %+v", newest)
	}
	if old.Likes != 1 || old.Dislikes != 1 || old.Seen != 2 {
		t.Fatalf("old face = %+v", old)
	}

	rt.Levels["star"] = mood.LevelLow
	res, err = s.MyFaceStats(ctx, "star")
	must(err)
	if !res.DislikesHidden {
		t.Fatal("dislikes must be hidden while LOW")
	}
	for _, f := range res.Faces {
		if f.Dislikes != 0 {
			t.Fatalf("dislike leaked while LOW: %+v", f)
		}
	}
}

func TestLikedListSaysWhoCanBeWavedAt(t *testing.T) {
	s, rt, _, _ := starWorld(t, map[string]mood.Level{"me": mood.LevelHigh, "x": mood.LevelHigh, "y": mood.LevelHigh})
	ctx := context.Background()
	if err := s.Rate(ctx, "me", "x", RateLike); err != nil {
		t.Fatal(err)
	}
	if err := s.Rate(ctx, "me", "y", RateDislike); err != nil {
		t.Fatal(err)
	}
	ls, err := s.MyLiked(ctx, "me")
	if err != nil || len(ls) != 1 || ls[0].UserID != "x" || !ls[0].OnRadar {
		t.Fatalf("liked = %+v %v", ls, err)
	}
	// Liking never creates a match or a wave.
	if ms, _ := s.Matches(ctx, "me"); len(ms) != 0 {
		t.Fatalf("a like matched: %+v", ms)
	}
	rt.Blocked[[2]string{"x", "me"}] = true
	if ls, _ := s.MyLiked(ctx, "me"); len(ls) != 0 {
		t.Fatalf("blocked person still listed: %+v", ls)
	}
}
