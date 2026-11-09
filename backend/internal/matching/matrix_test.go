package matching

import (
	"testing"

	"github.com/lioilsources/Mimo/backend/internal/mood"
)

var allLevels = []mood.Level{mood.LevelLow, mood.LevelMid, mood.LevelHigh}
var allTrends = []mood.Trend{mood.TrendRising, mood.TrendFlat, mood.TrendFalling}

func allSignals() []Signal {
	var out []Signal
	for _, l := range allLevels {
		for _, t := range allTrends {
			out = append(out, Signal{Level: l, Trend: t})
		}
	}
	return out
}

// Hard rule, written first: two LOW users are never connected, whatever the
// trends, flags or settings.
func TestLowTimesLowIsNever(t *testing.T) {
	for _, a := range allSignals() {
		for _, b := range allSignals() {
			if a.Level != mood.LevelLow || b.Level != mood.LevelLow {
				continue
			}
			if got := Cell(a, b); got != RelNever {
				t.Errorf("Cell(%v,%v)=%v, want RelNever", a, b, got)
			}
			for _, opt := range []bool{false, true} {
				r := Decide(
					Party{Signal: a, WantsEncouragement: true, CanBeBeacon: true},
					Party{Signal: b, WantsEncouragement: true, CanBeBeacon: true},
					Options{EnableOptional: opt},
				)
				if r != None {
					t.Errorf("Decide LOW×LOW (%v,%v, optional=%v)=%v, want None", a, b, opt, r)
				}
			}
		}
	}
}

func TestLowNeverGetsRomanticMatch(t *testing.T) {
	for _, a := range allSignals() {
		if a.Level != mood.LevelLow {
			continue
		}
		for _, b := range allSignals() {
			r := Decide(Party{Signal: a, WantsEncouragement: true}, Party{Signal: b, CanBeBeacon: true}, Options{EnableOptional: true})
			if r == Match {
				t.Errorf("LOW %v × %v gave Match", a, b)
			}
		}
	}
}

func TestMatrixIsSymmetric(t *testing.T) {
	for _, a := range allSignals() {
		for _, b := range allSignals() {
			if Cell(a, b) != Cell(b, a) {
				t.Errorf("asymmetric: Cell(%v,%v)=%v Cell(%v,%v)=%v", a, b, Cell(a, b), b, a, Cell(b, a))
			}
		}
	}
}

func sig(l mood.Level, t mood.Trend) Signal { return Signal{Level: l, Trend: t} }

var (
	hUp   = sig(mood.LevelHigh, mood.TrendRising)
	hFlat = sig(mood.LevelHigh, mood.TrendFlat)
	hDown = sig(mood.LevelHigh, mood.TrendFalling)
	mUp   = sig(mood.LevelMid, mood.TrendRising)
	mFlat = sig(mood.LevelMid, mood.TrendFlat)
	mDown = sig(mood.LevelMid, mood.TrendFalling)
	low   = sig(mood.LevelLow, mood.TrendRising)
)

// Table from SEZNAMKA_PLAN §1.3, row A × column B.
func TestMatrixMatchesPlan(t *testing.T) {
	cases := []struct {
		a, b Signal
		want Relation
	}{
		{hUp, hUp, RelMatch}, {hUp, hFlat, RelMatch}, {hUp, hDown, RelMatch}, {hUp, mUp, RelMatch},
		{hUp, mFlat, RelOptional}, {hUp, mDown, RelOptional}, {hUp, low, RelEncourage},
		{hFlat, hFlat, RelMatch}, {hFlat, hDown, RelOptional}, {hFlat, mUp, RelOptional},
		{hFlat, mFlat, RelOptional}, {hFlat, low, RelEncourage},
		{hDown, hDown, RelNever}, {hDown, mUp, RelOptional}, {hDown, mFlat, RelNever}, {hDown, low, RelNever},
		{mUp, mUp, RelOptional}, {mUp, mFlat, RelNever}, {mUp, mDown, RelNever}, {mUp, low, RelNever},
		{mFlat, mFlat, RelNever}, {mDown, mFlat, RelNever}, {mFlat, low, RelNever},
		{low, low, RelNever},
	}
	for _, c := range cases {
		if got := Cell(c.a, c.b); got != c.want {
			t.Errorf("Cell(%v,%v)=%v, want %v", c.a, c.b, got, c.want)
		}
	}
}

func TestOptionalCellsOffInMVP(t *testing.T) {
	a, b := Party{Signal: hUp}, Party{Signal: mFlat}
	if r := Decide(a, b, Options{}); r != None {
		t.Errorf("optional cell in MVP = %v, want None", r)
	}
	if r := Decide(a, b, Options{EnableOptional: true}); r != Match {
		t.Errorf("optional cell enabled = %v, want Match", r)
	}
}

func TestEncouragementNeedsBothOptIns(t *testing.T) {
	beacon := Party{Signal: hUp, CanBeBeacon: true}
	seeker := Party{Signal: low, WantsEncouragement: true}
	if r := Decide(beacon, seeker, Options{}); r != Encourage {
		t.Errorf("both opt-in = %v, want Encourage", r)
	}
	if r := Decide(seeker, beacon, Options{}); r != Encourage {
		t.Errorf("reversed order = %v, want Encourage", r)
	}
	if r := Decide(Party{Signal: hUp}, seeker, Options{}); r != None {
		t.Errorf("no beacon opt-in = %v, want None", r)
	}
	if r := Decide(beacon, Party{Signal: low}, Options{}); r != None {
		t.Errorf("no seeker opt-in = %v, want None", r)
	}
}

func TestSupportPausePausesRomanceKeepsEncouragement(t *testing.T) {
	a := Party{Signal: hUp, SupportPause: true}
	if r := Decide(a, Party{Signal: hUp}, Options{}); r != None {
		t.Errorf("support pause romantic = %v, want None", r)
	}
	seeker := Party{Signal: low, WantsEncouragement: true, SupportPause: true}
	if r := Decide(Party{Signal: hUp, CanBeBeacon: true}, seeker, Options{}); r != Encourage {
		t.Errorf("support pause encouragement = %v, want Encourage", r)
	}
}
