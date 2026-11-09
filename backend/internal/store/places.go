package store

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/lioilsources/AlienMatch/backend/internal/catalog"
	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func f8(p *float64) pgtype.Float8 {
	if p == nil {
		return pgtype.Float8{}
	}
	return pgtype.Float8{Float64: *p, Valid: true}
}

func fromF8(v pgtype.Float8) *float64 {
	if !v.Valid {
		return nil
	}
	return &v.Float64
}

func day(t time.Time) pgtype.Date {
	y, m, d := t.UTC().Date()
	return pgtype.Date{Time: time.Date(y, m, d, 0, 0, 0, 0, time.UTC), Valid: true}
}

func (s *PG) SearchPlaces(ctx context.Context, region, key string, now time.Time, limit int) ([]service.CatalogPlace, error) {
	rows, err := s.q.SearchPlaces(ctx, sqlc.SearchPlacesParams{Region: region, Q: key, Now: ts(now), Lim: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]service.CatalogPlace, len(rows))
	for i, r := range rows {
		out[i] = service.CatalogPlace{ID: r.PlaceID, Kind: places.Kind(r.Kind), Name: r.Name, Subtype: r.Subtype, Lat: fromF8(r.Lat), Lon: fromF8(r.Lon)}
	}
	return out, nil
}

func (s *PG) SetProfilePlaces(ctx context.Context, userID string, ids []string, now time.Time) error {
	id, err := uid(userID)
	if err != nil {
		return err
	}
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		if len(ids) > 0 {
			ok, err := q.ExistingPlaces(ctx, sqlc.ExistingPlacesParams{Ids: ids, Now: ts(now)})
			if err != nil {
				return err
			}
			if len(ok) != len(ids) {
				return service.ErrUnknownPlace
			}
		}
		if err := q.ClearProfilePlaces(ctx, id); err != nil {
			return err
		}
		for _, p := range ids {
			if err := q.AddProfilePlace(ctx, sqlc.AddProfilePlaceParams{UserID: id, PlaceID: p, AddedAt: ts(now)}); err != nil {
				return fmt.Errorf("add %s: %w", p, err)
			}
		}
		return nil
	})
}

func (s *PG) ProfilePlaces(ctx context.Context, userID string) ([]service.CatalogPlace, error) {
	id, err := uid(userID)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.ProfilePlaces(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make([]service.CatalogPlace, len(rows))
	for i, r := range rows {
		out[i] = service.CatalogPlace{ID: r.PlaceID, Kind: places.Kind(r.Kind), Name: r.Name, Subtype: r.Subtype}
	}
	return out, nil
}

func (s *PG) PlaceCounts(ctx context.Context, ids []string) (map[string]int, error) {
	out := map[string]int{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := s.q.PlaceCounts(ctx, ids)
	if err != nil {
		return nil, err
	}
	for _, r := range rows {
		out[r.PlaceID] = int(r.ActiveCount)
	}
	return out, nil
}

func (s *PG) ActiveTEKCount(ctx context.Context, userID string) (int, error) {
	id, err := uid(userID)
	if err != nil {
		return 0, err
	}
	n, err := s.q.ActiveTEKCount(ctx, id)
	return int(n), err
}

func (s *PG) ActiveVenueCheckins(ctx context.Context, userID string, now time.Time) ([]string, error) {
	id, err := uid(userID)
	if err != nil {
		return nil, err
	}
	return s.q.ActiveVenueCheckins(ctx, sqlc.ActiveVenueCheckinsParams{UserID: id, Now: ts(now)})
}

func (s *PG) RefreshPlaceCounts(ctx context.Context, now, freshAfter time.Time) error {
	return s.q.RefreshPlaceCounts(ctx, sqlc.RefreshPlaceCountsParams{Now: ts(now), FreshAfter: ts(freshAfter)})
}

func (s *PG) PurgeExpired(ctx context.Context, now time.Time) (service.PurgeStats, error) {
	var st service.PurgeStats
	cutoff := day(now.AddDate(0, 0, -service.EncounterRetentionDays))
	err := pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		var err error
		if st.TEK, err = q.PurgeExpiredTEK(ctx, cutoff); err != nil {
			return err
		}
		if st.Encounters, err = q.PurgeExpiredEncounters(ctx, cutoff); err != nil {
			return err
		}
		if st.VenueCheckins, err = q.PurgeExpiredVenueCheckins(ctx, ts(now)); err != nil {
			return err
		}
		st.Events, err = q.PurgeExpiredEvents(ctx, ts(now))
		return err
	})
	return st, err
}

// UpsertCatalog writes catalog places in one transaction (import command).
func (s *PG) UpsertCatalog(ctx context.Context, ps []catalog.Place) error {
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		for _, p := range ps {
			err := q.UpsertPlace(ctx, sqlc.UpsertPlaceParams{
				PlaceID: p.ID, Kind: sqlc.PlaceKind(p.Kind), Name: p.Name, NameSearch: places.SearchKey(p.Name),
				Subtype: p.Subtype, Lat: f8(p.Lat), Lon: f8(p.Lon), Region: p.Region, Source: p.Source,
			})
			if err != nil {
				return fmt.Errorf("upsert %s: %w", p.ID, err)
			}
		}
		return nil
	})
}
