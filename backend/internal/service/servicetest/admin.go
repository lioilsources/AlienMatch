package servicetest

import (
	"context"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// Admin is an in-memory service.AdminStore.
type Admin struct {
	Reports  []service.ReportView
	Resolved map[int64]string
}

var _ service.AdminStore = (*Admin)(nil)

func (a *Admin) OpenReports(context.Context, int) ([]service.ReportView, error) {
	var out []service.ReportView
	for _, r := range a.Reports {
		if _, done := a.Resolved[r.ID]; !done {
			out = append(out, r)
		}
	}
	return out, nil
}

func (a *Admin) ResolveReport(_ context.Context, id int64, action string, _ time.Time) error {
	for _, r := range a.Reports {
		if r.ID == id {
			if a.Resolved == nil {
				a.Resolved = map[int64]string{}
			}
			a.Resolved[id] = action
			return nil
		}
	}
	return service.ErrNotFound
}
