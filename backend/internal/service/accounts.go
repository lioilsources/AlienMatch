package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"slices"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/lioilsources/AlienMatch/backend/internal/matching"
)

// AccountStore persists anonymous accounts and profiles.
type AccountStore interface {
	CreateAccount(ctx context.Context, tokenHash []byte, now time.Time, moodConsent bool) (string, error)
	UserByTokenHash(ctx context.Context, tokenHash []byte) (string, error)
	Me(ctx context.Context, userID string) (Me, error)
	SaveProfile(ctx context.Context, userID string, p ProfileInput, now time.Time) error
	// SwapPhoto stores the new media key and returns the previous one ("" if none).
	SwapPhoto(ctx context.Context, userID, key string, now time.Time) (string, error)
	PhotoKey(ctx context.Context, userID string) (string, error)
	// DeleteAccount removes the user and all rows; returns the photo key.
	DeleteAccount(ctx context.Context, userID string) (string, error)
}

// MediaStore keeps profile photos. FS now, MinIO later.
type MediaStore interface {
	Put(ctx context.Context, key string, data []byte) error
	Get(ctx context.Context, key string) ([]byte, error)
	Delete(ctx context.Context, key string) error
}

// Me is the caller's own account view.
type Me struct {
	UserID      string        `json:"user_id"`
	MoodConsent bool          `json:"mood_consent"`
	VLEnabled   bool          `json:"vl_enabled"`
	HasProfile  bool          `json:"has_profile"`
	HasPhoto    bool          `json:"has_photo"`
	Profile     *ProfileInput `json:"profile,omitempty"`
}

// ProfileInput is everything the user sets in onboarding. All icons, except
// the optional nickname (the only free text in the product).
type ProfileInput struct {
	Nickname           string                `json:"nickname,omitempty"`
	Generation         matching.Generation   `json:"generation"`
	Status             matching.Status       `json:"status"`
	KidsCount          *int                  `json:"kids_count,omitempty"`
	KidsFlags          []string              `json:"kids_flags"`
	Region             string                `json:"region"`
	SeekGenerations    []matching.Generation `json:"seek_generations"`
	SeekStatuses       []matching.Status     `json:"seek_statuses"`
	Intents            []matching.Intent     `json:"intents"`
	CanBeBeacon        bool                  `json:"can_be_beacon"`
	WantsEncouragement bool                  `json:"wants_encouragement"`
	BeaconOnly         bool                  `json:"beacon_only"`
}

var (
	generations = []matching.Generation{matching.GenZ, matching.Millennial, matching.GenX, matching.BabyBoomer}
	statuses    = []matching.Status{matching.StatusSingle, matching.StatusMarried, matching.StatusDivorced, matching.StatusComplicated}
	intents     = []matching.Intent{matching.IntentFlirt, matching.IntentSex, matching.IntentChat, matching.IntentCafe,
		matching.IntentBeer, matching.IntentWine, matching.IntentTea, matching.IntentWalk, matching.IntentPlay}
	kidsFlags = []string{"boys", "girls", "twins", "triplets"}
	// Regions selectable in the MVP (Prague first). Picked by hand, never from GPS.
	Regions = []string{"CZ-PHA"}
)

// ErrInvalid wraps profile validation failures.
var ErrInvalid = errors.New("service: invalid input")

// MaxNickname is the nickname limit in characters.
const MaxNickname = 12

// Validate checks every field against the allowed icon sets.
func (p *ProfileInput) Validate() error {
	bad := func(f string) error { return fmt.Errorf("%s: %w", f, ErrInvalid) }
	if !validNickname(p.Nickname) {
		return bad("nickname")
	}
	if !slices.Contains(generations, p.Generation) {
		return bad("generation")
	}
	if !slices.Contains(statuses, p.Status) {
		return bad("status")
	}
	if p.KidsCount != nil && (*p.KidsCount < 0 || *p.KidsCount > 5) {
		return bad("kids_count")
	}
	if !subset(p.KidsFlags, kidsFlags) {
		return bad("kids_flags")
	}
	if !slices.Contains(Regions, p.Region) {
		return bad("region")
	}
	if !subset(p.SeekGenerations, generations) || !subset(p.SeekStatuses, statuses) {
		return bad("seek")
	}
	if len(p.Intents) == 0 || !subset(p.Intents, intents) {
		return bad("intents")
	}
	if p.BeaconOnly {
		// A beacon-only profile exists to encourage; it needs the beacon switch.
		p.CanBeBeacon = true
	}
	p.KidsFlags = dedupe(p.KidsFlags)
	p.SeekGenerations = dedupe(p.SeekGenerations)
	p.SeekStatuses = dedupe(p.SeekStatuses)
	p.Intents = dedupe(p.Intents)
	return nil
}

// validNickname: empty, or 1-12 letters/digits with single inner '-' or '.'.
// Moderation of the content itself happens asynchronously.
func validNickname(s string) bool {
	if s == "" {
		return true
	}
	if utf8.RuneCountInString(s) > MaxNickname || !utf8.ValidString(s) {
		return false
	}
	for i, r := range []rune(s) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
		case (r == '-' || r == '.') && i > 0 && i < utf8.RuneCountInString(s)-1:
		default:
			return false
		}
	}
	return true
}

func subset[T comparable](xs, allowed []T) bool {
	for _, x := range xs {
		if !slices.Contains(allowed, x) {
			return false
		}
	}
	return true
}

func dedupe[T comparable](xs []T) []T {
	out := make([]T, 0, len(xs))
	for _, x := range xs {
		if !slices.Contains(out, x) {
			out = append(out, x)
		}
	}
	return out
}

// ErrNoAdultConfirmation: the 18+ checkbox is mandatory (store requirement).
var ErrNoAdultConfirmation = errors.New("service: 18+ confirmation required")

// NewToken returns a random bearer token and its SHA-256 hash.
func NewToken() (token string, hash []byte, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", nil, err
	}
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, HashToken(token), nil
}

// HashToken is what the server stores and looks up.
func HashToken(token string) []byte {
	h := sha256.Sum256([]byte(token))
	return h[:]
}

// CreateAccount registers an anonymous account. Mood scoring from face and
// voice is special-category data (GDPR art. 9) and needs its own consent;
// without it the account runs on self-score only.
func (s *Service) CreateAccount(ctx context.Context, adult, moodConsent bool) (userID, token string, err error) {
	if !adult {
		return "", "", ErrNoAdultConfirmation
	}
	token, hash, err := NewToken()
	if err != nil {
		return "", "", err
	}
	id, err := s.Accounts.CreateAccount(ctx, hash, s.Now(), moodConsent)
	if err != nil {
		return "", "", fmt.Errorf("create account: %w", err)
	}
	return id, token, nil
}

// SaveProfile validates and stores the onboarding profile.
func (s *Service) SaveProfile(ctx context.Context, userID string, p ProfileInput) error {
	if err := p.Validate(); err != nil {
		return err
	}
	return s.Accounts.SaveProfile(ctx, userID, p, s.Now())
}

// Photo limits: the app sends a finished mirror variant, max 1024 px.
const MaxPhotoBytes = 1 << 20

// ErrBadPhoto is returned for anything that is not a small JPEG/WebP/PNG.
var ErrBadPhoto = errors.New("service: bad photo")

// SetPhoto stores the chosen mirror variant and deletes the previous file.
// Only the chosen variant ever reaches the server; the original never does.
// It returns the face's public id (see PhotoID) for the face statistics.
func (s *Service) SetPhoto(ctx context.Context, userID string, data []byte) (string, error) {
	ext := photoExt(data)
	if ext == "" || len(data) > MaxPhotoBytes {
		return "", ErrBadPhoto
	}
	rnd := make([]byte, 12)
	if _, err := rand.Read(rnd); err != nil {
		return "", err
	}
	key := fmt.Sprintf("photos/%s/%s.%s", userID, base64.RawURLEncoding.EncodeToString(rnd), ext)
	if err := s.Media.Put(ctx, key, data); err != nil {
		return "", fmt.Errorf("put photo: %w", err)
	}
	prev, err := s.Accounts.SwapPhoto(ctx, userID, key, s.Now())
	if err != nil {
		_ = s.Media.Delete(ctx, key)
		return "", fmt.Errorf("swap photo: %w", err)
	}
	if prev != "" {
		_ = s.Media.Delete(ctx, prev)
	}
	return PhotoID(key), nil
}

// Photo returns a user's photo bytes.
func (s *Service) Photo(ctx context.Context, userID string) ([]byte, error) {
	key, err := s.Accounts.PhotoKey(ctx, userID)
	if err != nil {
		return nil, err
	}
	if key == "" {
		return nil, ErrNotFound
	}
	return s.Media.Get(ctx, key)
}

// DeleteAccount removes everything: rows cascade, media is deleted.
func (s *Service) DeleteAccount(ctx context.Context, userID string) error {
	key, err := s.Accounts.DeleteAccount(ctx, userID)
	if err != nil {
		return fmt.Errorf("delete account: %w", err)
	}
	if key != "" {
		if err := s.Media.Delete(ctx, key); err != nil {
			return fmt.Errorf("delete photo: %w", err)
		}
	}
	return nil
}

func photoExt(b []byte) string {
	switch {
	case len(b) > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF:
		return "jpg"
	case len(b) > 12 && string(b[0:4]) == "RIFF" && string(b[8:12]) == "WEBP":
		return "webp"
	case len(b) > 8 && string(b[1:4]) == "PNG":
		return "png"
	default:
		return ""
	}
}
