package store

import (
	"context"
	"testing"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func TestModerationQueueInDB(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	a := seedUser(t, pool, "HIGH", false, false)
	b := seedUser(t, pool, "HIGH", false, false)
	_, wall, err := s.CreateMatchWithWall(ctx, a, b, matching.Match)
	if err != nil {
		t.Fatal(err)
	}
	ink := []byte(`{"aspect":1,"strokes":[{"c":3,"w":0.02,"p":[0,0,1,1]}]}`)
	st, _ := s.InsertSticker(ctx, service.Sticker{WallID: wall, AuthorID: a, ClientID: "0f8fad5b-d9cb-469f-a165-70867728950e", Kind: "ink", Ink: ink, Scale: 1}, tNow)
	if _, err := s.HideSticker(ctx, st.ID, b); err != nil {
		t.Fatal(err)
	}
	_ = s.Report(ctx, b, nil, &st.ID, false, tNow)

	open, err := s.OpenReports(ctx, 10)
	if err != nil || len(open) != 1 || open[0].Sticker == nil || open[0].Sticker.Moderation != "review" || len(open[0].Sticker.Ink) == 0 {
		t.Fatalf("open=%+v err=%v", open, err)
	}
	if vis, _ := s.ListStickers(ctx, wall, 0); len(vis) != 0 {
		t.Fatal("reported sticker visible before review")
	}
	if err := s.ResolveReport(ctx, open[0].ID, service.ActionRestore, tNow); err != nil {
		t.Fatal(err)
	}
	if vis, _ := s.ListStickers(ctx, wall, 0); len(vis) != 1 {
		t.Fatal("restored sticker not visible")
	}
	if open, _ := s.OpenReports(ctx, 10); len(open) != 0 {
		t.Fatalf("report still open: %+v", open)
	}
	if err := s.ResolveReport(ctx, open[0].ID, service.ActionRemove, tNow); err != service.ErrNotFound {
		t.Fatalf("resolving twice: %v", err)
	}

	_, _ = s.HideSticker(ctx, st.ID, b)
	_ = s.Report(ctx, b, nil, &st.ID, true, tNow)
	open, _ = s.OpenReports(ctx, 10)
	if err := s.ResolveReport(ctx, open[0].ID, service.ActionRemove, tNow); err != nil {
		t.Fatal(err)
	}
	var removed bool
	_ = pool.QueryRow(ctx, `SELECT removed_at IS NOT NULL FROM stickers WHERE id = $1`, st.ID).Scan(&removed)
	if !removed {
		t.Fatal("removed sticker still on the wall")
	}
}
