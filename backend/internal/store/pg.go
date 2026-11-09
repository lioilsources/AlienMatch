// Package store implements service.Store over Postgres via sqlc.
package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lioilsources/Mimo/backend/internal/db/sqlc"
	"github.com/lioilsources/Mimo/backend/internal/matching"
	"github.com/lioilsources/Mimo/backend/internal/mood"
	"github.com/lioilsources/Mimo/backend/internal/service"
)

// PG is the Postgres store.
type PG struct {
	DB *pgxpool.Pool
	q  *sqlc.Queries
}

// New wraps a pool.
func New(pool *pgxpool.Pool) *PG { return &PG{DB: pool, q: sqlc.New(pool)} }

var _ service.Store = (*PG)(nil)

func uid(s string) (pgtype.UUID, error) {
	var u pgtype.UUID
	if err := u.Scan(s); err != nil {
		return u, fmt.Errorf("user id %q: %w", s, err)
	}
	return u, nil
}

func ts(t time.Time) pgtype.Timestamptz { return pgtype.Timestamptz{Time: t, Valid: true} }

func f4(p *mood.VLScore, get func(mood.VLScore) float64) pgtype.Float4 {
	if p == nil {
		return pgtype.Float4{}
	}
	return pgtype.Float4{Float32: float32(get(*p)), Valid: true}
}

func notFound(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return service.ErrNotFound
	}
	return err
}

func (s *PG) Settings(ctx context.Context, userID string) (service.Settings, error) {
	id, err := uid(userID)
	if err != nil {
		return service.Settings{}, err
	}
	r, err := s.q.UserWeights(ctx, id)
	if err != nil {
		return service.Settings{}, notFound(err)
	}
	return service.Settings{VLEnabled: r.VlEnabled, Weights: mood.Weights{Self: float64(r.WSelf), VL: float64(r.WVl)}}, nil
}

func (s *PG) InsertCheckin(ctx context.Context, c service.CheckinRecord) error {
	id, err := uid(c.UserID)
	if err != nil {
		return err
	}
	_, err = s.q.InsertCheckin(ctx, sqlc.InsertCheckinParams{
		UserID:       id,
		At:           ts(c.At),
		SelfScore:    float32(c.Self),
		VlEnergy:     f4(c.VL, func(v mood.VLScore) float64 { return v.Energy }),
		VlValence:    f4(c.VL, func(v mood.VLScore) float64 { return v.Valence }),
		VlConfidence: f4(c.VL, func(v mood.VLScore) float64 { return v.Confidence }),
		Mood:         float32(c.Fused.Mood),
		Disagreement: c.Fused.Disagreement,
	})
	return err
}

func (s *PG) RecentCheckins(ctx context.Context, userID string, limit int) ([]mood.Point, error) {
	id, err := uid(userID)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.RecentCheckins(ctx, sqlc.RecentCheckinsParams{UserID: id, Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]mood.Point, len(rows))
	for i, r := range rows {
		out[i] = mood.Point{At: r.At.Time, Mood: float64(r.Mood), Valence: float64(r.Valence)}
	}
	return out, nil
}

func (s *PG) SaveState(ctx context.Context, userID string, st mood.State, pause bool) error {
	id, err := uid(userID)
	if err != nil {
		return err
	}
	return s.q.UpsertMoodState(ctx, sqlc.UpsertMoodStateParams{
		UserID:        id,
		Level:         sqlc.MoodLevel(st.Level),
		Trend:         sqlc.MoodTrend(st.Trend),
		Mood:          float32(st.Mood),
		LastCheckinAt: ts(st.LastAt),
		SupportPause:  pause,
		ComputedAt:    ts(st.ComputedAt),
	})
}

func (s *PG) Region(ctx context.Context, userID string) (string, error) {
	id, err := uid(userID)
	if err != nil {
		return "", err
	}
	r, err := s.q.ProfileRegion(ctx, id)
	return r, notFound(err)
}

func (s *PG) Pool(ctx context.Context, region string, freshAfter time.Time) ([]matching.Profile, error) {
	rows, err := s.q.MatchingPool(ctx, sqlc.MatchingPoolParams{Region: region, LastCheckinAt: ts(freshAfter)})
	if err != nil {
		return nil, err
	}
	out := make([]matching.Profile, 0, len(rows))
	for _, r := range rows {
		p := matching.Profile{
			ID:         r.UserID.String(),
			Generation: matching.Generation(r.Generation),
			Status:     matching.Status(r.Status),
			Region:     r.Region,
			State: mood.State{
				Level:  mood.Level(r.Level),
				Trend:  mood.Trend(r.Trend),
				Mood:   float64(r.Mood),
				LastAt: r.LastCheckinAt.Time,
			},
			Party: matching.Party{
				CanBeBeacon:        r.CanBeBeacon,
				WantsEncouragement: r.WantsEncouragement,
				SupportPause:       r.SupportPause,
			},
		}
		for _, g := range r.SeekGenerations {
			p.SeekGens = append(p.SeekGens, matching.Generation(g))
		}
		for _, st := range r.SeekStatuses {
			p.SeekStatus = append(p.SeekStatus, matching.Status(st))
		}
		for _, t := range r.Intents {
			p.Intents = append(p.Intents, matching.Intent(t))
		}
		out = append(out, p)
	}
	return out, nil
}

// CreateMatch inserts a match; the DB trigger rejects forbidden pairs.
func (s *PG) CreateMatch(ctx context.Context, a, b string, kind matching.Result) (int64, error) {
	x, err := uid(a)
	if err != nil {
		return 0, err
	}
	y, err := uid(b)
	if err != nil {
		return 0, err
	}
	k := sqlc.MatchKindMatch
	switch kind {
	case matching.Match:
	case matching.Encourage:
		k = sqlc.MatchKindEncourage
	default:
		return 0, fmt.Errorf("create match: kind %v", kind)
	}
	return s.q.CreateMatch(ctx, sqlc.CreateMatchParams{X: x, Y: y, Kind: k})
}
