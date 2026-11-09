package places

import (
	"errors"
	"testing"
)

func TestKindOf(t *testing.T) {
	if k, err := KindOf("stop:pid:U1040Z1"); err != nil || k != KindStop {
		t.Fatalf("k=%v err=%v", k, err)
	}
	for _, bad := range []string{"", "stop", "stop:", "home:123", "gps:50.1,14.4"} {
		if _, err := KindOf(bad); !errors.Is(err, ErrBadID) {
			t.Errorf("KindOf(%q) err=%v", bad, err)
		}
	}
}

func TestNormalizeSelectionLimit(t *testing.T) {
	ids := []string{"stop:a", "stop:a", "route:1", "poi:osm:n1", "poi:osm:n2", "poi:osm:n3", "edu:x", "office:y", "partner:z"}
	got, err := NormalizeSelection(ids)
	if err != nil || len(got) != 8 {
		t.Fatalf("got %v err=%v", got, err)
	}
	if _, err := NormalizeSelection(append(ids, "event:e")); !errors.Is(err, ErrTooMany) {
		t.Fatalf("9 places err=%v", err)
	}
}

func TestSearchKey(t *testing.T) {
	if got := SearchKey("  Anděl  ČVUT FEL "); got != "andel cvut fel" {
		t.Fatalf("got %q", got)
	}
}

// k-anonymity: a place with 4 members is never shown as a constellation.
func TestKAnonymityFourIsNeverShown(t *testing.T) {
	c := Shared([]string{"stop:palmovka"}, []string{"stop:palmovka"}, map[string]int{"stop:palmovka": 4})
	if c.Star != "" || !c.WeakSignal || c.Score != 3 {
		t.Fatalf("got %+v", c)
	}
	c = Shared([]string{"stop:palmovka"}, []string{"stop:palmovka"}, map[string]int{"stop:palmovka": 5})
	if c.Star != "stop:palmovka" || c.WeakSignal {
		t.Fatalf("got %+v", c)
	}
}

func TestSharedRevealsOnlyOnePlace(t *testing.T) {
	mine := []string{"route:pid:22", "stop:pid:A", "poi:osm:n1", "edu:cvut"}
	theirs := []string{"route:pid:22", "stop:pid:A", "poi:osm:n1", "edu:cvut"}
	counts := map[string]int{"route:pid:22": 100, "stop:pid:A": 9, "poi:osm:n1": 50, "edu:cvut": 3}
	c := Shared(mine, theirs, counts)
	if c.Star != "stop:pid:A" {
		t.Fatalf("star=%q, want strongest qualifying place", c.Star)
	}
	if c.Score != 1+3+2+2 {
		t.Fatalf("score=%d", c.Score)
	}
}

func TestNoSharedNoSignal(t *testing.T) {
	c := Shared([]string{"stop:a"}, []string{"stop:b"}, map[string]int{"stop:a": 10, "stop:b": 10})
	if c != (Constellation{}) {
		t.Fatalf("got %+v", c)
	}
}

func TestRankStableByScore(t *testing.T) {
	type cand struct {
		id     string
		places []string
	}
	items := []cand{{"none", nil}, {"route", []string{"route:1"}}, {"stop", []string{"stop:a"}}, {"none2", nil}}
	r := Rank([]string{"stop:a", "route:1"}, items, func(c cand) []string { return c.places }, nil)
	order := []string{r[0].Item.id, r[1].Item.id, r[2].Item.id, r[3].Item.id}
	want := []string{"stop", "route", "none", "none2"}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("order=%v want %v", order, want)
		}
	}
}
