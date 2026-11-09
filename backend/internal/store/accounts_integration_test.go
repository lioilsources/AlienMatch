package store

import (
	"context"
	"testing"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

func TestAccountProfileRoundTripAndFullDelete(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	s := New(pool)
	seedCatalog(t, s, 0)
	_, hash, _ := service.NewToken()
	id, err := s.CreateAccount(ctx, hash, tNow, true)
	if err != nil {
		t.Fatal(err)
	}
	if got, err := s.UserByTokenHash(ctx, hash); err != nil || got != id {
		t.Fatalf("lookup=%q err=%v", got, err)
	}
	kids := 2
	p := service.ProfileInput{
		Nickname: "Zq-7", Generation: matching.GenX, Status: matching.StatusDivorced, KidsCount: &kids,
		KidsFlags: []string{"twins"}, Region: "CZ-PHA", SeekGenerations: []matching.Generation{matching.GenX, matching.Millennial},
		SeekStatuses: []matching.Status{matching.StatusSingle}, Intents: []matching.Intent{matching.IntentWine},
		CanBeBeacon: true, BeaconOnly: true,
	}
	if err := s.SaveProfile(ctx, id, p, tNow); err != nil {
		t.Fatal(err)
	}
	if prev, err := s.SwapPhoto(ctx, id, "photos/x/1.jpg", tNow); err != nil || prev != "" {
		t.Fatalf("prev=%q err=%v", prev, err)
	}
	if prev, _ := s.SwapPhoto(ctx, id, "photos/x/2.jpg", tNow); prev != "photos/x/1.jpg" {
		t.Fatalf("prev=%q", prev)
	}
	me, err := s.Me(ctx, id)
	if err != nil || !me.HasProfile || !me.HasPhoto || !me.MoodConsent || me.Profile.Nickname != "Zq-7" ||
		*me.Profile.KidsCount != 2 || len(me.Profile.SeekGenerations) != 2 || me.Profile.Intents[0] != matching.IntentWine || !me.Profile.BeaconOnly {
		t.Fatalf("me=%+v profile=%+v err=%v", me, me.Profile, err)
	}

	// Fill every user-linked table, then delete and check nothing is left.
	exec := func(q string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, q, args...); err != nil {
			t.Fatal(err)
		}
	}
	exec(`INSERT INTO mood_state (user_id, level, trend, mood, last_checkin_at, computed_at) VALUES ($1,'HIGH','FLAT',0.7,now(),now())`, id)
	exec(`INSERT INTO checkins (user_id, at, mode, self_score, mood) VALUES ($1, now(), 'voice', 0.7, 0.7)`, id)
	exec(`INSERT INTO profile_places (user_id, place_id) VALUES ($1, 'stop:pid:A')`, id)
	exec(`INSERT INTO tek_uploads VALUES ($1, '2026-11-08', $2, 'CZ-PHA')`, id, make([]byte, 16))
	exec(`INSERT INTO venue_checkins VALUES ($1, 'stop:pid:A', '2026-11-09 09:00Z', '2026-11-09 15:00Z')`, id)
	exec(`INSERT INTO entitlements (user_id, product, source) VALUES ($1, 'signal_plus', 'ol1n_pass')`, id)

	key, err := s.DeleteAccount(ctx, id)
	if err != nil || key != "photos/x/2.jpg" {
		t.Fatalf("key=%q err=%v", key, err)
	}
	rows, err := pool.Query(ctx, `
		SELECT c.table_name, c.column_name FROM information_schema.columns c
		JOIN information_schema.tables t ON t.table_name = c.table_name AND t.table_schema = c.table_schema
		WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE' AND c.data_type = 'uuid'`)
	if err != nil {
		t.Fatal(err)
	}
	var cols [][2]string
	for rows.Next() {
		var tbl, col string
		_ = rows.Scan(&tbl, &col)
		cols = append(cols, [2]string{tbl, col})
	}
	rows.Close()
	for _, c := range cols {
		var n int
		if err := pool.QueryRow(ctx, `SELECT count(*) FROM `+c[0]+` WHERE `+c[1]+` = $1`, id).Scan(&n); err != nil {
			t.Fatal(err)
		}
		if n != 0 {
			t.Errorf("%s.%s still has %d rows after account deletion", c[0], c[1], n)
		}
	}
	if len(cols) < 10 {
		t.Fatalf("audit found only %d uuid columns; query broken?", len(cols))
	}
}
