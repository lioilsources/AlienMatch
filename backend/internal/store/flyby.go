package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var _ service.FlybyStore = (*PG)(nil)

func dateOf(t time.Time) pgtype.Date { return pgtype.Date{Time: t, Valid: true} }

func (s *PG) SetFlyby(ctx context.Context, user string, enabled bool) error {
	id, err := uid(user)
	if err != nil {
		return err
	}
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		if err := q.SetFlyby(ctx, sqlc.SetFlybyParams{Enabled: enabled, ID: id}); err != nil {
			return err
		}
		if !enabled {
			return q.WipeFlyby(ctx, id)
		}
		return nil
	})
}

func (s *PG) FlybyEnabled(ctx context.Context, user string) (bool, error) {
	id, err := uid(user)
	if err != nil {
		return false, err
	}
	on, err := s.q.FlybyEnabled(ctx, id)
	return on, notFound(err)
}

func (s *PG) InsertTEK(ctx context.Context, user string, day time.Time, tek []byte, region string) (bool, error) {
	id, err := uid(user)
	if err != nil {
		return false, err
	}
	n, err := s.q.InsertTEK(ctx, sqlc.InsertTEKParams{UserID: id, Day: dateOf(day), Tek: tek, Region: region})
	return n == 1, err
}

func (s *PG) RegionTEKs(ctx context.Context, region string, since time.Time, me string) ([]service.DayKey, error) {
	id, err := uid(me)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.RegionTEKs(ctx, sqlc.RegionTEKsParams{Region: region, Since: dateOf(since), Me: id})
	if err != nil {
		return nil, err
	}
	out := make([]service.DayKey, len(rows))
	for i, r := range rows {
		out[i] = service.DayKey{Day: r.Day.Time.Format(time.DateOnly), TEK: r.Tek}
	}
	return out, nil
}

func (s *PG) OwnerOfTEK(ctx context.Context, tek []byte, day time.Time) (string, error) {
	u, err := s.q.OwnerOfTEK(ctx, sqlc.OwnerOfTEKParams{Tek: tek, Day: dateOf(day)})
	if errors.Is(err, pgx.ErrNoRows) {
		return "", service.ErrNotFound
	}
	if err != nil {
		return "", err
	}
	return u.String(), nil
}

func (s *PG) HasTEKSince(ctx context.Context, user string, since time.Time) (bool, error) {
	id, err := uid(user)
	if err != nil {
		return false, err
	}
	return s.q.HasTEKSince(ctx, sqlc.HasTEKSinceParams{UserID: id, Column2: dateOf(since)})
}

func (s *PG) WaveEncounter(ctx context.Context, me, other, kind string, day time.Time) error {
	x, y, err := uids(me, other)
	if err != nil {
		return err
	}
	return s.q.WaveEncounter(ctx, sqlc.WaveEncounterParams{Me: x, Other: y, Kind: sqlc.EncounterKind(kind), Day: dateOf(day)})
}

func (s *PG) Comets(ctx context.Context, me string) (map[string]string, error) {
	id, err := uid(me)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.Comets(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, r := range rows {
		out[r.Other.String()] = r.Kind
	}
	return out, nil
}
