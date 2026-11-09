package service

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
)

// ScoreTimeout keeps a synchronous check-in snappy (plan: score within 5 s).
const ScoreTimeout = 8 * time.Second

// Models are started on demand through the SPARK broker. While they start,
// a recording waits in memory only, bounded in time and size; it is never
// written to disk and is zeroed right after scoring or when it expires.
const (
	PendingMaxAge   = 15 * time.Minute
	PendingMaxBytes = 24 << 20
)

// Lease is the on-demand model lifecycle (sparklease.Manager). Nil means the
// models are always on (e.g. a dedicated server).
type Lease interface {
	Demand(ctx context.Context) string // off | starting | ready
	Ready() bool
	Result(ok bool)
}

// MediaCheckinResult adds whether a VL signal was used or is still coming.
type MediaCheckinResult struct {
	CheckinResult
	Signal  bool // scored now
	Pending bool // will be scored as soon as the models are up
}

// MoodScoringAvailable tells the app whether recording makes sense at all.
func (s *Service) MoodScoringAvailable() bool { return s.Scorer != nil }

// WarmUp asks for the models when a consenting user opens the check-in, so
// they are likely up by the time the recording is done.
func (s *Service) WarmUp(ctx context.Context, me string) string {
	if s.Scorer == nil {
		return "off"
	}
	set, err := s.Store.Settings(ctx, me)
	if err != nil || !set.VLEnabled {
		return "off"
	}
	if s.Lease == nil {
		return "ready"
	}
	return s.Lease.Demand(ctx)
}

// CheckinWithMedia scores the recording if the user consented and scoring is
// configured. With the models up it scores at once; otherwise it stores the
// check-in with the user's own rating now and scores the recording later.
func (s *Service) CheckinWithMedia(ctx context.Context, me string, mode Mode, self float64, in moodscore.Input) (MediaCheckinResult, error) {
	keep := false
	defer func() {
		if !keep {
			wipe(in)
		}
	}()
	if mode != ModeVideo && mode != ModeVoice {
		return MediaCheckinResult{}, ErrBadMode
	}
	if mode == ModeVoice {
		in.Frames = nil
	}
	set, err := s.Store.Settings(ctx, me)
	if err != nil {
		return MediaCheckinResult{}, err
	}
	if !set.VLEnabled || s.Scorer == nil {
		res, err := s.Checkin(ctx, me, ModeSelf, self, nil)
		return MediaCheckinResult{CheckinResult: res}, err
	}
	ready := s.Lease == nil || s.Lease.Demand(ctx) == "ready"
	if ready {
		sctx, cancel := context.WithTimeout(ctx, ScoreTimeout)
		vl, err := s.Scorer.Score(sctx, in)
		cancel()
		if s.Lease != nil {
			s.Lease.Result(err == nil)
		}
		if err == nil {
			res, err := s.Checkin(ctx, me, mode, self, &vl)
			return MediaCheckinResult{CheckinResult: res, Signal: true}, err
		}
		res, err := s.Checkin(ctx, me, ModeSelf, self, nil)
		return MediaCheckinResult{CheckinResult: res}, err
	}
	// Models starting: record now with the user's own rating, score later.
	id, res, err := s.checkin(ctx, me, mode, self, nil)
	if err != nil {
		return MediaCheckinResult{}, err
	}
	if s.Pending != nil && s.Pending.Add(PendingCheckin{UserID: me, CheckinID: id, Self: self, Input: in, At: s.Now()}) {
		keep = true
		return MediaCheckinResult{CheckinResult: res, Pending: true}, nil
	}
	return MediaCheckinResult{CheckinResult: res}, nil
}

// PendingCheckin is a recording waiting for the models (memory only).
type PendingCheckin struct {
	UserID    string
	CheckinID int64
	Self      float64
	Input     moodscore.Input
	At        time.Time
}

func (p PendingCheckin) size() int {
	n := len(p.Input.Audio)
	for _, f := range p.Input.Frames {
		n += len(f)
	}
	return n
}

// PendingQueue bounds what waits in memory.
type PendingQueue struct {
	mu    sync.Mutex
	items []PendingCheckin
	bytes int
}

// Add enqueues unless the memory budget is exhausted.
func (q *PendingQueue) Add(p PendingCheckin) bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	if q.bytes+p.size() > PendingMaxBytes {
		return false
	}
	q.items = append(q.items, p)
	q.bytes += p.size()
	return true
}

// Len is the number of waiting recordings.
func (q *PendingQueue) Len() int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return len(q.items)
}

func (q *PendingQueue) take() []PendingCheckin {
	q.mu.Lock()
	defer q.mu.Unlock()
	out := q.items
	q.items, q.bytes = nil, 0
	return out
}

// ProcessPending drops expired recordings and, if the models are up, scores
// the rest and updates their check-ins. Called periodically by the server.
func (s *Service) ProcessPending(ctx context.Context) {
	if s.Pending == nil || s.Pending.Len() == 0 {
		return
	}
	now := s.Now()
	ready := s.Lease == nil || s.Lease.Ready()
	if !ready && s.Lease != nil {
		s.Lease.Demand(ctx) // keep the lease alive while recordings wait
	}
	for _, p := range s.Pending.take() {
		if now.Sub(p.At) > PendingMaxAge {
			wipe(p.Input)
			if s.Lease != nil {
				s.Lease.Result(false)
			}
			continue
		}
		if !ready {
			s.Pending.Add(p) // still waiting
			continue
		}
		err := s.scoreLate(ctx, p)
		wipe(p.Input)
		if s.Lease != nil {
			s.Lease.Result(err == nil)
		}
	}
}

func (s *Service) scoreLate(ctx context.Context, p PendingCheckin) error {
	set, err := s.Store.Settings(ctx, p.UserID)
	if err != nil || !set.VLEnabled {
		return fmt.Errorf("late score: consent gone or user missing")
	}
	sctx, cancel := context.WithTimeout(ctx, ScoreTimeout)
	vl, err := s.Scorer.Score(sctx, p.Input)
	cancel()
	if err != nil {
		return err
	}
	fused, err := mood.Fuse(p.Self, &vl, set.Weights)
	if err != nil {
		return err
	}
	if err := s.Store.ApplyCheckinVL(ctx, p.UserID, p.CheckinID, vl, fused); err != nil {
		return err
	}
	_, _, err = s.Recompute(ctx, p.UserID)
	return err
}

func wipe(in moodscore.Input) {
	for _, f := range in.Frames {
		clear(f)
	}
	clear(in.Audio)
}
