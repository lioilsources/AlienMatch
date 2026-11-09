// Command alienmatch-api serves profiles, check-ins and the radar.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lioilsources/AlienMatch/backend/internal/api"
	"github.com/lioilsources/AlienMatch/backend/internal/db"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("exit", "err", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	dbURL := os.Getenv("ALIENMATCH_DATABASE_URL")
	addr := envOr("ALIENMATCH_ADDR", ":8080")
	if err := db.Migrate(dbURL); err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	var auth api.Authenticator
	if os.Getenv("ALIENMATCH_DEV_AUTH") == "1" {
		log.Warn("dev auth enabled: X-AlienMatch-User header is trusted")
		auth = api.DevAuth{}
	} else {
		auth = denyAll{} // real auth lands in phase 2
	}
	svc := &service.Service{Store: store.New(pool), Now: time.Now}
	srv := &http.Server{Addr: addr, Handler: api.Handler(svc, auth, log), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		<-ctx.Done()
		sctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(sctx)
	}()
	log.Info("listening", "addr", addr)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

type denyAll struct{}

func (denyAll) UserID(*http.Request) (string, bool) { return "", false }

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
