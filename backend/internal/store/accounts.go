package store

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var _ service.AccountStore = (*PG)(nil)

func (s *PG) CreateAccount(ctx context.Context, hash []byte, now time.Time, moodConsent bool) (string, error) {
	p := sqlc.CreateAccountParams{AdultConfirmedAt: ts(now), VlEnabled: moodConsent, TokenHash: hash}
	if moodConsent {
		p.SpecialConsentAt = ts(now)
	}
	id, err := s.q.CreateAccount(ctx, p)
	return id.String(), err
}

func (s *PG) UserByTokenHash(ctx context.Context, hash []byte) (string, error) {
	id, err := s.q.UserByTokenHash(ctx, hash)
	if err != nil {
		return "", notFound(err)
	}
	return id.String(), nil
}

func strs[T ~string](xs []string) []T {
	out := make([]T, len(xs))
	for i, x := range xs {
		out[i] = T(x)
	}
	return out
}

func unstrs[T ~string](xs []T) []string {
	out := make([]string, len(xs))
	for i, x := range xs {
		out[i] = string(x)
	}
	return out
}

func (s *PG) Me(ctx context.Context, userID string) (service.Me, error) {
	id, err := uid(userID)
	if err != nil {
		return service.Me{}, err
	}
	r, err := s.q.Me(ctx, id)
	if err != nil {
		return service.Me{}, notFound(err)
	}
	me := service.Me{UserID: r.UserID.String(), MoodConsent: r.MoodConsent, VLEnabled: r.VlEnabled, HasProfile: r.HasProfile, HasPhoto: r.HasPhoto}
	if r.HasProfile {
		p := &service.ProfileInput{
			Nickname: r.Nickname, Generation: matching.Generation(r.Generation), Status: matching.Status(r.Status),
			KidsFlags: r.KidsFlags, Region: r.Region,
			SeekGenerations: strs[matching.Generation](r.SeekGenerations), SeekStatuses: strs[matching.Status](r.SeekStatuses),
			Intents: strs[matching.Intent](r.Intents), CanBeBeacon: r.CanBeBeacon, WantsEncouragement: r.WantsEncouragement, BeaconOnly: r.BeaconOnly,
		}
		if r.KidsCount.Valid {
			n := int(r.KidsCount.Int16)
			p.KidsCount = &n
		}
		me.Profile = p
	}
	return me, nil
}

func (s *PG) SaveProfile(ctx context.Context, userID string, p service.ProfileInput, now time.Time) error {
	id, err := uid(userID)
	if err != nil {
		return err
	}
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		arg := sqlc.UpsertProfileParams{
			UserID: id, Nickname: pgtype.Text{String: p.Nickname, Valid: p.Nickname != ""},
			Generation: sqlc.Generation(p.Generation), Status: sqlc.RelStatus(p.Status),
			KidsFlags: nonNil(p.KidsFlags), Region: p.Region,
			SeekGenerations: unstrs(p.SeekGenerations), SeekStatuses: unstrs(p.SeekStatuses),
			CanBeBeacon: p.CanBeBeacon, WantsEncouragement: p.WantsEncouragement, BeaconOnly: p.BeaconOnly, Now: ts(now),
		}
		if p.KidsCount != nil {
			arg.KidsCount = pgtype.Int2{Int16: int16(*p.KidsCount), Valid: true}
		}
		if err := q.UpsertProfile(ctx, arg); err != nil {
			return err
		}
		if err := q.ClearTags(ctx, id); err != nil {
			return err
		}
		for _, t := range p.Intents {
			if err := q.AddTag(ctx, sqlc.AddTagParams{UserID: id, Tag: string(t)}); err != nil {
				return err
			}
		}
		return nil
	})
}

func nonNil(xs []string) []string {
	if xs == nil {
		return []string{}
	}
	return xs
}

func (s *PG) SwapPhoto(ctx context.Context, userID, key string, now time.Time) (string, error) {
	id, err := uid(userID)
	if err != nil {
		return "", err
	}
	prev, err := s.q.SwapPhoto(ctx, sqlc.SwapPhotoParams{UserID: id, PhotoKey: pgtype.Text{String: key, Valid: true}, Now: ts(now)})
	return prev, notFound(err)
}

func (s *PG) PhotoKey(ctx context.Context, userID string) (string, error) {
	id, err := uid(userID)
	if err != nil {
		return "", err
	}
	k, err := s.q.PhotoKey(ctx, id)
	return k, notFound(err)
}

func (s *PG) DeleteAccount(ctx context.Context, userID string) (string, error) {
	id, err := uid(userID)
	if err != nil {
		return "", err
	}
	k, err := s.q.DeleteAccount(ctx, id)
	return k, notFound(err)
}
