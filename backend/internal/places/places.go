// Package places implements the "constellation" layer from Prompts/01-GPS.md:
// users pick places from a public catalog; shared places boost radar ranking
// and are shown only under k-anonymity. No user coordinates exist anywhere.
package places

import (
	"errors"
	"fmt"
	"slices"
	"sort"
	"strings"
	"unicode"

	"golang.org/x/text/runes"
	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

// Kind is the catalog place type; it is also the place_id prefix.
type Kind string

const (
	KindStop    Kind = "stop"
	KindRoute   Kind = "route"
	KindPOI     Kind = "poi"
	KindEdu     Kind = "edu"
	KindOffice  Kind = "office"
	KindPartner Kind = "partner"
	KindEvent   Kind = "event"
)

var kinds = []Kind{KindStop, KindRoute, KindPOI, KindEdu, KindOffice, KindPartner, KindEvent}

const (
	// MaxPerProfile limits how many places a user can share (correlation risk).
	MaxPerProfile = 8
	// KMin is the k-anonymity threshold for showing a shared place.
	KMin = 5
	// MinQueryLen is the shortest catalog search.
	MinQueryLen = 2
)

// Bonus is the ranking bonus per shared place. Routes are big sets, so low.
func Bonus(k Kind) int {
	switch k {
	case KindStop:
		return 3
	case KindRoute:
		return 1
	case KindPOI, KindEdu, KindOffice, KindPartner, KindEvent:
		return 2
	default:
		return 0
	}
}

// ErrBadID is returned for malformed place ids.
var ErrBadID = errors.New("places: bad place id")

// KindOf returns the kind encoded in a place id ("stop:pid:U1040Z1" → stop).
func KindOf(id string) (Kind, error) {
	k, rest, ok := strings.Cut(id, ":")
	if !ok || rest == "" || len(id) > 128 || !slices.Contains(kinds, Kind(k)) {
		return "", fmt.Errorf("%q: %w", id, ErrBadID)
	}
	return Kind(k), nil
}

// ErrTooMany is returned when a profile would exceed MaxPerProfile.
var ErrTooMany = fmt.Errorf("places: at most %d places", MaxPerProfile)

// NormalizeSelection validates and de-duplicates a user's chosen place ids.
func NormalizeSelection(ids []string) ([]string, error) {
	var out []string
	for _, id := range ids {
		if _, err := KindOf(id); err != nil {
			return nil, err
		}
		if !slices.Contains(out, id) {
			out = append(out, id)
		}
	}
	if len(out) > MaxPerProfile {
		return nil, ErrTooMany
	}
	return out, nil
}

// SearchKey lower-cases and strips diacritics ("Anděl" → "andel").
func SearchKey(s string) string {
	t := transform.Chain(norm.NFD, runes.Remove(runes.In(unicode.Mn)), norm.NFC)
	r, _, err := transform.String(t, s)
	if err != nil {
		r = s
	}
	return strings.Join(strings.Fields(strings.ToLower(r)), " ")
}

// Constellation is what a radar planet may reveal about shared places.
type Constellation struct {
	// Star is one of MY places that the other user shares and that has at
	// least KMin active members. Empty if none qualifies.
	Star string
	// WeakSignal: we share something, but no shared place passes k-anonymity.
	WeakSignal bool
	// Score is the ranking bonus. Internal only, never sent to clients.
	Score int
}

// Shared computes the constellation between my places and theirs.
// counts maps place_id → active member count.
func Shared(mine, theirs []string, counts map[string]int) Constellation {
	var c Constellation
	bestBonus := -1
	for _, id := range mine {
		if !slices.Contains(theirs, id) {
			continue
		}
		k, err := KindOf(id)
		if err != nil {
			continue
		}
		b := Bonus(k)
		c.Score += b
		if counts[id] < KMin {
			continue
		}
		// Reveal at most one place: the strongest, ties by id for determinism.
		if b > bestBonus || (b == bestBonus && id < c.Star) {
			c.Star, bestBonus = id, b
		}
	}
	c.WeakSignal = c.Score > 0 && c.Star == ""
	return c
}

// Ranked pairs an item with its constellation, for sorting.
type Ranked[T any] struct {
	Item          T
	Constellation Constellation
}

// Rank sorts items by constellation score (desc), stable otherwise.
func Rank[T any](mine []string, items []T, placesOf func(T) []string, counts map[string]int) []Ranked[T] {
	out := make([]Ranked[T], len(items))
	for i, it := range items {
		out[i] = Ranked[T]{Item: it, Constellation: Shared(mine, placesOf(it), counts)}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Constellation.Score > out[j].Constellation.Score })
	return out
}
