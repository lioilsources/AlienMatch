package store

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/lioilsources/AlienMatch/backend/internal/db/sqlc"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

var _ service.AdminStore = (*PG)(nil)

func (s *PG) OpenReports(ctx context.Context, limit int) ([]service.ReportView, error) {
	rows, err := s.q.OpenReports(ctx, int32(limit))
	if err != nil {
		return nil, err
	}
	out := make([]service.ReportView, len(rows))
	for i, r := range rows {
		v := service.ReportView{ID: r.ID, CreatedAt: r.CreatedAt.Time, Block: r.Block, ReporterID: r.ReporterID.String()}
		if r.TargetUser.Valid {
			v.TargetUser = r.TargetUser.String()
		}
		if r.StickerID.Valid {
			st := &service.ReportedSticker{ID: r.StickerID.Int64, AuthorID: r.StickerAuthor.String(), Kind: r.StickerKind, Moderation: r.StickerModeration}
			if r.StickerKind == "ink" {
				st.Ink = r.StickerInk
			} else {
				st.Preset = strings.TrimPrefix(r.StickerMedia, presetPrefix)
			}
			v.Sticker = st
		}
		out[i] = v
	}
	return out, nil
}

func (s *PG) ResolveReport(ctx context.Context, id int64, action string, now time.Time) error {
	return pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		sid, err := q.ReportSticker(ctx, id)
		if errors.Is(err, pgx.ErrNoRows) {
			return service.ErrNotFound
		}
		if err != nil {
			return err
		}
		if sid.Valid {
			switch action {
			case service.ActionRestore:
				err = q.SetModeration(ctx, sqlc.SetModerationParams{Moderation: "ok", ID: sid.Int64})
			case service.ActionRemove:
				err = q.RemoveSticker(ctx, sqlc.RemoveStickerParams{Now: ts(now), ID: sid.Int64})
			}
			if err != nil {
				return err
			}
		}
		return q.ResolveReport(ctx, sqlc.ResolveReportParams{Now: ts(now), ID: id})
	})
}
