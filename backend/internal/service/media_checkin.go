package service

import (
	"context"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
)

// ScoreTimeout keeps the check-in snappy (plan: score within 5 s).
const ScoreTimeout = 8 * time.Second

// MediaCheckinResult adds whether a VL signal was used.
type MediaCheckinResult struct {
	CheckinResult
	Signal bool
}

// MoodScoringAvailable tells the app whether recording makes sense at all.
func (s *Service) MoodScoringAvailable() bool { return s.Scorer != nil }

// CheckinWithMedia scores the recording (if the user consented and scoring
// runs), then stores scores only. The media is never stored: it lives in
// memory for the duration of this call and is zeroed afterwards.
func (s *Service) CheckinWithMedia(ctx context.Context, me string, mode Mode, self float64, in moodscore.Input) (MediaCheckinResult, error) {
	defer wipe(in)
	if mode != ModeVideo && mode != ModeVoice {
		return MediaCheckinResult{}, ErrBadMode
	}
	if mode == ModeVoice {
		in.Frames = nil // voice-only: no frames even if sent
	}
	set, err := s.Store.Settings(ctx, me)
	if err != nil {
		return MediaCheckinResult{}, err
	}
	var used bool
	res, err := func() (CheckinResult, error) {
		if !set.VLEnabled || s.Scorer == nil {
			return s.Checkin(ctx, me, ModeSelf, self, nil)
		}
		sctx, cancel := context.WithTimeout(ctx, ScoreTimeout)
		defer cancel()
		vl, err := s.Scorer.Score(sctx, in)
		if err != nil {
			// Advisory only: fall back to the user's own rating.
			return s.Checkin(ctx, me, ModeSelf, self, nil)
		}
		used = true
		return s.Checkin(ctx, me, mode, self, &vl)
	}()
	if err != nil {
		return MediaCheckinResult{}, err
	}
	return MediaCheckinResult{CheckinResult: res, Signal: used}, nil
}

func wipe(in moodscore.Input) {
	for _, f := range in.Frames {
		clear(f)
	}
	clear(in.Audio)
}
