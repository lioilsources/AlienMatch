package matching

import (
	"testing"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
)

var now = time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC)

func prof(id string, l mood.Level, t mood.Trend, ago time.Duration, intents ...Intent) Profile {
	return Profile{
		ID: id, Generation: Millennial, Status: StatusSingle, Region: "CZ-PHA",
		Intents: intents,
		State:   mood.State{Level: l, Trend: t, LastAt: now.Add(-ago)},
	}
}

func TestCandidatesFreshnessAndFilters(t *testing.T) {
	me := prof("me", mood.LevelHigh, mood.TrendRising, time.Hour, IntentCafe, IntentFlirt)
	pool := []Profile{
		me,
		prof("ok", mood.LevelHigh, mood.TrendFlat, 2*time.Hour, IntentFlirt),
		prof("stale", mood.LevelHigh, mood.TrendFlat, 37*time.Hour, IntentFlirt),
		prof("nointent", mood.LevelHigh, mood.TrendFlat, time.Hour, IntentBeer),
		prof("never", mood.LevelMid, mood.TrendFalling, time.Hour, IntentFlirt),
	}
	other := prof("region", mood.LevelHigh, mood.TrendFlat, time.Hour, IntentFlirt)
	other.Region = "CZ-JHM"
	gen := prof("gen", mood.LevelHigh, mood.TrendFlat, time.Hour, IntentFlirt)
	gen.SeekGens = []Generation{GenX}
	pool = append(pool, other, gen)

	got := Candidates(me, pool, now, Options{})
	if len(got) != 1 || got[0].Profile.ID != "ok" || got[0].Result != Match {
		t.Fatalf("got %+v, want only ok/match", got)
	}
}

func TestStaleMeSeesNobody(t *testing.T) {
	me := prof("me", mood.LevelHigh, mood.TrendRising, 40*time.Hour, IntentCafe)
	pool := []Profile{prof("x", mood.LevelHigh, mood.TrendRising, time.Hour, IntentCafe)}
	if got := Candidates(me, pool, now, Options{}); got != nil {
		t.Fatalf("stale me got %v", got)
	}
}

func TestEncouragementRestrictsIntents(t *testing.T) {
	beacon := prof("b", mood.LevelHigh, mood.TrendRising, time.Hour, IntentFlirt, IntentSex, IntentTea)
	beacon.Party.CanBeBeacon = true
	seeker := prof("s", mood.LevelLow, mood.TrendFlat, time.Hour, IntentFlirt, IntentTea)
	seeker.Party.WantsEncouragement = true

	got := Candidates(beacon, []Profile{seeker}, now, Options{})
	if len(got) != 1 || got[0].Result != Encourage {
		t.Fatalf("got %+v, want encourage", got)
	}
	if len(got[0].SharedIntents) != 1 || got[0].SharedIntents[0] != IntentTea {
		t.Fatalf("shared=%v, want [tea]", got[0].SharedIntents)
	}

	seeker.Intents = []Intent{IntentFlirt}
	if got := Candidates(beacon, []Profile{seeker}, now, Options{}); len(got) != 0 {
		t.Fatalf("flirt-only encouragement should be dropped, got %+v", got)
	}
}

func TestLowSeesNoLowOnRadar(t *testing.T) {
	a := prof("a", mood.LevelLow, mood.TrendRising, time.Hour, IntentTea)
	a.Party = Party{WantsEncouragement: true, CanBeBeacon: true}
	b := prof("b", mood.LevelLow, mood.TrendRising, time.Hour, IntentTea)
	b.Party = a.Party
	if got := Candidates(a, []Profile{b}, now, Options{EnableOptional: true}); len(got) != 0 {
		t.Fatalf("LOW×LOW on radar: %+v", got)
	}
}
