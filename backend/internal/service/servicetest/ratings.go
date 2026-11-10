package servicetest

import (
	"context"
	"slices"
	"sync"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

type rating struct {
	rater, target, key string
	value              int
	at                 time.Time
}

// Ratings is an in-memory service.RatingStore. Levels mirror mood_state;
// Blocked pairs are hidden from LikedTargets like the SQL does.
type Ratings struct {
	mu      sync.Mutex
	Rows    []rating
	Levels  map[string]mood.Level
	Blocked map[[2]string]bool
}

// NewRatings returns an empty rating store.
func NewRatings() *Ratings {
	return &Ratings{Levels: map[string]mood.Level{}, Blocked: map[[2]string]bool{}}
}

var _ service.RatingStore = (*Ratings)(nil)

func (r *Ratings) RateFace(_ context.Context, rater, target, key string, v int, now time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for i := range r.Rows {
		if r.Rows[i].rater == rater && r.Rows[i].key == key {
			r.Rows[i].value, r.Rows[i].at = v, now
			return nil
		}
	}
	r.Rows = append(r.Rows, rating{rater, target, key, v, now})
	return nil
}

func (r *Ratings) RatingsByRater(_ context.Context, rater string, keys []string) (map[string]int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := map[string]int{}
	for _, x := range r.Rows {
		if x.rater == rater && slices.Contains(keys, x.key) {
			out[x.key] = x.value
		}
	}
	return out, nil
}

func (r *Ratings) FaceStats(_ context.Context, target string) ([]service.FaceStat, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	by := map[string]*service.FaceStat{}
	var order []string
	for _, x := range r.Rows {
		if x.target != target {
			continue
		}
		st, ok := by[x.key]
		if !ok {
			st = &service.FaceStat{PhotoKey: x.key, FirstAt: x.at}
			by[x.key] = st
			order = append(order, x.key)
		}
		st.Seen++
		switch x.value {
		case 1:
			st.Likes++
		case -1:
			st.Dislikes++
		}
		if x.at.Before(st.FirstAt) {
			st.FirstAt = x.at
		}
	}
	out := make([]service.FaceStat, 0, len(order))
	for _, k := range order {
		out = append(out, *by[k])
	}
	slices.SortFunc(out, func(a, b service.FaceStat) int { return b.FirstAt.Compare(a.FirstAt) })
	return out, nil
}

func (r *Ratings) LikedTargets(_ context.Context, rater string) ([]service.LikedRow, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	latest := map[string]time.Time{}
	for _, x := range r.Rows {
		if x.rater != rater || x.value != 1 || r.Blocked[[2]string{rater, x.target}] || r.Blocked[[2]string{x.target, rater}] {
			continue
		}
		if x.at.After(latest[x.target]) {
			latest[x.target] = x.at
		}
	}
	out := make([]service.LikedRow, 0, len(latest))
	for u, at := range latest {
		out = append(out, service.LikedRow{UserID: u, At: at})
	}
	slices.SortFunc(out, func(a, b service.LikedRow) int { return b.At.Compare(a.At) })
	return out, nil
}

func (r *Ratings) OwnLevel(_ context.Context, u string) (mood.Level, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	l, ok := r.Levels[u]
	if !ok {
		return "", service.ErrNotFound
	}
	return l, nil
}
