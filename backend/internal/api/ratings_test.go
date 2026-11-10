package api

import (
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

func starServer(t *testing.T) (*httptest.Server, *servicetest.Ratings) {
	t.Helper()
	f, acc, rt := servicetest.New(), servicetest.NewAccounts(), servicetest.NewRatings()
	for id, l := range map[string]mood.Level{"me": mood.LevelMid, "star": mood.LevelHigh, "low": mood.LevelLow} {
		f.Profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ, Status: matching.StatusSingle, Intents: []matching.Intent{matching.IntentCafe}}
		f.States[id] = mood.State{Level: l, Trend: mood.TrendRising, LastAt: now.Add(-time.Hour)}
		acc.Photos[id] = "photos/" + id + "/abc.jpg"
		rt.Levels[id] = l
	}
	svc := &service.Service{Store: f, Accounts: acc, Walls: servicetest.NewWalls(), Ratings: rt, Now: func() time.Time { return now }}
	srv := httptest.NewServer(Handler(svc, DevAuth{}, slog.New(slog.NewTextHandler(io.Discard, nil))))
	t.Cleanup(srv.Close)
	return srv, rt
}

func TestStarDeckRatingStatsAndLiked(t *testing.T) {
	srv, rt := starServer(t)
	code, body := as(t, srv, "me", "GET", "/v1/stars", "")
	if code != 200 || !strings.Contains(body, `"user_id":"star"`) || strings.Contains(body, `"low"`) || !strings.Contains(body, `"rating":null`) {
		t.Fatalf("deck: %d %s", code, body)
	}
	if strings.Contains(body, `"mood"`) {
		t.Fatalf("deck leaks mood numbers: %s", body)
	}
	for _, bad := range []string{`{"value":2}`, `{}`, `{"value":1,"x":1}`} {
		if code, _ := as(t, srv, "me", "PUT", "/v1/stars/star/rating", bad); code != 400 {
			t.Fatalf("%s: %d", bad, code)
		}
	}
	if code, _ := as(t, srv, "me", "PUT", "/v1/stars/low/rating", `{"value":-1}`); code != 404 {
		t.Fatalf("rating LOW: %d", code)
	}
	if code, _ := as(t, srv, "me", "PUT", "/v1/stars/star/rating", `{"value":-1}`); code != 204 {
		t.Fatalf("rate: %d", code)
	}
	if _, body := as(t, srv, "me", "GET", "/v1/stars", ""); !strings.Contains(body, `"rating":-1`) {
		t.Fatalf("my rating not shown back: %s", body)
	}
	_, body = as(t, srv, "star", "GET", "/v1/me/face-stats", "")
	if !strings.Contains(body, `"photo_id":"abc","current":true,"likes":0,"dislikes":1,"seen":1`) {
		t.Fatalf("stats: %s", body)
	}
	rt.Levels["star"] = mood.LevelLow
	_, body = as(t, srv, "star", "GET", "/v1/me/face-stats", "")
	if !strings.Contains(body, `"dislikes":null`) || !strings.Contains(body, `"dislikes_hidden":true`) {
		t.Fatalf("LOW stats: %s", body)
	}
	as(t, srv, "me", "PUT", "/v1/stars/star/rating", `{"value":1}`)
	if _, body := as(t, srv, "me", "GET", "/v1/me/liked", ""); !strings.Contains(body, `"user_id":"star"`) || !strings.Contains(body, `"on_radar":true`) {
		t.Fatalf("liked: %s", body)
	}
}
