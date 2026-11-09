// Package mood turns daily check-in scores into a (level, trend) state.
//
// Product vocabulary rule: this package talks about "mood / energy / signal".
// Never expose diagnostic words in anything user-facing.
package mood

import (
	"errors"
	"fmt"
	"math"
	"sort"
	"time"
)

// Level is the coarse mood level.
type Level string

const (
	LevelLow  Level = "LOW"
	LevelMid  Level = "MID"
	LevelHigh Level = "HIGH"
)

// Trend is the direction of mood over the last few check-ins.
type Trend string

const (
	TrendRising  Trend = "RISING"
	TrendFlat    Trend = "FLAT"
	TrendFalling Trend = "FALLING"
)

// Level thresholds from the plan: HIGH >= 0.66, MID 0.33-0.66, LOW < 0.33.
const (
	HighThreshold = 0.66
	LowThreshold  = 0.33
)

// Defaults for fusion and trend; tune with beta data.
const (
	DefaultSelfWeight = 0.6
	DefaultVLWeight   = 0.4
	// MinVLConfidence below this the VL score is ignored for the check-in.
	MinVLConfidence = 0.3
	// DisagreementThreshold flags a gentle re-ask tomorrow; self score still wins.
	DisagreementThreshold = 0.35
	// FlatSlopePerDay is the |slope| under which a trend counts as flat.
	FlatSlopePerDay = 0.02
	// TrendMinPoints / TrendMaxPoints bound the regression window (plan: 3-5 check-ins).
	TrendMinPoints = 3
	TrendMaxPoints = 5
	// Freshness: only states younger than this enter matching.
	Freshness = 36 * time.Hour
)

// ErrOutOfRange is returned for scores outside 0..1.
var ErrOutOfRange = errors.New("mood: score out of range 0..1")

// VLScore is the structured JSON returned by the VL model on SPARK.
type VLScore struct {
	Energy     float64 `json:"energy"`
	Valence    float64 `json:"valence"`
	Confidence float64 `json:"confidence"`
}

// Validate checks all fields are within 0..1.
func (v VLScore) Validate() error {
	for name, x := range map[string]float64{"energy": v.Energy, "valence": v.Valence, "confidence": v.Confidence} {
		if !in01(x) {
			return fmt.Errorf("%s=%v: %w", name, x, ErrOutOfRange)
		}
	}
	return nil
}

// Value collapses energy and valence into one 0..1 number.
func (v VLScore) Value() float64 { return (v.Energy + v.Valence) / 2 }

// Weights are per-user fusion weights; they are normalised before use.
type Weights struct {
	Self float64
	VL   float64
}

// DefaultWeights returns the starting weights from the plan.
func DefaultWeights() Weights { return Weights{Self: DefaultSelfWeight, VL: DefaultVLWeight} }

// Fused is the result of combining self and VL scores for one check-in.
type Fused struct {
	Mood float64
	// UsedVL is false when VL was disabled, missing, or low-confidence.
	UsedVL bool
	// Disagreement is true when VL and self differ a lot; the app re-asks tomorrow.
	Disagreement bool
}

// Fuse combines the self score with an optional VL score.
// vl == nil means the user turned VL off ("no signal" profile) or scoring failed.
func Fuse(self float64, vl *VLScore, w Weights) (Fused, error) {
	if !in01(self) {
		return Fused{}, fmt.Errorf("self=%v: %w", self, ErrOutOfRange)
	}
	if vl == nil {
		return Fused{Mood: self}, nil
	}
	if err := vl.Validate(); err != nil {
		return Fused{}, err
	}
	if vl.Confidence < MinVLConfidence || w.Self+w.VL <= 0 || w.Self < 0 || w.VL < 0 {
		return Fused{Mood: self}, nil
	}
	sum := w.Self + w.VL
	v := vl.Value()
	m := (w.Self*self + w.VL*v) / sum
	return Fused{
		Mood:         clamp01(m),
		UsedVL:       true,
		Disagreement: math.Abs(self-v) > DisagreementThreshold,
	}, nil
}

// LevelOf classifies a mood value.
func LevelOf(m float64) Level {
	switch {
	case m >= HighThreshold:
		return LevelHigh
	case m >= LowThreshold:
		return LevelMid
	default:
		return LevelLow
	}
}

// Point is one fused check-in in time.
type Point struct {
	At      time.Time
	Mood    float64
	Valence float64 // VL valence if available, else equal to Mood
}

// State is the materialised (level, trend) used by matching.
type State struct {
	Level      Level
	Trend      Trend
	Mood       float64 // latest fused mood
	ComputedAt time.Time
	LastAt     time.Time // time of the latest check-in
}

// Fresh reports whether the state may enter matching at time now.
func (s State) Fresh(now time.Time) bool {
	return !s.LastAt.IsZero() && now.Sub(s.LastAt) < Freshness
}

// ErrNoCheckins is returned by Compute with an empty history.
var ErrNoCheckins = errors.New("mood: no check-ins")

// Compute derives the state from check-in history (any order).
// Level comes from the latest check-in, trend from the slope over the
// last TrendMaxPoints check-ins (FLAT with fewer than TrendMinPoints).
func Compute(points []Point, now time.Time) (State, error) {
	if len(points) == 0 {
		return State{}, ErrNoCheckins
	}
	ps := sortedCopy(points)
	last := ps[len(ps)-1]
	window := ps
	if len(window) > TrendMaxPoints {
		window = window[len(window)-TrendMaxPoints:]
	}
	return State{
		Level:      LevelOf(last.Mood),
		Trend:      TrendOf(window),
		Mood:       last.Mood,
		ComputedAt: now,
		LastAt:     last.At,
	}, nil
}

// TrendOf classifies the least-squares slope (mood per day) of the points.
func TrendOf(points []Point) Trend {
	if len(points) < TrendMinPoints {
		return TrendFlat
	}
	s, ok := Slope(points)
	switch {
	case !ok || math.Abs(s) < FlatSlopePerDay:
		return TrendFlat
	case s > 0:
		return TrendRising
	default:
		return TrendFalling
	}
}

// Slope returns the least-squares slope of mood over time, in mood units per day.
// ok is false when all points share the same timestamp.
func Slope(points []Point) (slope float64, ok bool) {
	n := float64(len(points))
	if n < 2 {
		return 0, false
	}
	t0 := points[0].At
	var sx, sy float64
	xs := make([]float64, len(points))
	for i, p := range points {
		xs[i] = p.At.Sub(t0).Hours() / 24
		sx += xs[i]
		sy += p.Mood
	}
	mx, my := sx/n, sy/n
	var num, den float64
	for i, p := range points {
		dx := xs[i] - mx
		num += dx * (p.Mood - my)
		den += dx * dx
	}
	if den == 0 {
		return 0, false
	}
	return num / den, true
}

// Support thresholds: repeated LOW plus low valence pauses romantic matching
// and shows the help card (CZ: 116 123).
const (
	SupportLowDays    = 5
	SupportMaxValence = 0.33
)

// NeedsSupport reports whether the last SupportLowDays distinct calendar days
// (UTC) with check-ins were all LOW and their mean valence is low.
// When true: romantic matching pauses, encouragement stays available, the
// help card is shown. Nothing is diagnosed.
func NeedsSupport(points []Point) bool {
	ps := sortedCopy(points)
	byDay := map[string]Point{}
	var days []string
	for _, p := range ps {
		d := p.At.UTC().Format(time.DateOnly)
		if _, seen := byDay[d]; !seen {
			days = append(days, d)
		}
		byDay[d] = p // keep the latest per day
	}
	if len(days) < SupportLowDays {
		return false
	}
	var val float64
	for _, d := range days[len(days)-SupportLowDays:] {
		p := byDay[d]
		if LevelOf(p.Mood) != LevelLow {
			return false
		}
		val += p.Valence
	}
	return val/SupportLowDays < SupportMaxValence
}

func sortedCopy(points []Point) []Point {
	ps := append([]Point(nil), points...)
	sort.SliceStable(ps, func(i, j int) bool { return ps[i].At.Before(ps[j].At) })
	return ps
}

func in01(x float64) bool { return x >= 0 && x <= 1 && !math.IsNaN(x) }

func clamp01(x float64) float64 { return math.Max(0, math.Min(1, x)) }
