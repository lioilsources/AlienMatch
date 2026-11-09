package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

type fakeScorer struct {
	calls int
	last  moodscore.Input
	err   error
}

func (f *fakeScorer) Score(_ context.Context, in moodscore.Input) (mood.VLScore, error) {
	f.calls++
	f.last = moodscore.Input{Frames: append([][]byte(nil), in.Frames...), Audio: in.Audio}
	if f.err != nil {
		return mood.VLScore{}, f.err
	}
	return mood.VLScore{Energy: 0.2, Valence: 0.2, Confidence: 0.9}, nil
}

func mediaSvc(vl bool, sc moodscore.Scorer) (*Service, *servicetest.Fake) {
	f := servicetest.New()
	f.Settings_["u"] = Settings{VLEnabled: vl, Weights: mood.DefaultWeights()}
	return &Service{Store: f, Scorer: sc, Now: func() time.Time { return time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC) }}, f
}

func input() moodscore.Input {
	return moodscore.Input{Frames: [][]byte{{0xFF, 0xD8, 9}}, Audio: []byte{1, 2, 3}}
}

func TestMediaCheckinUsesVLWithConsent(t *testing.T) {
	sc := &fakeScorer{}
	s, f := mediaSvc(true, sc)
	in := input()
	r, err := s.CheckinWithMedia(context.Background(), "u", ModeVideo, 0.8, in)
	if err != nil || !r.Signal || sc.calls != 1 {
		t.Fatalf("r=%+v err=%v calls=%d", r, err, sc.calls)
	}
	rec := f.Records[0]
	if rec.Mode != ModeVideo || rec.VL == nil {
		t.Fatalf("record=%+v", rec)
	}
	// 0.6*0.8 + 0.4*0.2 = 0.56: self keeps the majority.
	if rec.Fused.Mood < 0.55 || rec.Fused.Mood > 0.57 {
		t.Fatalf("fused=%v", rec.Fused.Mood)
	}
	if in.Audio[0] != 0 || in.Frames[0][0] != 0 {
		t.Fatal("media buffers must be zeroed after scoring")
	}
}

func TestMediaCheckinWithoutConsentNeverScores(t *testing.T) {
	sc := &fakeScorer{}
	s, f := mediaSvc(false, sc)
	r, err := s.CheckinWithMedia(context.Background(), "u", ModeVideo, 0.5, input())
	if err != nil || r.Signal || sc.calls != 0 || f.Records[0].Mode != ModeSelf {
		t.Fatalf("r=%+v err=%v calls=%d rec=%+v", r, err, sc.calls, f.Records[0])
	}
}

func TestMediaCheckinFallsBackWhenModelsDown(t *testing.T) {
	sc := &fakeScorer{err: moodscore.ErrUnavailable}
	s, f := mediaSvc(true, sc)
	r, err := s.CheckinWithMedia(context.Background(), "u", ModeVoice, 0.4, input())
	if err != nil || r.Signal || f.Records[0].Mode != ModeSelf || f.Records[0].Fused.Mood != 0.4 {
		t.Fatalf("r=%+v err=%v rec=%+v", r, err, f.Records[0])
	}
	if len(sc.last.Frames) != 0 {
		t.Fatal("voice mode must not send frames")
	}
}

func TestMediaCheckinRejectsSelfMode(t *testing.T) {
	s, _ := mediaSvc(true, &fakeScorer{})
	if _, err := s.CheckinWithMedia(context.Background(), "u", ModeSelf, 0.4, input()); !errors.Is(err, ErrBadMode) {
		t.Fatalf("err=%v", err)
	}
}
