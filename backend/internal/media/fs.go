// Package media stores profile photos. FS implementation for now; MinIO
// (S3) on JODA replaces it behind the same service.MediaStore interface.
package media

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/lioilsources/AlienMatch/backend/internal/service"
)

// FS stores files under Root.
type FS struct{ Root string }

var _ service.MediaStore = FS{}

func (f FS) path(key string) (string, error) {
	clean := filepath.Clean("/" + key)
	if strings.Contains(key, "..") || clean == "/" {
		return "", fmt.Errorf("media: bad key %q", key)
	}
	return filepath.Join(f.Root, clean), nil
}

func (f FS) Put(_ context.Context, key string, data []byte) error {
	p, err := f.path(key)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o750); err != nil {
		return err
	}
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, data, 0o640); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

func (f FS) Get(_ context.Context, key string) ([]byte, error) {
	p, err := f.path(key)
	if err != nil {
		return nil, err
	}
	b, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return nil, service.ErrNotFound
	}
	return b, err
}

func (f FS) Delete(_ context.Context, key string) error {
	p, err := f.path(key)
	if err != nil {
		return err
	}
	if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	// Remove the per-user directory when empty (account deletion).
	_ = os.Remove(filepath.Dir(p))
	return nil
}
