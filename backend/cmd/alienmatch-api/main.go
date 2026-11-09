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
	"github.com/lioilsources/AlienMatch/backend/internal/media"
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

	st := store.New(pool)
	var auth api.Authenticator = api.BearerAuth{Lookup: st.UserByTokenHash}
	if os.Getenv("ALIENMATCH_DEV_AUTH") == "1" {
		log.Warn("dev auth enabled: X-AlienMatch-User header is trusted")
		auth = api.DevAuth{}
	}
	svc := &service.Service{Store: st, Accounts: st, Media: media.FS{Root: envOr("ALIENMATCH_MEDIA_DIR", "run/media")}, Now: time.Now}
	go housekeeping(ctx, svc, log)
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

// housekeeping refreshes k-anonymity counts and enforces TTLs every 10 minutes.
func housekeeping(ctx context.Context, svc *service.Service, log *slog.Logger) {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for {
		st, err := svc.Housekeeping(ctx)
		if err != nil {
			log.Error("housekeeping", "err", err)
		} else {
			log.Info("housekeeping", "tek", st.TEK, "encounters", st.Encounters, "venue_checkins", st.VenueCheckins, "events", st.Events)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
