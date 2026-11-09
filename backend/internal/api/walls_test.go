package api

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/realtime"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

func wallServer(t *testing.T) (*httptest.Server, *realtime.Hub) {
	t.Helper()
	f, w := servicetest.New(), servicetest.NewWalls()
	for _, id := range []string{"a", "b"} {
		f.Profiles[id] = matching.Profile{ID: id, Region: "CZ-PHA", Generation: matching.GenZ, Status: matching.StatusSingle, Intents: []matching.Intent{matching.IntentCafe}}
		f.States[id] = mood.State{Level: mood.LevelHigh, Trend: mood.TrendRising, LastAt: now.Add(-time.Hour)}
	}
	hub := realtime.NewHub()
	clock := func() time.Time { return now }
	svc := &service.Service{Store: f, Walls: w, Pub: hub, Now: clock}
	rt := &Realtime{Hub: hub, Tickets: realtime.NewTickets(clock)}
	srv := httptest.NewServer(Handler(svc, DevAuth{}, slog.New(slog.NewTextHandler(io.Discard, nil)), WithRealtime(rt)))
	t.Cleanup(srv.Close)
	return srv, hub
}

func as(t *testing.T, srv *httptest.Server, user, method, path, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
	req.Header.Set("X-AlienMatch-User", user)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

func TestWallRealtimeDelivery(t *testing.T) {
	srv, hub := wallServer(t)
	as(t, srv, "a", "POST", "/v1/waves", `{"to":"b"}`)
	code, body := as(t, srv, "b", "POST", "/v1/waves", `{"to":"a"}`)
	var wr service.WaveResult
	_ = json.Unmarshal([]byte(body), &wr)
	if code != 200 || !wr.Matched {
		t.Fatalf("mutual wave: %d %s", code, body)
	}
	wall := wr.WallID
	path := "/v1/walls/" + itoa(wall)

	_, body = as(t, srv, "b", "POST", path+"/ticket", "")
	var tk struct{ Ticket string }
	_ = json.Unmarshal([]byte(body), &tk)
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + path + "/ws?ticket=" + tk.Ticket
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer c.CloseNow()
	// Single use: the same ticket must not open a second socket.
	if _, _, err := websocket.Dial(ctx, wsURL, nil); err == nil {
		t.Fatal("ticket reused")
	}
	for hub.Subscribers(wall) == 0 {
		time.Sleep(5 * time.Millisecond)
	}

	start := time.Now()
	sticker := `{"client_id":"0f8fad5b-d9cb-469f-a165-70867728950e","kind":"preset","preset":"ufo","x":1,"y":2,"scale":1}`
	if code, b := as(t, srv, "a", "POST", path+"/stickers", sticker); code != 201 {
		t.Fatalf("stick: %d %s", code, b)
	}
	_, msg, err := c.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if d := time.Since(start); d > 500*time.Millisecond {
		t.Fatalf("delivery took %v, budget 500ms", d)
	}
	var ev service.WallEvent
	_ = json.Unmarshal(msg, &ev)
	if ev.Type != "sticker" || ev.Sticker == nil || ev.Sticker.Preset != "ufo" {
		t.Fatalf("event: %s", msg)
	}

	// Report by b hides it and notifies the wall.
	if code, _ := as(t, srv, "b", "POST", "/v1/reports", `{"sticker_id":`+itoa(ev.Sticker.ID)+`}`); code != 204 {
		t.Fatalf("report: %d", code)
	}
	_, msg, _ = c.Read(ctx)
	if !strings.Contains(string(msg), `"hide"`) {
		t.Fatalf("hide event: %s", msg)
	}
	_, body = as(t, srv, "a", "GET", path+"/stickers", "")
	if strings.Contains(body, "ufo") {
		t.Fatalf("reported sticker still listed: %s", body)
	}
	// Outsiders never get a ticket.
	if code, _ := as(t, srv, "c", "POST", path+"/ticket", ""); code != 404 {
		t.Fatalf("outsider ticket: %d", code)
	}
}

func TestStickerRejectsText(t *testing.T) {
	srv, _ := wallServer(t)
	as(t, srv, "a", "POST", "/v1/waves", `{"to":"b"}`)
	_, body := as(t, srv, "b", "POST", "/v1/waves", `{"to":"a"}`)
	var wr service.WaveResult
	_ = json.Unmarshal([]byte(body), &wr)
	path := "/v1/walls/" + itoa(wr.WallID) + "/stickers"
	for _, b := range []string{
		`{"client_id":"0f8fad5b-d9cb-469f-a165-70867728950e","kind":"preset","preset":"ufo","scale":1,"text":"hi"}`,
		`{"client_id":"0f8fad5b-d9cb-469f-a165-70867728950e","kind":"text","scale":1}`,
		`{"client_id":"0f8fad5b-d9cb-469f-a165-70867728950e","kind":"ink","scale":1,"ink":{"aspect":1,"strokes":[{"c":0,"w":0.01,"p":[0,0]}],"caption":"hi"}}`,
	} {
		if code, _ := as(t, srv, "a", "POST", path, b); code != 400 {
			t.Errorf("accepted %s: %d", b, code)
		}
	}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }
