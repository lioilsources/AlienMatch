package service

import (
	"context"
	"errors"
	"fmt"
	"path"
	"slices"
	"strings"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/mood"
)

// Star ratings: the brightest stars (HIGH aura) on my radar can be rated per
// face. Ratings only feed the owner's face statistics and the rater's liked
// list; they never create a match. People in LOW are never rated and, while
// LOW, never see dislikes.

// Rating values.
const (
	RateDislike = -1
	RateSeen    = 0 // browsed past without a rating
	RateLike    = 1
)

// MaxStars caps one deck.
const MaxStars = 30

// ErrNotAStar is returned when rating someone who is not in the caller's deck.
var ErrNotAStar = errors.New("service: not a star on your radar")

// ErrBadRating is returned for a value other than -1, 0, 1.
var ErrBadRating = errors.New("service: bad rating")

// FaceStat is one face's community feedback. Dislikes is nil when hidden.
type FaceStat struct {
	PhotoKey string
	Likes    int
	Dislikes int
	Seen     int
	FirstAt  time.Time
}

// LikedRow is someone whose face I liked.
type LikedRow struct {
	UserID string
	At     time.Time
}

// RatingStore persists star ratings.
type RatingStore interface {
	RateFace(ctx context.Context, rater, target, photoKey string, value int, now time.Time) error
	// RatingsByRater maps photo keys to the rater's value (missing = unrated).
	RatingsByRater(ctx context.Context, rater string, photoKeys []string) (map[string]int, error)
	FaceStats(ctx context.Context, target string) ([]FaceStat, error)
	LikedTargets(ctx context.Context, rater string) ([]LikedRow, error)
	// OwnLevel is the user's last computed mood level ("" if none yet).
	OwnLevel(ctx context.Context, user string) (mood.Level, error)
}

// Star is one face in the rating deck.
type Star struct {
	UserID  string
	PhotoID string
	Level   mood.Level
	Trend   mood.Trend
	Rating  *int // the caller's earlier rating of this face
}

// PhotoID is the public id of a face: the random part of its media key.
func PhotoID(key string) string {
	return strings.TrimSuffix(path.Base(key), path.Ext(key))
}

// stars are radar entries with a HIGH aura, with their current photo keys.
func (s *Service) stars(ctx context.Context, me string) ([]Star, []string, error) {
	entries, err := s.Radar(ctx, me)
	if err != nil {
		return nil, nil, err
	}
	var out []Star
	var keys []string
	for _, e := range entries {
		p := e.Candidate.Profile
		if p.State.Level != mood.LevelHigh {
			continue
		}
		key, err := s.Accounts.PhotoKey(ctx, p.ID)
		if errors.Is(err, ErrNotFound) || key == "" {
			continue
		}
		if err != nil {
			return nil, nil, fmt.Errorf("photo key: %w", err)
		}
		out = append(out, Star{UserID: p.ID, PhotoID: PhotoID(key), Level: p.State.Level, Trend: p.State.Trend})
		keys = append(keys, key)
		if len(out) == MaxStars {
			break
		}
	}
	return out, keys, nil
}

// Stars is the caller's rating deck, with their earlier ratings of these
// exact faces (a new profile photo starts unrated).
func (s *Service) Stars(ctx context.Context, me string) ([]Star, error) {
	out, keys, err := s.stars(ctx, me)
	if err != nil || len(out) == 0 {
		return out, err
	}
	mine, err := s.Ratings.RatingsByRater(ctx, me, keys)
	if err != nil {
		return nil, fmt.Errorf("ratings: %w", err)
	}
	for i, k := range keys {
		if v, ok := mine[k]; ok {
			out[i].Rating = &v
		}
	}
	return out, nil
}

// Rate stores the caller's rating of a star's current face.
func (s *Service) Rate(ctx context.Context, me, target string, value int) error {
	if value < RateDislike || value > RateLike {
		return ErrBadRating
	}
	deck, keys, err := s.stars(ctx, me)
	if errors.Is(err, ErrNotFound) {
		return ErrNotAStar
	}
	if err != nil {
		return err
	}
	i := slices.IndexFunc(deck, func(st Star) bool { return st.UserID == target })
	if i < 0 {
		return ErrNotAStar
	}
	return s.Ratings.RateFace(ctx, me, target, keys[i], value, s.Now())
}

// FaceStatsResult is the caller's feedback per face.
type FaceStatsResult struct {
	Faces          []FaceStat
	CurrentKey     string
	DislikesHidden bool
}

// MyFaceStats returns how the community rated each of the caller's faces.
// While the caller is LOW, dislikes are left out.
func (s *Service) MyFaceStats(ctx context.Context, me string) (FaceStatsResult, error) {
	stats, err := s.Ratings.FaceStats(ctx, me)
	if err != nil {
		return FaceStatsResult{}, fmt.Errorf("face stats: %w", err)
	}
	cur, err := s.Accounts.PhotoKey(ctx, me)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return FaceStatsResult{}, err
	}
	lvl, err := s.Ratings.OwnLevel(ctx, me)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return FaceStatsResult{}, err
	}
	hide := lvl == mood.LevelLow
	if hide {
		for i := range stats {
			stats[i].Dislikes = 0
		}
	}
	return FaceStatsResult{Faces: stats, CurrentKey: cur, DislikesHidden: hide}, nil
}

// Liked is someone I liked, and whether a wave is possible right now.
type Liked struct {
	UserID  string
	At      time.Time
	OnRadar bool
}

// MyLiked lists the people whose faces the caller liked. Waving still goes
// through the radar (the mood matrix decides), so OnRadar says if it can.
func (s *Service) MyLiked(ctx context.Context, me string) ([]Liked, error) {
	rows, err := s.Ratings.LikedTargets(ctx, me)
	if err != nil {
		return nil, fmt.Errorf("liked: %w", err)
	}
	onRadar := map[string]bool{}
	entries, err := s.Radar(ctx, me)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return nil, err
	}
	for _, e := range entries {
		onRadar[e.Candidate.Profile.ID] = true
	}
	out := make([]Liked, len(rows))
	for i, r := range rows {
		out[i] = Liked{UserID: r.UserID, At: r.At, OnRadar: onRadar[r.UserID]}
	}
	return out, nil
}
