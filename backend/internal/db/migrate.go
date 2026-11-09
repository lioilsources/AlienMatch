// Package db holds migrations (embedded) and sqlc-generated queries.
package db

import (
	"embed"
	"errors"
	"fmt"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

//go:embed migrations/*.sql
var migrations embed.FS

// Migrate applies all up migrations. url is a postgres:// URL.
func Migrate(url string) error {
	src, err := iofs.New(migrations, "migrations")
	if err != nil {
		return fmt.Errorf("migrations source: %w", err)
	}
	_, rest, ok := strings.Cut(url, "://")
	if !ok {
		return fmt.Errorf("migrate: bad database url")
	}
	m, err := migrate.NewWithSourceInstance("iofs", src, "pgx5://"+rest)
	if err != nil {
		return fmt.Errorf("migrate init: %w", err)
	}
	defer m.Close()
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate up: %w", err)
	}
	return nil
}
