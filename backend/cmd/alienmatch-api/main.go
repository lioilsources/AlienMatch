// Command alienmatch-api serves profiles, check-ins and the radar.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lioilsources/AlienMatch/backend/internal/api"
	"github.com/lioilsources/AlienMatch/backend/internal/db"
	"github.com/lioilsources/AlienMatch/backend/internal/media"
	"github.com/lioilsources/AlienMatch/backend/internal/moodscore"
	"github.com/lioilsources/AlienMatch/backend/internal/realtime"
	"github.com/lioilsources/AlienMatch/backend/internal/service"
	"github.com/lioilsources/AlienMatch/backend/internal/store"
)

func main() {
	// "healthcheck" is for the container HEALTHCHECK (distroless has no curl).
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}
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
	hub := realtime.NewHub()
	svc := &service.Service{Store: st, Accounts: st, Walls: st, Flyby: st, Admin: st, Pub: hub, Media: media.FS{Root: envOr("ALIENMATCH_MEDIA_DIR", "run/media")}, Now: time.Now}
	if u := os.Getenv("ALIENMATCH_GATEWAY_URL"); u != "" {
		// Mood scoring via LiteLLM on SPARK; without it check-ins are self-only.
		svc.Scorer = &moodscore.Gateway{
			BaseURL: u, APIKey: os.Getenv("ALIENMATCH_GATEWAY_KEY"),
			VLModel: envOr("ALIENMATCH_VL_MODEL", "vl"), ASRModel: envOr("ALIENMATCH_ASR_MODEL", "asr"),
		}
		log.Info("mood scoring enabled", "vl", envOr("ALIENMATCH_VL_MODEL", "vl"))
	}
	rt := &api.Realtime{Hub: hub, Tickets: realtime.NewTickets(time.Now), OriginPatterns: strings.Fields(os.Getenv("ALIENMATCH_WS_ORIGINS"))}
	go housekeeping(ctx, svc, log)
	srv := &http.Server{Addr: addr, Handler: api.Handler(svc, auth, log, api.WithRealtime(rt), api.WithAdmin(os.Getenv("ALIENMATCH_ADMIN_TOKEN"))), ReadHeaderTimeout: 5 * time.Second}
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

func healthcheck() int {
	addr := envOr("ALIENMATCH_ADDR", ":8080")
	if strings.HasPrefix(addr, ":") {
		addr = "127.0.0.1" + addr
	}
	c := &http.Client{Timeout: 3 * time.Second}
	res, err := c.Get("http://" + addr + "/healthz")
	if err != nil {
		return 1
	}
	res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
