// Package service holds the use cases: check-in ingest and the radar.
package service

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
)

// HistoryWindow is how many recent check-ins are loaded to compute state.
// It must cover mood.SupportLowDays distinct days.
const HistoryWindow = 30

// Settings are a user's scoring settings.
type Settings struct {
	VLEnabled bool
	Weights   mood.Weights
}

// Mode is how the check-in was recorded. Media never reach the API.
type Mode string

const (
	ModeVideo Mode = "video" // video + voice (default)
	ModeVoice Mode = "voice" // voice-only fallback
	ModeSelf  Mode = "self"  // self scale only: VL off or no recording ("no signal")
)

// ErrBadMode is returned for an unknown check-in mode.
var ErrBadMode = errors.New("service: bad check-in mode")

// CheckinRecord is what gets persisted: scores only, never media.
type CheckinRecord struct {
	UserID string
	At     time.Time
	Mode   Mode
	Self   float64
	VL     *mood.VLScore
	Fused  mood.Fused
}

// Store is the persistence port; implemented over Postgres in internal/store.
type Store interface {
	Settings(ctx context.Context, userID string) (Settings, error)
	InsertCheckin(ctx context.Context, c CheckinRecord) (int64, error)
	ApplyCheckinVL(ctx context.Context, userID string, id int64, vl mood.VLScore, fused mood.Fused) error
	RecentCheckins(ctx context.Context, userID string, limit int) ([]mood.Point, error)
	SaveState(ctx context.Context, userID string, s mood.State, supportPause bool) error
	Region(ctx context.Context, userID string) (string, error)
	Pool(ctx context.Context, region string, freshAfter time.Time) ([]matching.Profile, error)
	PlaceStore
}

// ErrNotFound is returned when the user has no profile or state.
var ErrNotFound = errors.New("service: not found")

// Service wires the domain logic to the store. Now is injected for tests.
type Service struct {
	Store    Store
	Accounts AccountStore
	Media    MediaStore
	Walls    WallStore
	Flyby    FlybyStore
	Admin    AdminStore
	// Scorer is nil when the mood models on SPARK are not configured.
	Scorer moodscore.Scorer
	// Lease starts the models on demand (nil = always on); Pending holds
	// recordings in memory while they start.
	Lease   Lease
	Pending *PendingQueue
	Pub     Publisher
	Now     func() time.Time
	Options matching.Options
}

// CheckinResult is returned to the app after a check-in.
type CheckinResult struct {
	State        mood.State
	SupportPause bool // app shows the gentle help card
	AskAgain     bool // VL and self disagreed; re-ask tomorrow
}

// Checkin fuses scores, stores them and recomputes the user's state.
func (s *Service) Checkin(ctx context.Context, userID string, mode Mode, self float64, vl *mood.VLScore) (CheckinResult, error) {
	_, res, err := s.checkin(ctx, userID, mode, self, vl)
	return res, err
}

// checkin stores one check-in and returns its id (for a late VL score).
func (s *Service) checkin(ctx context.Context, userID string, mode Mode, self float64, vl *mood.VLScore) (int64, CheckinResult, error) {
	if mode != ModeVideo && mode != ModeVoice && mode != ModeSelf {
		return 0, CheckinResult{}, ErrBadMode
	}
	if mode == ModeSelf {
		vl = nil
	}
	set, err := s.Store.Settings(ctx, userID)
	if err != nil {
		return 0, CheckinResult{}, fmt.Errorf("settings: %w", err)
	}
	if !set.VLEnabled {
		vl = nil
	}
	fused, err := mood.Fuse(self, vl, set.Weights)
	if err != nil {
		return 0, CheckinResult{}, err
	}
	now := s.Now()
	id, err := s.Store.InsertCheckin(ctx, CheckinRecord{UserID: userID, At: now, Mode: mode, Self: self, VL: vl, Fused: fused})
	if err != nil {
		return 0, CheckinResult{}, fmt.Errorf("insert checkin: %w", err)
	}
	st, pause, err := s.Recompute(ctx, userID)
	if err != nil {
		return 0, CheckinResult{}, err
	}
	return id, CheckinResult{State: st, SupportPause: pause, AskAgain: fused.Disagreement}, nil
}

// Recompute derives and saves (level, trend) from history. The matching job
// calls it every 10 minutes too.
func (s *Service) Recompute(ctx context.Context, userID string) (mood.State, bool, error) {
	pts, err := s.Store.RecentCheckins(ctx, userID, HistoryWindow)
	if err != nil {
		return mood.State{}, false, fmt.Errorf("recent checkins: %w", err)
	}
	st, err := mood.Compute(pts, s.Now())
	if err != nil {
		return mood.State{}, false, err
	}
	pause := mood.NeedsSupport(pts)
	if err := s.Store.SaveState(ctx, userID, st, pause); err != nil {
		return mood.State{}, false, fmt.Errorf("save state: %w", err)
	}
	return st, pause, nil
}

// RadarEntry is one planet: a candidate plus what may be shown about shared places.
type RadarEntry struct {
	Candidate     matching.Candidate
	Constellation places.Constellation
	// Comet is the contact type of a mutual fly-by (vehicle | stop | venue), or "".
	Comet string
}

// Radar returns candidates for userID in their own (coarse) region, ranked
// by shared places. The ranking score never leaves the server.
func (s *Service) Radar(ctx context.Context, userID string) ([]RadarEntry, error) {
	region, err := s.Store.Region(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("region: %w", err)
	}
	now := s.Now()
	pool, err := s.Store.Pool(ctx, region, now.Add(-mood.Freshness))
	if err != nil {
		return nil, fmt.Errorf("pool: %w", err)
	}
	idx := slices.IndexFunc(pool, func(p matching.Profile) bool { return p.ID == userID })
	if idx < 0 {
		// Not in the fresh pool: no check-in in 36 h, user is off the radar.
		return nil, ErrNotFound
	}
	me := pool[idx]
	if s.Walls != nil {
		// Blocked either way or already matched: never on each other's radar.
		ex, err := s.Walls.RadarExclusions(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("radar exclusions: %w", err)
		}
		pool = slices.DeleteFunc(slices.Clone(pool), func(p matching.Profile) bool { return slices.Contains(ex, p.ID) })
	}
	cands := matching.Candidates(me, pool, now, s.Options)
	counts, err := s.Store.PlaceCounts(ctx, me.Places)
	if err != nil {
		return nil, fmt.Errorf("place counts: %w", err)
	}
	ranked := places.Rank(me.Places, cands, func(c matching.Candidate) []string { return c.Profile.Places }, counts)
	comets, err := s.comets(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("comets: %w", err)
	}
	out := make([]RadarEntry, len(ranked))
	for i, r := range ranked {
		out[i] = RadarEntry{Candidate: r.Item, Constellation: r.Constellation, Comet: comets[r.Item.Profile.ID]}
	}
	return out, nil
}
