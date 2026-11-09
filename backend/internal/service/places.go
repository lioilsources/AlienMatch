package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
)

// freshnessForCounts: a member is "active" for k-anonymity while on the radar.
const freshnessForCounts = mood.Freshness

// PlaceStore is the persistence port for the place layers (Prompts/01-GPS.md).
type PlaceStore interface {
	SearchPlaces(ctx context.Context, region, key string, now time.Time, limit int) ([]CatalogPlace, error)
	// SetProfilePlaces replaces the user's places atomically. It returns
	// ErrUnknownPlace if any id is not in the (non-expired) catalog.
	SetProfilePlaces(ctx context.Context, userID string, ids []string, now time.Time) error
	ProfilePlaces(ctx context.Context, userID string) ([]CatalogPlace, error)
	PlaceCounts(ctx context.Context, ids []string) (map[string]int, error)
	ActiveTEKCount(ctx context.Context, userID string) (int, error)
	ActiveVenueCheckins(ctx context.Context, userID string, now time.Time) ([]string, error)
	RefreshPlaceCounts(ctx context.Context, now, freshAfter time.Time) error
	PurgeExpired(ctx context.Context, now time.Time) (PurgeStats, error)
}

// CatalogPlace is a public catalog entry. Coordinates are catalog data
// (OSM/GTFS) used only to render the picker map; never a user's position.
type CatalogPlace struct {
	ID      string      `json:"place_id"`
	Kind    places.Kind `json:"kind"`
	Name    string      `json:"name"`
	Subtype string      `json:"subtype,omitempty"`
	Lat     *float64    `json:"lat,omitempty"`
	Lon     *float64    `json:"lon,omitempty"`
}

// PurgeStats reports rows removed by TTL enforcement.
type PurgeStats struct {
	TEK, Encounters, VenueCheckins, Events int64
}

// Retention from Prompts/01-GPS.md §0.6.
const (
	EncounterRetentionDays = 14
	SearchLimit            = 20
)

var (
	// ErrUnknownPlace is returned when a chosen place is not in the catalog.
	ErrUnknownPlace = errors.New("service: unknown place")
	// ErrShortQuery is returned for catalog searches under places.MinQueryLen.
	ErrShortQuery = errors.New("service: query too short")
)

// SearchPlaces searches the catalog in the user's own region. It is the only
// free-text input besides the nickname, and it is a lookup, not a message.
func (s *Service) SearchPlaces(ctx context.Context, userID, q string) ([]CatalogPlace, error) {
	key := places.SearchKey(q)
	if len([]rune(key)) < places.MinQueryLen {
		return nil, ErrShortQuery
	}
	if len(key) > 64 {
		key = key[:64]
	}
	region, err := s.Store.Region(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("region: %w", err)
	}
	return s.Store.SearchPlaces(ctx, region, key, s.Now(), SearchLimit)
}

// SetPlaces replaces the user's constellation (max places.MaxPerProfile).
func (s *Service) SetPlaces(ctx context.Context, userID string, ids []string) error {
	norm, err := places.NormalizeSelection(ids)
	if err != nil {
		return err
	}
	return s.Store.SetProfilePlaces(ctx, userID, norm, s.Now())
}

// LocationData is the full answer to "what do you know about my location".
// If something is stored about location and is not in here, that is a bug.
type LocationData struct {
	Places        []CatalogPlace `json:"places"`
	ActiveKeys    int            `json:"active_encounter_keys"`
	VenueCheckins []string       `json:"venue_checkins"`
	Coordinates   []struct{}     `json:"coordinates"` // always empty: we never have any
}

// LocationData collects everything stored server-side about the user's places.
func (s *Service) LocationData(ctx context.Context, userID string) (LocationData, error) {
	ps, err := s.Store.ProfilePlaces(ctx, userID)
	if err != nil {
		return LocationData{}, err
	}
	n, err := s.Store.ActiveTEKCount(ctx, userID)
	if err != nil {
		return LocationData{}, err
	}
	vc, err := s.Store.ActiveVenueCheckins(ctx, userID, s.Now())
	if err != nil {
		return LocationData{}, err
	}
	if ps == nil {
		ps = []CatalogPlace{}
	}
	if vc == nil {
		vc = []string{}
	}
	return LocationData{Places: ps, ActiveKeys: n, VenueCheckins: vc, Coordinates: []struct{}{}}, nil
}

// Housekeeping refreshes k-anonymity counts and enforces TTLs. Runs every
// 10 minutes from the server; TTLs are enforced by this job, not by goodwill.
func (s *Service) Housekeeping(ctx context.Context) (PurgeStats, error) {
	now := s.Now()
	if err := s.Store.RefreshPlaceCounts(ctx, now, now.Add(-freshnessForCounts)); err != nil {
		return PurgeStats{}, fmt.Errorf("refresh place counts: %w", err)
	}
	st, err := s.Store.PurgeExpired(ctx, now)
	if err != nil {
		return st, fmt.Errorf("purge: %w", err)
	}
	return st, nil
}
