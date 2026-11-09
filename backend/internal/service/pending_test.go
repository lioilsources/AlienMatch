package service_test

import (
	"bytes"
	"context"
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/service/servicetest"
)

type fakeLease struct {
	ready   bool
	demands int
	ok, bad int
}

func (l *fakeLease) Demand(context.Context) string {
	l.demands++
	if l.ready {
		return "ready"
	}
	return "starting"
}
func (l *fakeLease) Ready() bool { return l.ready }
func (l *fakeLease) Result(ok bool) {
	if ok {
		l.ok++
	} else {
		l.bad++
	}
}

func pendingSvc(t *testing.T) (*Service, *servicetest.Fake, *fakeLease, *fakeScorer, *time.Time) {
	f := servicetest.New()
	f.Settings_["u"] = Settings{VLEnabled: true, Weights: mood.DefaultWeights()}
	now := time.Date(2026, 11, 9, 8, 0, 0, 0, time.UTC)
	l, sc := &fakeLease{}, &fakeScorer{}
	s := &Service{Store: f, Scorer: sc, Lease: l, Pending: &PendingQueue{}, Now: func() time.Time { return now }}
	return s, f, l, sc, &now
}

func TestCheckinWhileModelsStartIsScoredLater(t *testing.T) {
	s, f, l, sc, _ := pendingSvc(t)
	ctx := context.Background()
	if st := s.WarmUp(ctx, "u"); st != "starting" || l.demands != 1 {
		t.Fatalf("warmup=%s demands=%d", st, l.demands)
	}
	in := input()
	r, err := s.CheckinWithMedia(ctx, "u", ModeVideo, 0.8, in)
	if err != nil || r.Signal || !r.Pending || sc.calls != 0 {
		t.Fatalf("r=%+v err=%v calls=%d", r, err, sc.calls)
	}
	if f.Records[0].VL != nil || f.Records[0].Fused.Mood != 0.8 || f.Records[0].Mode != ModeVideo {
		t.Fatalf("stored now: %+v", f.Records[0])
	}
	if in.Audio[0] == 0 {
		t.Fatal("media must stay in memory while waiting")
	}

	s.ProcessPending(ctx) // models not up yet
	if sc.calls != 0 || s.Pending.Len() != 1 {
		t.Fatal("must keep waiting")
	}
	l.ready = true
	s.ProcessPending(ctx)
	if sc.calls != 1 || s.Pending.Len() != 0 || l.ok != 1 {
		t.Fatalf("calls=%d pending=%d ok=%d", sc.calls, s.Pending.Len(), l.ok)
	}
	rec := f.Records[0]
	if rec.VL == nil || rec.Fused.Mood < 0.55 || rec.Fused.Mood > 0.57 {
		t.Fatalf("late score not applied: %+v", rec)
	}
	if f.States["u"].Mood != rec.Fused.Mood {
		t.Fatalf("state not recomputed: %+v", f.States["u"])
	}
	if !bytes.Equal(in.Audio, make([]byte, len(in.Audio))) || in.Frames[0][0] != 0 {
		t.Fatal("media must be zeroed after scoring")
	}
}

func TestPendingRecordingExpires(t *testing.T) {
	s, _, l, sc, now := pendingSvc(t)
	ctx := context.Background()
	in := input()
	_, _ = s.CheckinWithMedia(ctx, "u", ModeVoice, 0.5, in)
	*now = now.Add(PendingMaxAge + time.Minute)
	l.ready = true
	s.ProcessPending(ctx)
	if sc.calls != 0 || s.Pending.Len() != 0 || l.bad != 1 {
		t.Fatalf("expired recording must be dropped unscored: calls=%d pending=%d bad=%d", sc.calls, s.Pending.Len(), l.bad)
	}
	if in.Audio[0] != 0 {
		t.Fatal("expired media must be zeroed")
	}
}

func TestPendingMemoryCap(t *testing.T) {
	s, _, _, _, _ := pendingSvc(t)
	big := moodscore.Input{Audio: make([]byte, PendingMaxBytes/2+1)}
	big.Audio[0] = 1
	r1, _ := s.CheckinWithMedia(context.Background(), "u", ModeVoice, 0.5, big)
	big2 := moodscore.Input{Audio: make([]byte, PendingMaxBytes/2+1)}
	big2.Audio[0] = 1
	r2, _ := s.CheckinWithMedia(context.Background(), "u", ModeVoice, 0.5, big2)
	if !r1.Pending || r2.Pending {
		t.Fatalf("cap: r1=%v r2=%v", r1.Pending, r2.Pending)
	}
	if big2.Audio[0] != 0 {
		t.Fatal("rejected media must be zeroed at once")
	}
}

func TestConsentWithdrawnWhileWaiting(t *testing.T) {
	s, f, l, sc, _ := pendingSvc(t)
	_, _ = s.CheckinWithMedia(context.Background(), "u", ModeVoice, 0.5, input())
	f.Settings_["u"] = Settings{VLEnabled: false, Weights: mood.DefaultWeights()}
	l.ready = true
	s.ProcessPending(context.Background())
	if sc.calls != 0 || f.Records[0].VL != nil {
		t.Fatal("must not score after consent was withdrawn")
	}
}
