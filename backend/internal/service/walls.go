package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
)

// WallStore persists waves, matches, walls, stickers, reports and blocks.
type WallStore interface {
	CountWavesSince(ctx context.Context, from string, since time.Time) (int, error)
	AddWave(ctx context.Context, from, to string, now time.Time) error
	HasWave(ctx context.Context, from, to string) (bool, error)
	// CreateMatchWithWall creates the match (DB guard applies) and its wall atomically.
	CreateMatchWithWall(ctx context.Context, a, b string, kind matching.Result) (matchID, wallID int64, err error)
	ActiveMatchBetween(ctx context.Context, a, b string) (matchID, wallID int64, err error)
	ListMatches(ctx context.Context, me string) ([]MatchView, error)
	WallMember(ctx context.Context, wallID int64, me string) (Wall, error)
	ListStickers(ctx context.Context, wallID, afterID int64) ([]Sticker, error)
	InsertSticker(ctx context.Context, s Sticker, now time.Time) (Sticker, error)
	MoveSticker(ctx context.Context, s Sticker) error
	PeelSticker(ctx context.Context, wallID, id int64, author string, now time.Time) error
	HideSticker(ctx context.Context, id int64, me string) (wallID int64, err error)
	Report(ctx context.Context, reporter string, target *string, sticker *int64, block bool, now time.Time) error
	Block(ctx context.Context, me, other string, now time.Time) error
	RadarExclusions(ctx context.Context, me string) ([]string, error)
	HasEntitlement(ctx context.Context, user, product string, now time.Time) (bool, error)
}

// Publisher pushes wall events to connected clients (realtime hub).
type Publisher interface {
	Publish(wallID int64, ev WallEvent)
}

// WallEvent is broadcast to both members of a wall.
type WallEvent struct {
	Type    string   `json:"type"` // sticker | move | peel | hide | ended
	Sticker *Sticker `json:"sticker,omitempty"`
	ID      int64    `json:"id,omitempty"`
}

// MatchView is one wall in the caller's list. SharedPlaces are revealed
// automatically after the match (owner decision 2026-11-09).
type MatchView struct {
	MatchID       int64     `json:"match_id"`
	WallID        int64     `json:"wall_id"`
	Kind          string    `json:"kind"`
	OtherID       string    `json:"other_id"`
	OtherNickname string    `json:"other_nickname,omitempty"`
	SharedPlaces  []string  `json:"shared_places"`
	CreatedAt     time.Time `json:"created_at"`
}

// Wall is the caller's view of one wall.
type Wall struct {
	ID      int64
	Gentle  bool // encouragement wall: softer visuals, no flirt/sex presets
	OtherID string
}

// Sticker is one item on a wall: vector ink or a preset image, never text.
type Sticker struct {
	ID       int64           `json:"id"`
	WallID   int64           `json:"wall_id"`
	AuthorID string          `json:"author_id"`
	ClientID string          `json:"client_id"`
	Kind     string          `json:"kind"` // ink | preset
	Preset   string          `json:"preset,omitempty"`
	Ink      json.RawMessage `json:"ink,omitempty"`
	X        float64         `json:"x"`
	Y        float64         `json:"y"`
	Rotation float64         `json:"rotation"`
	Scale    float64         `json:"scale"`
	Z        int             `json:"z"`
	Created  time.Time       `json:"created_at"`
}

// Free tier: 5 waves a day; Signál+ (or Ol1n Pass) is unlimited.
const (
	FreeWavesPerDay   = 5
	ProductSignalPlus = "signal_plus"
)

var (
	ErrNotOnRadar = errors.New("service: user is not on your radar")
	ErrWaveLimit  = errors.New("service: daily wave limit reached")
	ErrNotMember  = errors.New("service: not a member of this wall")
	ErrBadSticker = errors.New("service: bad sticker")
	ErrNotYours   = errors.New("service: not your sticker")
	ErrSelfReport = errors.New("service: cannot report yourself")
)

// Presets are image reactions. Gentle (encouragement) walls get a subset.
var (
	Presets       = []string{"heart", "ufo", "coffee", "tea", "wine", "beer", "star", "wave", "rocket", "hug", "flower", "fire"}
	GentlePresets = []string{"ufo", "coffee", "tea", "star", "wave", "hug", "flower"}
)

// WaveResult tells the app whether a wall just opened.
type WaveResult struct {
	Matched bool   `json:"matched"`
	Kind    string `json:"kind,omitempty"`
	WallID  int64  `json:"wall_id,omitempty"`
}

// Wave sends the first wordless hello. It is allowed only to someone on the
// caller's radar right now, so the mood matrix and opt-ins always apply.
// The other side learns about it only when they wave back.
func (s *Service) Wave(ctx context.Context, me, to string) (WaveResult, error) {
	if me == to {
		return WaveResult{}, ErrNotOnRadar
	}
	entries, err := s.Radar(ctx, me)
	if errors.Is(err, ErrNotFound) {
		return WaveResult{}, ErrNotOnRadar
	}
	if err != nil {
		return WaveResult{}, err
	}
	i := slices.IndexFunc(entries, func(e RadarEntry) bool { return e.Candidate.Profile.ID == to })
	if i < 0 {
		return WaveResult{}, ErrNotOnRadar
	}
	kind := entries[i].Candidate.Result
	now := s.Now()
	plus, err := s.Walls.HasEntitlement(ctx, me, ProductSignalPlus, now)
	if err != nil {
		return WaveResult{}, err
	}
	if !plus {
		y, m, d := now.UTC().Date()
		n, err := s.Walls.CountWavesSince(ctx, me, time.Date(y, m, d, 0, 0, 0, 0, time.UTC))
		if err != nil {
			return WaveResult{}, err
		}
		if n >= FreeWavesPerDay {
			return WaveResult{}, ErrWaveLimit
		}
	}
	if err := s.Walls.AddWave(ctx, me, to, now); err != nil {
		return WaveResult{}, fmt.Errorf("add wave: %w", err)
	}
	back, err := s.Walls.HasWave(ctx, to, me)
	if err != nil || !back {
		return WaveResult{}, err
	}
	_, wall, err := s.Walls.CreateMatchWithWall(ctx, me, to, kind)
	if err != nil {
		return WaveResult{}, fmt.Errorf("create match: %w", err)
	}
	return WaveResult{Matched: true, Kind: kind.String(), WallID: wall}, nil
}

// Matches lists the caller's active walls.
func (s *Service) Matches(ctx context.Context, me string) ([]MatchView, error) {
	return s.Walls.ListMatches(ctx, me)
}

// Stickers returns visible stickers after afterID (for catch-up after offline).
func (s *Service) Stickers(ctx context.Context, me string, wallID, afterID int64) ([]Sticker, error) {
	if _, err := s.Walls.WallMember(ctx, wallID, me); err != nil {
		return nil, err
	}
	return s.Walls.ListStickers(ctx, wallID, afterID)
}

// StickerInput is what the app posts. client_id makes retries idempotent.
type StickerInput struct {
	ClientID string          `json:"client_id"`
	Kind     string          `json:"kind"`
	Preset   string          `json:"preset,omitempty"`
	Ink      json.RawMessage `json:"ink,omitempty"`
	X        float64         `json:"x"`
	Y        float64         `json:"y"`
	Rotation float64         `json:"rotation"`
	Scale    float64         `json:"scale"`
}

// Stick puts a sticker on top of the wall.
func (s *Service) Stick(ctx context.Context, me string, wallID int64, in StickerInput) (Sticker, error) {
	w, err := s.Walls.WallMember(ctx, wallID, me)
	if err != nil {
		return Sticker{}, err
	}
	st := Sticker{WallID: wallID, AuthorID: me, ClientID: in.ClientID, Kind: in.Kind, X: in.X, Y: in.Y, Rotation: in.Rotation, Scale: in.Scale}
	if !validClientID(in.ClientID) || !validPlacement(in.X, in.Y, in.Rotation, in.Scale) {
		return Sticker{}, ErrBadSticker
	}
	switch in.Kind {
	case "preset":
		allowed := Presets
		if w.Gentle {
			allowed = GentlePresets
		}
		if !slices.Contains(allowed, in.Preset) {
			return Sticker{}, ErrBadSticker
		}
		st.Preset = in.Preset
	case "ink":
		norm, err := ValidateInk(in.Ink)
		if err != nil {
			return Sticker{}, err
		}
		st.Ink = norm
	default:
		return Sticker{}, ErrBadSticker
	}
	out, err := s.Walls.InsertSticker(ctx, st, s.Now())
	if err != nil {
		return Sticker{}, err
	}
	s.publish(wallID, WallEvent{Type: "sticker", Sticker: &out})
	return out, nil
}

// Move repositions one of the caller's own stickers (re-sticking on top).
func (s *Service) Move(ctx context.Context, me string, wallID, id int64, x, y, rot, scale float64, z int) error {
	if _, err := s.Walls.WallMember(ctx, wallID, me); err != nil {
		return err
	}
	if !validPlacement(x, y, rot, scale) {
		return ErrBadSticker
	}
	st := Sticker{ID: id, WallID: wallID, AuthorID: me, X: x, Y: y, Rotation: rot, Scale: scale, Z: z}
	if err := s.Walls.MoveSticker(ctx, st); err != nil {
		return err
	}
	s.publish(wallID, WallEvent{Type: "move", Sticker: &st})
	return nil
}

// Peel removes one of the caller's own stickers.
func (s *Service) Peel(ctx context.Context, me string, wallID, id int64) error {
	if _, err := s.Walls.WallMember(ctx, wallID, me); err != nil {
		return err
	}
	if err := s.Walls.PeelSticker(ctx, wallID, id, me, s.Now()); err != nil {
		return err
	}
	s.publish(wallID, WallEvent{Type: "peel", ID: id})
	return nil
}

// ReportSticker hides the sticker immediately and records the report.
func (s *Service) ReportSticker(ctx context.Context, me string, id int64, block bool) error {
	wallID, err := s.Walls.HideSticker(ctx, id, me)
	if err != nil {
		return err
	}
	if err := s.Walls.Report(ctx, me, nil, &id, block, s.Now()); err != nil {
		return err
	}
	s.publish(wallID, WallEvent{Type: "hide", ID: id})
	if block {
		w, err := s.Walls.WallMember(ctx, wallID, me)
		if err == nil {
			return s.BlockUser(ctx, me, w.OtherID)
		}
	}
	return nil
}

// BlockUser ends any wall between the two and hides them from each other.
func (s *Service) BlockUser(ctx context.Context, me, other string) error {
	if me == other {
		return ErrSelfReport
	}
	_, wallID, mErr := s.Walls.ActiveMatchBetween(ctx, me, other)
	now := s.Now()
	if err := s.Walls.Report(ctx, me, &other, nil, true, now); err != nil {
		return err
	}
	if err := s.Walls.Block(ctx, me, other, now); err != nil {
		return err
	}
	if mErr == nil {
		s.publish(wallID, WallEvent{Type: "ended"})
	}
	return nil
}

func (s *Service) publish(wallID int64, ev WallEvent) {
	if s.Pub != nil {
		s.Pub.Publish(wallID, ev)
	}
}

func validPlacement(x, y, rot, scale float64) bool {
	return x >= -1e5 && x <= 1e5 && y >= -1e5 && y <= 1e5 && rot >= -7 && rot <= 7 && scale >= 0.2 && scale <= 5
}

func validClientID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, r := range s {
		switch {
		case i == 8 || i == 13 || i == 18 || i == 23:
			if r != '-' {
				return false
			}
		case (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f'):
		default:
			return false
		}
	}
	return true
}

// Ink limits keep a sticker a drawing, not a payload.
const (
	MaxInkBytes   = 48 << 10
	MaxInkStrokes = 96
	MaxInkPoints  = 6000
	InkColors     = 8
)

// Ink is handwritten vector ink. Coordinates are 0..1 within the sticker box.
type Ink struct {
	Strokes []InkStroke `json:"strokes"`
	Aspect  float64     `json:"aspect"` // width / height of the sticker box
}

// InkStroke is one finger/stylus stroke: flat [x0,y0,x1,y1,...] list.
type InkStroke struct {
	Color int       `json:"c"` // palette index
	Width float64   `json:"w"` // relative to box width
	P     []float64 `json:"p"`
}

// ValidateInk accepts only geometry from the fixed schema and returns it
// re-encoded, so nothing else (e.g. smuggled text fields) is ever stored.
func ValidateInk(raw json.RawMessage) (json.RawMessage, error) {
	if len(raw) == 0 || len(raw) > MaxInkBytes {
		return nil, ErrBadSticker
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var ink Ink
	if err := dec.Decode(&ink); err != nil {
		return nil, ErrBadSticker
	}
	if len(ink.Strokes) == 0 || len(ink.Strokes) > MaxInkStrokes || ink.Aspect < 0.1 || ink.Aspect > 10 {
		return nil, ErrBadSticker
	}
	pts := 0
	for _, st := range ink.Strokes {
		if st.Color < 0 || st.Color >= InkColors || st.Width <= 0 || st.Width > 0.2 || len(st.P) < 2 || len(st.P)%2 != 0 {
			return nil, ErrBadSticker
		}
		for _, v := range st.P {
			if v < 0 || v > 1 {
				return nil, ErrBadSticker
			}
		}
		pts += len(st.P) / 2
	}
	if pts > MaxInkPoints {
		return nil, ErrBadSticker
	}
	return json.Marshal(ink)
}
