// Command places-import loads the public place catalog from open data.
//
//	places-import -region CZ-STC -zone-regions P=CZ-PHA,0=CZ-PHA,B=CZ-PHA -gtfs run/pid-gtfs.zip -feed pid
//	places-import -region CZ-PHA -osm run/praha-osm.json
//
// Sources: GTFS (CC BY 4.0, e.g. PID), OpenStreetMap via Overpass (ODbL).
// Exclusions (health, residential, non-university schools) are applied in
// internal/catalog. The catalog holds coordinates of public places only.
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lioilsources/AlienMatch/backend/internal/catalog"
	"github.com/lioilsources/AlienMatch/backend/internal/db"
	"github.com/lioilsources/AlienMatch/backend/internal/places"
	"github.com/lioilsources/AlienMatch/backend/internal/store"
)

func main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if err := run(); err != nil {
		log.Error("import failed", "err", err)
		os.Exit(1)
	}
}

func run() error {
	region := flag.String("region", "", "coarse region code for all imported places, e.g. CZ-PHA")
	gtfs := flag.String("gtfs", "", "GTFS .zip or directory")
	feed := flag.String("feed", "", "short GTFS feed id used in place ids, e.g. pid")
	zones := flag.String("zone-regions", "", "GTFS zone_id → region, e.g. P=CZ-PHA,0=CZ-PHA,B=CZ-PHA; other zones get -region")
	osm := flag.String("osm", "", "Overpass JSON file (out center tags)")
	dry := flag.Bool("dry-run", false, "parse and print counts, do not write")
	flag.Parse()
	if *region == "" || (*gtfs == "" && *osm == "") || (*gtfs != "" && *feed == "") {
		flag.Usage()
		return fmt.Errorf("need -region and -gtfs/-feed and/or -osm")
	}

	var all []catalog.Place
	if *gtfs != "" {
		fsys, closeFn, err := catalog.OpenGTFS(*gtfs)
		if err != nil {
			return err
		}
		zr, err := catalog.ParseZoneRegions(*zones)
		if err != nil {
			return err
		}
		ps, err := catalog.GTFS(fsys, catalog.GTFSOptions{Feed: *feed, Region: *region, ZoneRegions: zr})
		_ = closeFn()
		if err != nil {
			return err
		}
		all = append(all, ps...)
	}
	if *osm != "" {
		ps, err := catalog.ReadOSMFile(*osm, *region)
		if err != nil {
			return err
		}
		all = append(all, ps...)
	}
	byKind, byRegion := map[places.Kind]int{}, map[string]int{}
	for _, p := range all {
		byKind[p.Kind]++
		byRegion[p.Region]++
	}
	fmt.Fprintf(os.Stderr, "parsed %d places: %v, regions %v\n", len(all), byKind, byRegion)
	if *dry {
		return nil
	}

	url := os.Getenv("ALIENMATCH_DATABASE_URL")
	if err := db.Migrate(url); err != nil {
		return err
	}
	pool, err := pgxpool.New(context.Background(), url)
	if err != nil {
		return err
	}
	defer pool.Close()
	return store.New(pool).UpsertCatalog(context.Background(), all)
}
