// Package matching decides which pairs of users may see each other on the radar.
//
// The LOW × LOW rule is hard-coded and not configurable. It is also enforced
// by a database trigger (see db/migrations) so no code path can bypass it.
package matching

import "github.com/lioilsources/Mimo/backend/internal/mood"

// Signal is a user's current (level, trend).
type Signal struct {
	Level mood.Level
	Trend mood.Trend
}

func (s Signal) String() string { return string(s.Level) + "/" + string(s.Trend) }

// Relation is a raw matrix cell.
type Relation int

const (
	RelNever     Relation = iota // ❌
	RelOptional                  // ⚪ off in MVP, A/B later
	RelMatch                     // ✅
	RelEncourage                 // 💛 asymmetric, non-romantic
)

func (r Relation) String() string {
	return [...]string{"never", "optional", "match", "encourage"}[r]
}

// Result is the final decision for a pair.
type Result int

const (
	None Result = iota
	Match
	Encourage
)

func (r Result) String() string { return [...]string{"none", "match", "encourage"}[r] }

type bucket int

const (
	bHighUp bucket = iota
	bHighFlat
	bHighDown
	bMidUp
	bMidOther // MID flat or falling
	bLow      // any trend
)

func bucketOf(s Signal) bucket {
	switch s.Level {
	case mood.LevelHigh:
		switch s.Trend {
		case mood.TrendRising:
			return bHighUp
		case mood.TrendFalling:
			return bHighDown
		default:
			return bHighFlat
		}
	case mood.LevelMid:
		if s.Trend == mood.TrendRising {
			return bMidUp
		}
		return bMidOther
	default:
		// Unknown levels are treated as LOW: the safe side.
		return bLow
	}
}

const (
	n = RelNever
	o = RelOptional
	m = RelMatch
	e = RelEncourage
)

// matrix[A][B] from SEZNAMKA_PLAN §1.3. Must stay symmetric (tested).
var matrix = [6][6]Relation{
	//            H↑ H→ H↓ M↑ M→↓ LOW
	bHighUp:   {m, m, m, m, o, e},
	bHighFlat: {m, m, o, o, o, e},
	bHighDown: {m, o, n, o, n, n},
	bMidUp:    {m, o, o, o, n, n},
	bMidOther: {o, o, n, n, n, n},
	bLow:      {e, e, n, n, n, n},
}

// Cell returns the raw matrix relation for A × B.
func Cell(a, b Signal) Relation {
	ba, bb := bucketOf(a), bucketOf(b)
	if ba == bLow && bb == bLow {
		return RelNever // hard rule, independent of the table
	}
	return matrix[ba][bb]
}

// Party is one side of a pair, with the opt-ins that matter for matching.
type Party struct {
	Signal Signal
	// WantsEncouragement: "I want someone to cheer me up" (default off).
	WantsEncouragement bool
	// CanBeBeacon: "I can be a beacon" (default off).
	CanBeBeacon bool
	// SupportPause: repeated LOW with low valence; romance paused.
	SupportPause bool
}

// Options are rollout switches. The zero value is the MVP.
type Options struct {
	// EnableOptional turns ⚪ cells into matches (A/B after data).
	EnableOptional bool
}

// Decide applies the matrix plus opt-ins and safety pauses.
// Filters like generation, status, region and intents are applied elsewhere.
func Decide(a, b Party, opt Options) Result {
	if bucketOf(a.Signal) == bLow && bucketOf(b.Signal) == bLow {
		return None
	}
	switch Cell(a.Signal, b.Signal) {
	case RelMatch:
		return romantic(a, b)
	case RelOptional:
		if opt.EnableOptional {
			return romantic(a, b)
		}
		return None
	case RelEncourage:
		beacon, seeker := a, b
		if bucketOf(a.Signal) == bLow {
			beacon, seeker = b, a
		}
		if beacon.CanBeBeacon && seeker.WantsEncouragement && !beacon.SupportPause {
			return Encourage
		}
		return None
	default:
		return None
	}
}

func romantic(a, b Party) Result {
	if a.SupportPause || b.SupportPause {
		return None
	}
	return Match
}
