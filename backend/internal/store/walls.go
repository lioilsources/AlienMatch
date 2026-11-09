package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var _ service.WallStore = (*PG)(nil)

const presetPrefix = "preset:"

func uids(a, b string) (pgtype.UUID, pgtype.UUID, error) {
	x, err := uid(a)
	if err != nil {
		return x, x, err
	}
	y, err := uid(b)
	return x, y, err
}

func (s *PG) CountWavesSince(ctx context.Context, from string, since time.Time) (int, error) {
	id, err := uid(from)
	if err != nil {
		return 0, err
	}
	n, err := s.q.CountWavesSince(ctx, sqlc.CountWavesSinceParams{FromUser: id, CreatedAt: ts(since)})
	return int(n), err
}

func (s *PG) AddWave(ctx context.Context, from, to string, now time.Time) error {
	x, y, err := uids(from, to)
	if err != nil {
		return err
	}
	return s.q.AddWave(ctx, sqlc.AddWaveParams{FromUser: x, ToUser: y, CreatedAt: ts(now)})
}

func (s *PG) HasWave(ctx context.Context, from, to string) (bool, error) {
	x, y, err := uids(from, to)
	if err != nil {
		return false, err
	}
	return s.q.HasWave(ctx, sqlc.HasWaveParams{FromUser: x, ToUser: y})
}

func (s *PG) CreateMatchWithWall(ctx context.Context, a, b string, kind matching.Result) (int64, int64, error) {
	var mid, wid int64
	err := pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		x, y, err := uids(a, b)
		if err != nil {
			return err
		}
		if row, err := q.ActiveMatchBetween(ctx, sqlc.ActiveMatchBetweenParams{X: x, Y: y}); err == nil {
			mid, wid = row.ID, row.WallID
			return nil
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		k := sqlc.MatchKindMatch
		if kind == matching.Encourage {
			k = sqlc.MatchKindEncourage
		}
		// matches_guard trigger rejects LOW x LOW and other forbidden pairs.
		if mid, err = q.CreateMatch(ctx, sqlc.CreateMatchParams{X: x, Y: y, Kind: k}); err != nil {
			return err
		}
		wid, err = q.CreateWall(ctx, sqlc.CreateWallParams{MatchID: mid, Gentle: kind == matching.Encourage})
		return err
	})
	return mid, wid, err
}

func (s *PG) ActiveMatchBetween(ctx context.Context, a, b string) (int64, int64, error) {
	x, y, err := uids(a, b)
	if err != nil {
		return 0, 0, err
	}
	r, err := s.q.ActiveMatchBetween(ctx, sqlc.ActiveMatchBetweenParams{X: x, Y: y})
	if err != nil {
		return 0, 0, notFound(err)
	}
	return r.ID, r.WallID, nil
}

func (s *PG) ListMatches(ctx context.Context, me string) ([]service.MatchView, error) {
	id, err := uid(me)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.ListMatches(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make([]service.MatchView, len(rows))
	for i, r := range rows {
		out[i] = service.MatchView{MatchID: r.MatchID, WallID: r.WallID, Kind: r.Kind, OtherID: r.OtherID.String(),
			OtherNickname: r.OtherNickname, SharedPlaces: nonNil(r.SharedPlaces), CreatedAt: r.CreatedAt.Time}
	}
	return out, nil
}

func (s *PG) WallMember(ctx context.Context, wallID int64, me string) (service.Wall, error) {
	id, err := uid(me)
	if err != nil {
		return service.Wall{}, err
	}
	r, err := s.q.WallMember(ctx, sqlc.WallMemberParams{Me: id, WallID: wallID})
	if errors.Is(err, pgx.ErrNoRows) {
		return service.Wall{}, service.ErrNotMember
	}
	if err != nil {
		return service.Wall{}, err
	}
	return service.Wall{ID: r.ID, Gentle: r.Gentle, OtherID: r.OtherID.String()}, nil
}

func toSticker(id, wall int64, author, client pgtype.UUID, kind, media string, ink []byte, x, y, rot, scale float32, z int32, at pgtype.Timestamptz) service.Sticker {
	st := service.Sticker{ID: id, WallID: wall, AuthorID: author.String(), ClientID: client.String(), Kind: kind,
		X: float64(x), Y: float64(y), Rotation: float64(rot), Scale: float64(scale), Z: int(z), Created: at.Time}
	if kind == "ink" {
		st.Ink = ink
	} else {
		st.Preset = strings.TrimPrefix(media, presetPrefix)
	}
	return st
}

func (s *PG) ListStickers(ctx context.Context, wallID, afterID int64) ([]service.Sticker, error) {
	rows, err := s.q.ListStickers(ctx, sqlc.ListStickersParams{WallID: wallID, ID: afterID})
	if err != nil {
		return nil, err
	}
	out := make([]service.Sticker, len(rows))
	for i, r := range rows {
		out[i] = toSticker(r.ID, wallID, r.AuthorID, r.ClientID, r.Kind, r.MediaKey, r.Ink, r.X, r.Y, r.Rotation, r.Scale, r.Z, r.CreatedAt)
	}
	return out, nil
}

func (s *PG) InsertSticker(ctx context.Context, st service.Sticker, now time.Time) (service.Sticker, error) {
	author, err := uid(st.AuthorID)
	if err != nil {
		return st, err
	}
	var client pgtype.UUID
	if err := client.Scan(st.ClientID); err != nil {
		return st, fmt.Errorf("client id: %w", err)
	}
	z, err := s.q.NextZ(ctx, st.WallID)
	if err != nil {
		return st, err
	}
	p := sqlc.InsertStickerParams{WallID: st.WallID, AuthorID: author, ClientID: client, Kind: st.Kind,
		X: float32(st.X), Y: float32(st.Y), Rotation: float32(st.Rotation), Scale: float32(st.Scale), Z: z, Now: ts(now)}
	if st.Kind == "ink" {
		p.Ink = st.Ink
	} else {
		p.MediaKey = pgtype.Text{String: presetPrefix + st.Preset, Valid: true}
	}
	r, err := s.q.InsertSticker(ctx, p)
	if err != nil {
		return st, err
	}
	return toSticker(r.ID, r.WallID, r.AuthorID, r.ClientID, r.Kind, r.MediaKey, r.Ink, r.X, r.Y, r.Rotation, r.Scale, r.Z, r.CreatedAt), nil
}

func (s *PG) MoveSticker(ctx context.Context, st service.Sticker) error {
	author, err := uid(st.AuthorID)
	if err != nil {
		return err
	}
	_, err = s.q.MoveSticker(ctx, sqlc.MoveStickerParams{X: float32(st.X), Y: float32(st.Y), Rotation: float32(st.Rotation),
		Scale: float32(st.Scale), Z: int32(st.Z), ID: st.ID, WallID: st.WallID, AuthorID: author})
	if errors.Is(err, pgx.ErrNoRows) {
		return service.ErrNotYours
	}
	return err
}

func (s *PG) PeelSticker(ctx context.Context, wallID, id int64, author string, now time.Time) error {
	a, err := uid(author)
	if err != nil {
		return err
	}
	_, err = s.q.PeelSticker(ctx, sqlc.PeelStickerParams{Now: ts(now), ID: id, WallID: wallID, AuthorID: a})
	if errors.Is(err, pgx.ErrNoRows) {
		return service.ErrNotYours
	}
	return err
}

func (s *PG) HideSticker(ctx context.Context, id int64, me string) (int64, error) {
	m, err := uid(me)
	if err != nil {
		return 0, err
	}
	w, err := s.q.HideSticker(ctx, sqlc.HideStickerParams{ID: id, Me: m})
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, service.ErrNotMember
	}
	return w, err
}

func (s *PG) Report(ctx context.Context, reporter string, target *string, sticker *int64, block bool, now time.Time) error {
	r, err := uid(reporter)
	if err != nil {
		return err
	}
	p := sqlc.InsertReportParams{ReporterID: r, Block: block, Now: ts(now)}
	if target != nil {
		if p.TargetUser, err = uid(*target); err != nil {
			return err
		}
	}
	if sticker != nil {
		p.StickerID = pgtype.Int8{Int64: *sticker, Valid: true}
	}
	return s.q.InsertReport(ctx, p)
}

func (s *PG) Block(ctx context.Context, me, other string, now time.Time) error {
	x, y, err := uids(me, other)
	if err != nil {
		return err
	}
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		if err := q.AddBlock(ctx, sqlc.AddBlockParams{Blocker: x, Blocked: y, CreatedAt: ts(now)}); err != nil {
			return err
		}
		_, err := q.EndMatchBetween(ctx, sqlc.EndMatchBetweenParams{Now: ts(now), X: x, Y: y})
		return err
	})
}

func (s *PG) RadarExclusions(ctx context.Context, me string) ([]string, error) {
	id, err := uid(me)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.RadarExclusions(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make([]string, len(rows))
	for i, r := range rows {
		out[i] = r.String()
	}
	return out, nil
}

func (s *PG) HasEntitlement(ctx context.Context, user, product string, now time.Time) (bool, error) {
	id, err := uid(user)
	if err != nil {
		return false, err
	}
	return s.q.HasEntitlement(ctx, sqlc.HasEntitlementParams{UserID: id, Product: product, ExpiresAt: ts(now)})
}
