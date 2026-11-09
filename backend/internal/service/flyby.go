package service

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"
)

// FlybyStore persists layer B (Prompts/01-GPS.md): yesterday's temporary
// exposure keys and day-only encounters. Never a time of contact, never a place.
type FlybyStore interface {
	SetFlyby(ctx context.Context, user string, enabled bool) error
	FlybyEnabled(ctx context.Context, user string) (bool, error)
	InsertTEK(ctx context.Context, user string, day time.Time, tek []byte, region string) (bool, error)
	RegionTEKs(ctx context.Context, region string, since time.Time, me string) ([]DayKey, error)
	OwnerOfTEK(ctx context.Context, tek []byte, day time.Time) (string, error)
	HasTEKSince(ctx context.Context, user string, since time.Time) (bool, error)
	WaveEncounter(ctx context.Context, me, other, kind string, day time.Time) error
	Comets(ctx context.Context, me string) (map[string]string, error)
}

// DayKey is one downloadable key. It carries no user identity.
type DayKey struct {
	Day string `json:"day"` // YYYY-MM-DD
	TEK []byte `json:"tek"` // 16 bytes, base64 in JSON
}

// EncounterKinds are classified on the phone; the server only stores the label.
var EncounterKinds = []string{"vehicle", "stop", "venue"}

const TEKLen = 16

var (
	ErrFlybyOff     = errors.New("service: fly-by is off")
	ErrBadTEK       = errors.New("service: bad key")
	ErrNotYesterday = errors.New("service: only yesterday's key is accepted")
)

// utcDay truncates to the UTC calendar day.
func utcDay(t time.Time) time.Time {
	y, m, d := t.UTC().Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// SetFlyby turns layer B on or off. Off deletes the user's keys and encounters.
func (s *Service) SetFlyby(ctx context.Context, me string, on bool) error {
	return s.Flyby.SetFlyby(ctx, me, on)
}

func (s *Service) requireFlyby(ctx context.Context, me string) error {
	on, err := s.Flyby.FlybyEnabled(ctx, me)
	if err != nil {
		return err
	}
	if !on {
		return ErrFlybyOff
	}
	return nil
}

// UploadTEK accepts yesterday's key only (never today's, so nobody can be
// followed live), one per user and day.
func (s *Service) UploadTEK(ctx context.Context, me, day string, tek []byte) error {
	if err := s.requireFlyby(ctx, me); err != nil {
		return err
	}
	if len(tek) != TEKLen {
		return ErrBadTEK
	}
	d, err := time.Parse(time.DateOnly, day)
	if err != nil {
		return ErrBadTEK
	}
	if !d.Equal(utcDay(s.Now()).AddDate(0, 0, -1)) {
		return ErrNotYesterday
	}
	region, err := s.Store.Region(ctx, me)
	if err != nil {
		return fmt.Errorf("region: %w", err)
	}
	ok, err := s.Flyby.InsertTEK(ctx, me, d, tek, region)
	if err != nil {
		return err
	}
	if !ok {
		return ErrBadTEK // duplicate day or a key collision
	}
	return nil
}

// DownloadTEKs returns other users' keys from the caller's hand-picked region
// for the retention window. Matching happens on the phone.
func (s *Service) DownloadTEKs(ctx context.Context, me string) ([]DayKey, error) {
	if err := s.requireFlyby(ctx, me); err != nil {
		return nil, err
	}
	region, err := s.Store.Region(ctx, me)
	if err != nil {
		return nil, fmt.Errorf("region: %w", err)
	}
	return s.Flyby.RegionTEKs(ctx, region, utcDay(s.Now()).AddDate(0, 0, -EncounterRetentionDays), me)
}

// WaveFlyby records "I want to meet the holder of key K I was near on day D".
// The caller learns nothing about who that is; the other side sees a comet
// only after they uploaded their own key and waved back, and only if the mood
// matrix lets them see each other (see Radar).
func (s *Service) WaveFlyby(ctx context.Context, me string, tek []byte, day, kind string) error {
	if err := s.requireFlyby(ctx, me); err != nil {
		return err
	}
	if len(tek) != TEKLen || !slices.Contains(EncounterKinds, kind) {
		return ErrBadTEK
	}
	d, err := time.Parse(time.DateOnly, day)
	today := utcDay(s.Now())
	if err != nil || d.After(today) || d.Before(today.AddDate(0, 0, -EncounterRetentionDays)) {
		return ErrBadTEK
	}
	other, err := s.Flyby.OwnerOfTEK(ctx, tek, d)
	if errors.Is(err, ErrNotFound) {
		return nil // unknown or withdrawn key: answer the same, reveal nothing
	}
	if err != nil {
		return err
	}
	if other == me {
		return nil
	}
	if s.Walls != nil {
		ex, err := s.Walls.RadarExclusions(ctx, me)
		if err != nil {
			return err
		}
		if slices.Contains(ex, other) {
			return nil // blocked or already matched: silently ignore
		}
	}
	return s.Flyby.WaveEncounter(ctx, me, other, kind, d)
}

// comets returns contact kinds for radar planets, only if the caller has
// uploaded a key in the retention window themselves.
func (s *Service) comets(ctx context.Context, me string) (map[string]string, error) {
	if s.Flyby == nil {
		return nil, nil
	}
	on, err := s.Flyby.FlybyEnabled(ctx, me)
	if err != nil || !on {
		return nil, err
	}
	has, err := s.Flyby.HasTEKSince(ctx, me, utcDay(s.Now()).AddDate(0, 0, -EncounterRetentionDays))
	if err != nil || !has {
		return nil, err
	}
	return s.Flyby.Comets(ctx, me)
}
