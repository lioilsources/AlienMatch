package mood

import (
	"errors"
	"math"
	"testing"
	"time"
)

var t0 = time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)

func day(i int) time.Time { return t0.Add(time.Duration(i) * 24 * time.Hour) }

func near(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

func TestFuseDefaults(t *testing.T) {
	vl := &VLScore{Energy: 0.8, Valence: 0.6, Confidence: 0.9}
	f, err := Fuse(0.5, vl, DefaultWeights())
	if err != nil {
		t.Fatal(err)
	}
	// 0.6*0.5 + 0.4*0.7 = 0.58
	if !near(f.Mood, 0.58) || !f.UsedVL || f.Disagreement {
		t.Fatalf("got %+v", f)
	}
}

func TestFuseSelfOnlyWhenVLOffOrUnsure(t *testing.T) {
	f, _ := Fuse(0.4, nil, DefaultWeights())
	if f.Mood != 0.4 || f.UsedVL {
		t.Fatalf("vl off: %+v", f)
	}
	f, _ = Fuse(0.4, &VLScore{Energy: 1, Valence: 1, Confidence: 0.1}, DefaultWeights())
	if f.Mood != 0.4 || f.UsedVL {
		t.Fatalf("low confidence: %+v", f)
	}
}

func TestFuseDisagreementNeverOverridesSelf(t *testing.T) {
	f, _ := Fuse(0.9, &VLScore{Energy: 0.1, Valence: 0.1, Confidence: 1}, DefaultWeights())
	if !f.Disagreement {
		t.Fatal("expected disagreement flag")
	}
	// self keeps the majority weight
	if f.Mood < 0.5 {
		t.Fatalf("mood %v dominated by VL", f.Mood)
	}
}

func TestFuseRejectsOutOfRange(t *testing.T) {
	if _, err := Fuse(1.2, nil, DefaultWeights()); !errors.Is(err, ErrOutOfRange) {
		t.Fatalf("err=%v", err)
	}
	if _, err := Fuse(0.5, &VLScore{Energy: -1}, DefaultWeights()); !errors.Is(err, ErrOutOfRange) {
		t.Fatalf("err=%v", err)
	}
}

func TestLevelBoundaries(t *testing.T) {
	cases := map[float64]Level{0: LevelLow, 0.329: LevelLow, 0.33: LevelMid, 0.659: LevelMid, 0.66: LevelHigh, 1: LevelHigh}
	for m, want := range cases {
		if got := LevelOf(m); got != want {
			t.Errorf("LevelOf(%v)=%v want %v", m, got, want)
		}
	}
}

func pts(moods ...float64) []Point {
	var out []Point
	for i, m := range moods {
		out = append(out, Point{At: day(i), Mood: m, Valence: m})
	}
	return out
}

func TestTrend(t *testing.T) {
	cases := []struct {
		name string
		p    []Point
		want Trend
	}{
		{"too few", pts(0.1, 0.9), TrendFlat},
		{"rising", pts(0.3, 0.4, 0.5), TrendRising},
		{"falling", pts(0.8, 0.7, 0.5, 0.4), TrendFalling},
		{"flat", pts(0.5, 0.51, 0.5, 0.51), TrendFlat},
	}
	for _, c := range cases {
		if got := TrendOf(c.p); got != c.want {
			t.Errorf("%s: %v want %v", c.name, got, c.want)
		}
	}
}

func TestComputeUsesLastFiveUnordered(t *testing.T) {
	// Old high points must not affect the trend window; input is shuffled.
	p := pts(0.9, 0.9, 0.9, 0.2, 0.3, 0.4, 0.5, 0.7)
	p[0], p[7] = p[7], p[0]
	now := day(8)
	s, err := Compute(p, now)
	if err != nil {
		t.Fatal(err)
	}
	if s.Level != LevelHigh || s.Trend != TrendRising || !s.LastAt.Equal(day(7)) {
		t.Fatalf("got %+v", s)
	}
	if !s.Fresh(day(7).Add(35*time.Hour)) || s.Fresh(day(7).Add(36*time.Hour)) {
		t.Fatal("freshness boundary wrong")
	}
	if _, err := Compute(nil, now); !errors.Is(err, ErrNoCheckins) {
		t.Fatalf("err=%v", err)
	}
}

func TestNeedsSupport(t *testing.T) {
	if !NeedsSupport(pts(0.2, 0.1, 0.2, 0.15, 0.1)) {
		t.Error("5 LOW days with low valence should need support")
	}
	if NeedsSupport(pts(0.2, 0.1, 0.2, 0.15)) {
		t.Error("4 days is not enough")
	}
	if NeedsSupport(pts(0.2, 0.1, 0.5, 0.15, 0.1)) {
		t.Error("a MID day breaks the streak")
	}
	// Many check-ins on a single day count as one day.
	var same []Point
	for i := range 6 {
		same = append(same, Point{At: t0.Add(time.Duration(i) * time.Hour), Mood: 0.1, Valence: 0.1})
	}
	if NeedsSupport(same) {
		t.Error("one calendar day must not trigger support")
	}
	// Low mood but fine valence: no support card.
	p := pts(0.2, 0.2, 0.2, 0.2, 0.2)
	for i := range p {
		p[i].Valence = 0.6
	}
	if NeedsSupport(p) {
		t.Error("valence ok should not trigger")
	}
}
