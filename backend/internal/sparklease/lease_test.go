package sparklease

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeBroker struct {
	mu      sync.Mutex
	state   string
	created []map[string]any
	beats   int
	done    []map[string]any
	auth    string
}

func (f *fakeBroker) handler(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.auth = r.Header.Get("Authorization")
	switch {
	case r.Method == "POST" && r.URL.Path == "/v1/jobs":
		var b map[string]any
		_ = json.NewDecoder(r.Body).Decode(&b)
		f.created = append(f.created, b)
		f.state = "queued"
		w.WriteHeader(201)
		_, _ = io.WriteString(w, `{"id":"1109-200","state":"queued"}`)
	case r.Method == "GET" && r.URL.Path == "/v1/jobs/1109-200":
		_ = json.NewEncoder(w).Encode(map[string]string{"state": f.state})
	case strings.HasSuffix(r.URL.Path, "/heartbeat"):
		f.beats++
	case strings.HasSuffix(r.URL.Path, "/extend"):
	case strings.HasSuffix(r.URL.Path, "/done"):
		var b map[string]any
		_ = json.NewDecoder(r.Body).Decode(&b)
		f.done = append(f.done, b)
		f.state = "done"
	}
}

func TestLeaseLifecycle(t *testing.T) {
	fb := &fakeBroker{}
	srv := httptest.NewServer(http.HandlerFunc(fb.handler))
	defer srv.Close()
	now := time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)
	m := New(Config{BrokerURL: srv.URL, Token: "tok", Project: "alienmatch", Services: []string{"asr", "vl"}, Priority: 20},
		slog.New(slog.NewTextHandler(io.Discard, nil)), func() time.Time { return now })
	ctx := context.Background()

	if m.State() != "off" {
		t.Fatal("must start off")
	}
	if s := m.Demand(ctx); s != "starting" {
		t.Fatalf("after demand: %s", s)
	}
	m.Demand(ctx) // second demand: no second job
	if len(fb.created) != 1 {
		t.Fatalf("jobs created: %d", len(fb.created))
	}
	job := fb.created[0]
	stage := job["stages"].([]any)[0].(map[string]any)
	if job["project"] != "alienmatch" || job["preemptible"] != true || stage["mode"] != "lease" || len(stage["services"].([]any)) != 2 {
		t.Fatalf("job: %v", job)
	}
	if fb.auth != "Bearer tok" {
		t.Fatalf("auth: %q", fb.auth)
	}

	fb.state = "running"
	m.Tick(ctx)
	if !m.Ready() {
		t.Fatal("running job must be ready")
	}
	now = now.Add(3 * time.Minute)
	m.Demand(ctx)
	m.Tick(ctx)
	if fb.beats != 1 {
		t.Fatalf("heartbeats: %d", fb.beats)
	}

	m.Result(true)
	m.Result(false)
	now = now.Add(11 * time.Minute) // idle
	m.Tick(ctx)
	if m.State() != "off" || len(fb.done) != 1 {
		t.Fatalf("idle release: state=%s done=%v", m.State(), fb.done)
	}
	met := fb.done[0]["metrics"].(map[string]any)["checkins"].(map[string]any)
	if met["ok"] != 1.0 || met["failed"] != 1.0 {
		t.Fatalf("metrics: %v", met)
	}
}

func TestLeaseEndedByBroker(t *testing.T) {
	fb := &fakeBroker{}
	srv := httptest.NewServer(http.HandlerFunc(fb.handler))
	defer srv.Close()
	now := time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)
	m := New(Config{BrokerURL: srv.URL, Project: "alienmatch", Services: []string{"asr"}}, slog.New(slog.NewTextHandler(io.Discard, nil)), func() time.Time { return now })
	m.Demand(context.Background())
	fb.state = "orphaned"
	m.Tick(context.Background())
	if m.State() != "off" {
		t.Fatalf("state=%s", m.State())
	}
	m.Demand(context.Background())
	if len(fb.created) != 2 {
		t.Fatal("a new demand must queue a new lease")
	}
}

func TestBrokerDownIsNotFatal(t *testing.T) {
	m := New(Config{BrokerURL: "http://127.0.0.1:1", Project: "alienmatch"}, slog.New(slog.NewTextHandler(io.Discard, nil)), time.Now)
	if s := m.Demand(context.Background()); s != "off" {
		t.Fatalf("state=%s", s)
	}
}
