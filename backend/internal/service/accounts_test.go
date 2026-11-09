package service_test

import (
	"errors"
	"testing"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	. "github.com/lioilsources/AlienMatch/backend/internal/service"
)

func validProfile() ProfileInput {
	return ProfileInput{
		Generation: matching.GenZ, Status: matching.StatusSingle, Region: "CZ-PHA",
		Intents: []matching.Intent{matching.IntentCafe, matching.IntentCafe},
	}
}

func TestProfileValidation(t *testing.T) {
	p := validProfile()
	if err := p.Validate(); err != nil || len(p.Intents) != 1 {
		t.Fatalf("valid: err=%v intents=%v", err, p.Intents)
	}
	bad := map[string]func(*ProfileInput){
		"generation":  func(p *ProfileInput) { p.Generation = "1990" },
		"status":      func(p *ProfileInput) { p.Status = "open" },
		"region":      func(p *ProfileInput) { p.Region = "50.08,14.42" },
		"no intents":  func(p *ProfileInput) { p.Intents = nil },
		"intent":      func(p *ProfileInput) { p.Intents = []matching.Intent{"hello there"} },
		"kids":        func(p *ProfileInput) { n := 6; p.KidsCount = &n },
		"kids flag":   func(p *ProfileInput) { p.KidsFlags = []string{"quads"} },
		"long nick":   func(p *ProfileInput) { p.Nickname = "Zq7Zq7Zq7Zq7Z" },
		"nick spaces": func(p *ProfileInput) { p.Nickname = "ahoj jak je" },
		"nick dash":   func(p *ProfileInput) { p.Nickname = "-Zq" },
	}
	for name, mut := range bad {
		p := validProfile()
		mut(&p)
		if err := p.Validate(); !errors.Is(err, ErrInvalid) {
			t.Errorf("%s: err=%v", name, err)
		}
	}
	for _, ok := range []string{"Zq-7", "Ůfoňák", "a.b", "123456789012"} {
		p := validProfile()
		p.Nickname = ok
		if err := p.Validate(); err != nil {
			t.Errorf("nickname %q rejected: %v", ok, err)
		}
	}
	p = validProfile()
	p.BeaconOnly = true
	_ = p.Validate()
	if !p.CanBeBeacon {
		t.Error("beacon-only must imply can_be_beacon")
	}
}
