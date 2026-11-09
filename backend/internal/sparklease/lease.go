// Package sparklease starts the mood models on SPARK on demand through the
// spark-broker HTTP API (never by touching containers): the first check-in
// that wants scoring queues a lease for the services, heartbeats keep it
// while check-ins keep coming, and it is released after an idle period.
package sparklease

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Config describes the lease this project asks for.
type Config struct {
	BrokerURL string // http://spark:8100
	Token     string // optional BROKER_TOKEN
	Project   string // "alienmatch"
	Services  []string
	Priority  int           // ≤ project cap (20 by default, alienmatch has 30)
	LeaseMin  int           // initial lease length
	Idle      time.Duration // release after this long without demand
}

// Manager keeps at most one lease and reports whether the services run.
type Manager struct {
	cfg  Config
	http *http.Client
	now  func() time.Time
	log  *slog.Logger

	mu         sync.Mutex
	jobID      string
	state      string
	lastDemand time.Time
	lastBeat   time.Time
	ok, failed int
}

// New returns a manager; call Run in a goroutine.
func New(cfg Config, log *slog.Logger, now func() time.Time) *Manager {
	if cfg.LeaseMin == 0 {
		cfg.LeaseMin = 20
	}
	if cfg.Idle == 0 {
		cfg.Idle = 10 * time.Minute
	}
	return &Manager{cfg: cfg, http: &http.Client{Timeout: 10 * time.Second}, now: now, log: log}
}

// State is "off" (no lease), "starting" (queued) or "ready" (running).
func (m *Manager) State() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	switch {
	case m.jobID == "":
		return "off"
	case m.state == "running":
		return "ready"
	default:
		return "starting"
	}
}

// Ready reports whether the models can be called now.
func (m *Manager) Ready() bool { return m.State() == "ready" }

// Demand records that a user wants scoring and queues a lease if none is
// active. It never blocks on the services starting.
func (m *Manager) Demand(ctx context.Context) string {
	m.mu.Lock()
	m.lastDemand = m.now()
	need := m.jobID == ""
	m.mu.Unlock()
	if need {
		if err := m.create(ctx); err != nil {
			m.log.Warn("sparklease: queue lease", "err", err)
		}
	}
	return m.State()
}

// Result counts scored check-ins for the broker's summary.
func (m *Manager) Result(ok bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if ok {
		m.ok++
	} else {
		m.failed++
	}
}

func (m *Manager) create(ctx context.Context) error {
	body := map[string]any{
		"project":     m.cfg.Project,
		"title":       "AlienMatch check-in scoring",
		"priority":    m.cfg.Priority,
		"preemptible": true,
		"heartbeat":   true,
		"notify":      false,
		"stages": []map[string]any{{
			"name": "score", "services": m.cfg.Services, "mode": "lease", "lease_min": m.cfg.LeaseMin,
		}},
	}
	var out struct {
		ID    string `json:"id"`
		State string `json:"state"`
	}
	if err := m.call(ctx, http.MethodPost, "/v1/jobs", body, &out); err != nil {
		return err
	}
	if out.ID == "" {
		return fmt.Errorf("sparklease: broker returned no job id")
	}
	m.mu.Lock()
	m.jobID, m.state, m.lastBeat = out.ID, out.State, m.now()
	m.mu.Unlock()
	m.log.Info("sparklease: lease queued", "job", out.ID)
	return nil
}

// Run polls the job, heartbeats while in use and releases it when idle.
func (m *Manager) Run(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			m.release(context.Background())
			return
		case <-t.C:
			m.Tick(ctx)
		}
	}
}

// Tick does one poll / heartbeat / release step (exported for tests).
func (m *Manager) Tick(ctx context.Context) {
	m.mu.Lock()
	id, lastDemand, lastBeat := m.jobID, m.lastDemand, m.lastBeat
	m.mu.Unlock()
	if id == "" {
		return
	}
	now := m.now()
	if now.Sub(lastDemand) > m.cfg.Idle {
		m.release(ctx)
		return
	}
	var job struct {
		State   string `json:"state"`
		Waiting string `json:"waiting"`
	}
	if err := m.call(ctx, http.MethodGet, "/v1/jobs/"+id, nil, &job); err != nil {
		m.log.Warn("sparklease: poll", "err", err)
		return
	}
	switch job.State {
	case "done", "failed", "cancelled", "orphaned":
		m.mu.Lock()
		m.jobID, m.state = "", ""
		m.mu.Unlock()
		return
	}
	m.mu.Lock()
	m.state = job.State
	m.mu.Unlock()
	if now.Sub(lastBeat) >= 2*time.Minute {
		if err := m.call(ctx, http.MethodPost, "/v1/jobs/"+id+"/heartbeat", nil, nil); err == nil {
			m.mu.Lock()
			m.lastBeat = now
			m.mu.Unlock()
		}
		if job.State == "running" {
			// Keep the lease ahead of demand; the broker caps it anyway.
			_ = m.call(ctx, http.MethodPost, fmt.Sprintf("/v1/jobs/%s/extend?minutes=%d", id, 10), nil, nil)
		}
	}
}

func (m *Manager) release(ctx context.Context) {
	m.mu.Lock()
	id, ok, failed := m.jobID, m.ok, m.failed
	m.jobID, m.state, m.ok, m.failed = "", "", 0, 0
	m.mu.Unlock()
	if id == "" {
		return
	}
	body := map[string]any{"metrics": map[string]any{"checkins": map[string]int{"ok": ok, "failed": failed}}}
	if err := m.call(ctx, http.MethodPost, "/v1/jobs/"+id+"/done", body, nil); err != nil {
		m.log.Warn("sparklease: release", "err", err)
		return
	}
	m.log.Info("sparklease: lease released", "job", id, "ok", ok, "failed", failed)
}

func (m *Manager) call(ctx context.Context, method, path string, body, out any) error {
	var rd *bytes.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	} else {
		rd = bytes.NewReader(nil)
	}
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimRight(m.cfg.BrokerURL, "/")+path, rd)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if m.cfg.Token != "" {
		req.Header.Set("Authorization", "Bearer "+m.cfg.Token)
	}
	res, err := m.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		return fmt.Errorf("broker %s %s: status %d", method, path, res.StatusCode)
	}
	if out != nil {
		return json.NewDecoder(res.Body).Decode(out)
	}
	return nil
}
