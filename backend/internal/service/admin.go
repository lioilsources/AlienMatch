package service

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

// AdminStore backs the internal moderation queue.
type AdminStore interface {
	OpenReports(ctx context.Context, limit int) ([]ReportView, error)
	// ResolveReport applies the action to the reported sticker (if any) and
	// closes the report, atomically.
	ResolveReport(ctx context.Context, id int64, action string, now time.Time) error
}

// ReportView is one open report for a moderator. User ids are pseudonymous.
type ReportView struct {
	ID         int64            `json:"id"`
	CreatedAt  time.Time        `json:"created_at"`
	Block      bool             `json:"block"`
	ReporterID string           `json:"reporter_id"`
	TargetUser string           `json:"target_user,omitempty"`
	Sticker    *ReportedSticker `json:"sticker,omitempty"`
}

// ReportedSticker is what the moderator needs to judge: the drawing itself.
type ReportedSticker struct {
	ID         int64           `json:"id"`
	AuthorID   string          `json:"author_id"`
	Kind       string          `json:"kind"`
	Preset     string          `json:"preset,omitempty"`
	Ink        json.RawMessage `json:"ink,omitempty"`
	Moderation string          `json:"moderation"`
}

// Moderator actions.
const (
	ActionRestore = "restore" // false alarm: show the sticker again
	ActionRemove  = "remove"  // remove for good
	ActionDismiss = "dismiss" // close without touching the sticker (user reports)
)

var ErrBadAction = errors.New("service: bad moderation action")

func (s *Service) OpenReports(ctx context.Context) ([]ReportView, error) {
	return s.Admin.OpenReports(ctx, 200)
}

func (s *Service) ResolveReport(ctx context.Context, id int64, action string) error {
	switch action {
	case ActionRestore, ActionRemove, ActionDismiss:
	default:
		return ErrBadAction
	}
	return s.Admin.ResolveReport(ctx, id, action, s.Now())
}
