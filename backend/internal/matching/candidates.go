package matching

import (
	"slices"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
)

// Generation flag; no numeric age anywhere in the product.
type Generation string

const (
	GenZ       Generation = "genz"
	Millennial Generation = "millennial"
	GenX       Generation = "genx"
	BabyBoomer Generation = "boomer"
)

// Status is the relationship status icon.
type Status string

const (
	StatusSingle      Status = "single"
	StatusMarried     Status = "married"
	StatusDivorced    Status = "divorced"
	StatusComplicated Status = "complicated"
)

// Intent is an intent sticker.
type Intent string

const (
	IntentFlirt Intent = "flirt"
	IntentSex   Intent = "sex"
	IntentChat  Intent = "chat"
	IntentCafe  Intent = "coffee"
	IntentBeer  Intent = "beer"
	IntentWine  Intent = "wine"
	IntentTea   Intent = "tea"
	IntentWalk  Intent = "walk"
	IntentPlay  Intent = "play"
)

// EncouragementIntents are the only intents allowed on an encouragement wall.
var EncouragementIntents = []Intent{IntentChat, IntentCafe, IntentTea}

// Profile is the matching-relevant view of a user.
type Profile struct {
	ID         string
	Generation Generation
	Status     Status
	Intents    []Intent
	SeekGens   []Generation // empty = any
	SeekStatus []Status     // empty = any
	Region     string       // coarse: district/region code, never GPS
	State      mood.State
	Party      Party // Signal is filled from State by Candidates
}

// Candidate is a profile allowed on the radar, with the kind of relation.
type Candidate struct {
	Profile Profile
	Result  Result
	// SharedIntents are the intents both sides selected (restricted for encouragement).
	SharedIntents []Intent
}

// Candidates returns the profiles that `me` may see on the radar at time now.
// Stale states (older than mood.Freshness) are off the radar on both sides.
func Candidates(me Profile, pool []Profile, now time.Time, opt Options) []Candidate {
	if !me.State.Fresh(now) {
		return nil
	}
	me.Party.Signal = signalOf(me.State)
	var out []Candidate
	for _, p := range pool {
		if p.ID == me.ID || !p.State.Fresh(now) || p.Region != me.Region {
			continue
		}
		if !wants(me, p) || !wants(p, me) {
			continue
		}
		p.Party.Signal = signalOf(p.State)
		r := Decide(me.Party, p.Party, opt)
		if r == None {
			continue
		}
		shared := intersect(me.Intents, p.Intents)
		if r == Encourage {
			shared = intersect(shared, EncouragementIntents)
		}
		if len(shared) == 0 {
			continue
		}
		out = append(out, Candidate{Profile: p, Result: r, SharedIntents: shared})
	}
	return out
}

func signalOf(s mood.State) Signal { return Signal{Level: s.Level, Trend: s.Trend} }

// wants reports whether a's "looking for" filters accept b.
func wants(a, b Profile) bool {
	if len(a.SeekGens) > 0 && !slices.Contains(a.SeekGens, b.Generation) {
		return false
	}
	if len(a.SeekStatus) > 0 && !slices.Contains(a.SeekStatus, b.Status) {
		return false
	}
	return true
}

func intersect(a, b []Intent) []Intent {
	var out []Intent
	for _, x := range a {
		if slices.Contains(b, x) && !slices.Contains(out, x) {
			out = append(out, x)
		}
	}
	return out
}
