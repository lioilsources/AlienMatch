package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

var now = time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)

func setup(t *testing.T) (*httptest.Server, *servicetest.Fake) {
	t.Helper()
	f := servicetest.New()
	for _, id := range []string{"me", "stop5", "stop4", "nothing"} {
		f.Settings_[id] = service.Settings{Weights: mood.DefaultWeights()}
		f.Profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ,
			Status: matching.StatusSingle, Intents: []matching.Intent{matching.IntentCafe}}
		f.States[id] = mood.State{Level: mood.LevelHigh, Trend: mood.TrendRising, LastAt: now.Add(-time.Hour)}
	}
	for _, id := range []string{"stop:pid:A", "stop:pid:B", "route:pid:22"} {
		f.Catalog[id] = service.CatalogPlace{ID: id, Kind: "stop", Name: "Anděl " + id}
	}
	set := func(u string, ps ...string) {
		p := f.Profiles[u]
		p.Places = ps
		f.Profiles[u] = p
	}
	set("me", "stop:pid:A", "stop:pid:B")
	set("stop5", "stop:pid:A")
	set("stop4", "stop:pid:B")
	f.Counts["stop:pid:A"] = 5
	f.Counts["stop:pid:B"] = 4
	svc := &service.Service{Store: f, Now: func() time.Time { return now }}
	srv := httptest.NewServer(Handler(svc, DevAuth{}, slog.New(slog.NewTextHandler(io.Discard, nil))))
	t.Cleanup(srv.Close)
	return srv, f
}

func do(t *testing.T, srv *httptest.Server, method, path, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
	req.Header.Set("X-AlienMatch-User", "me")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

func TestRadarConstellationKAnonymity(t *testing.T) {
	srv, _ := setup(t)
	code, body := do(t, srv, "GET", "/v1/radar", "")
	if code != 200 {
		t.Fatalf("%d %s", code, body)
	}
	var res struct {
		Planets []RadarPlanet `json:"planets"`
	}
	if err := json.Unmarshal([]byte(body), &res); err != nil {
		t.Fatal(err)
	}
	if len(res.Planets) != 3 {
		t.Fatalf("planets=%+v", res.Planets)
	}
	by := map[string]RadarPlanet{}
	for _, p := range res.Planets {
		by[p.UserID] = p
	}
	if p := by["stop5"]; p.Star != "stop:pid:A" || p.WeakSignal {
		t.Errorf("k=5 planet: %+v", p)
	}
	if p := by["stop4"]; p.Star != "" || !p.WeakSignal {
		t.Errorf("k=4 planet must not reveal the place: %+v", p)
	}
	if p := by["nothing"]; p.Star != "" || p.WeakSignal {
		t.Errorf("no shared place: %+v", p)
	}
	if res.Planets[2].UserID != "nothing" {
		t.Errorf("planets with shared places must rank first: %+v", res.Planets)
	}
	if strings.Contains(body, "score") || strings.Contains(body, "count") {
		t.Errorf("ranking score or counts leaked: %s", body)
	}
}

func TestCoordinatesRejected(t *testing.T) {
	srv, _ := setup(t)
	if code, _ := do(t, srv, "PUT", "/v1/me/places", `{"place_ids":["stop:pid:A"],"lat":50.1,"lon":14.4}`); code != 400 {
		t.Errorf("lat/lon in body: %d", code)
	}
	if code, _ := do(t, srv, "GET", "/v1/radar?lat=50.1&lon=14.4", ""); code != 400 {
		t.Errorf("lat/lon in query: %d", code)
	}
	if code, _ := do(t, srv, "GET", "/v1/places?q=andel&Geohash=u2fk", ""); code != 400 {
		t.Errorf("geohash in query: %d", code)
	}
	if code, _ := do(t, srv, "POST", "/v1/checkins", `{"self":0.5,"location":"x"}`); code != 400 {
		t.Errorf("location in check-in: %d", code)
	}
}

func TestSetPlaces(t *testing.T) {
	srv, f := setup(t)
	if code, b := do(t, srv, "PUT", "/v1/me/places", `{"place_ids":["route:pid:22","route:pid:22"]}`); code != 204 {
		t.Fatalf("%d %s", code, b)
	}
	if got := f.Profiles["me"].Places; len(got) != 1 || got[0] != "route:pid:22" {
		t.Fatalf("places=%v", got)
	}
	nine := `{"place_ids":["stop:1","stop:2","stop:3","stop:4","stop:5","stop:6","stop:7","stop:8","stop:9"]}`
	if code, _ := do(t, srv, "PUT", "/v1/me/places", nine); code != 400 {
		t.Errorf("9 places: %d", code)
	}
	if code, _ := do(t, srv, "PUT", "/v1/me/places", `{"place_ids":["stop:pid:nope"]}`); code != 400 {
		t.Errorf("unknown place: %d", code)
	}
	if code, _ := do(t, srv, "PUT", "/v1/me/places", `{"place_ids":["home:my-street"]}`); code != 400 {
		t.Errorf("bad kind: %d", code)
	}
}

func TestSearchPlaces(t *testing.T) {
	srv, _ := setup(t)
	if code, _ := do(t, srv, "GET", "/v1/places?q=a", ""); code != 400 {
		t.Errorf("short query: %d", code)
	}
	code, body := do(t, srv, "GET", "/v1/places?q=ANDEL", "")
	if code != 200 || !strings.Contains(body, "stop:pid:A") {
		t.Errorf("%d %s", code, body)
	}
}

func TestLocationDataIsComplete(t *testing.T) {
	srv, f := setup(t)
	f.TEK["me"] = 3
	code, body := do(t, srv, "GET", "/v1/me/location-data", "")
	if code != 200 {
		t.Fatalf("%d %s", code, body)
	}
	var d service.LocationData
	if err := json.Unmarshal([]byte(body), &d); err != nil {
		t.Fatal(err)
	}
	if len(d.Places) != 2 || d.ActiveKeys != 3 || len(d.Coordinates) != 0 || d.VenueCheckins == nil {
		t.Fatalf("got %+v", d)
	}
	if strings.Contains(body, `"lat"`) || strings.Contains(body, `"lon"`) {
		t.Errorf("location data must not carry coordinates: %s", body)
	}
}
