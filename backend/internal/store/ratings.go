package store

import (
	"context"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var _ service.RatingStore = (*PG)(nil)

func (s *PG) RateFace(ctx context.Context, rater, target, photoKey string, value int, now time.Time) error {
	r, err := uid(rater)
	if err != nil {
		return err
	}
	t, err := uid(target)
	if err != nil {
		return err
	}
	return s.q.RateFace(ctx, sqlc.RateFaceParams{RaterID: r, TargetID: t, PhotoKey: photoKey, Value: int16(value), Now: ts(now)})
}

func (s *PG) RatingsByRater(ctx context.Context, rater string, keys []string) (map[string]int, error) {
	r, err := uid(rater)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.RatingsByRater(ctx, sqlc.RatingsByRaterParams{RaterID: r, PhotoKeys: keys})
	if err != nil {
		return nil, err
	}
	out := make(map[string]int, len(rows))
	for _, row := range rows {
		out[row.PhotoKey] = int(row.Value)
	}
	return out, nil
}

func (s *PG) FaceStats(ctx context.Context, target string) ([]service.FaceStat, error) {
	t, err := uid(target)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.FaceStats(ctx, t)
	if err != nil {
		return nil, err
	}
	out := make([]service.FaceStat, len(rows))
	for i, r := range rows {
		out[i] = service.FaceStat{PhotoKey: r.PhotoKey, Likes: int(r.Likes), Dislikes: int(r.Dislikes), Seen: int(r.Seen), FirstAt: r.FirstAt.Time}
	}
	return out, nil
}

func (s *PG) LikedTargets(ctx context.Context, rater string) ([]service.LikedRow, error) {
	r, err := uid(rater)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.LikedTargets(ctx, r)
	if err != nil {
		return nil, err
	}
	out := make([]service.LikedRow, len(rows))
	for i, row := range rows {
		out[i] = service.LikedRow{UserID: row.TargetID.String(), At: row.At.Time}
	}
	return out, nil
}

func (s *PG) OwnLevel(ctx context.Context, user string) (mood.Level, error) {
	u, err := uid(user)
	if err != nil {
		return "", err
	}
	l, err := s.q.OwnLevel(ctx, u)
	return mood.Level(l), notFound(err)
}
