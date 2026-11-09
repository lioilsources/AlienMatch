// Package catalog builds the public place catalog from open data:
// GTFS (stops, routes) and OpenStreetMap (Overpass JSON).
//
// Exclusion rules from Prompts/01-GPS.md §2, §5 are enforced here:
// no health facilities, no residential buildings, no primary/secondary
// schools (only universities and colleges), nothing without a name.
package catalog

import (
	"archive/zip"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/lioilsources/AlienMatch/backend/internal/places"
)

// Place is one catalog entry ready for upsert.
type Place struct {
	ID      string
	Kind    places.Kind
	Name    string
	Subtype string
	Lat     *float64
	Lon     *float64
	Region  string
	Source  string
}

// OpenGTFS opens a GTFS feed from a .zip file or an unpacked directory.
func OpenGTFS(path string) (fs.FS, func() error, error) {
	st, err := os.Stat(path)
	if err != nil {
		return nil, nil, err
	}
	if st.IsDir() {
		return os.DirFS(path), func() error { return nil }, nil
	}
	z, err := zip.OpenReader(path)
	if err != nil {
		return nil, nil, fmt.Errorf("open gtfs zip: %w", err)
	}
	return z, z.Close, nil
}

// GTFSOptions configure one feed.
type GTFSOptions struct {
	Feed   string // short id used in place ids, e.g. "pid"
	Region string // default region
	// ZoneRegions maps a GTFS zone_id (first token) to a region, e.g. PID
	// zones P/0/B are Prague. Routes always get Region.
	ZoneRegions map[string]string
}

func (o GTFSOptions) regionOf(zone string) string {
	z, _, _ := strings.Cut(strings.TrimSpace(zone), ",")
	if r, ok := o.ZoneRegions[z]; ok {
		return r
	}
	return o.Region
}

// GTFS reads stops.txt and routes.txt.
//
// People on different platforms of one stop must share one place (otherwise
// the k-anonymity count is split and nobody ever sees a constellation), so:
// platforms with a parent station fold into the station, and feeds with an
// `asw_node_id` column (PID) fold all platforms of a node into `stop:<feed>:N<node>`.
func GTFS(fsys fs.FS, o GTFSOptions) ([]Place, error) {
	var out []Place
	src := "gtfs:" + o.Feed
	type node struct {
		p        Place
		lat, lon float64
		n        int
	}
	nodes := map[string]*node{}
	var order []string
	err := readCSV(fsys, "stops.txt", func(r map[string]string) {
		lt := r["location_type"]
		if lt != "" && lt != "0" && lt != "1" {
			return // entrances, nodes, boarding areas
		}
		if (lt == "" || lt == "0") && r["parent_station"] != "" {
			return
		}
		name := strings.TrimSpace(r["stop_name"])
		if name == "" || r["stop_id"] == "" {
			return
		}
		lat, lon := parseFloat(r["stop_lat"]), parseFloat(r["stop_lon"])
		if nid := strings.TrimSpace(r["asw_node_id"]); nid != "" && lt != "1" {
			id := "stop:" + o.Feed + ":N" + nid
			nd, ok := nodes[id]
			if !ok {
				nd = &node{p: Place{ID: id, Kind: places.KindStop, Name: name, Region: o.regionOf(r["zone_id"]), Source: src}}
				nodes[id] = nd
				order = append(order, id)
			}
			if lat != nil && lon != nil {
				nd.lat += *lat
				nd.lon += *lon
				nd.n++
			}
			return
		}
		out = append(out, Place{ID: "stop:" + o.Feed + ":" + r["stop_id"], Kind: places.KindStop, Name: name,
			Region: o.regionOf(r["zone_id"]), Source: src, Lat: lat, Lon: lon})
	})
	if err != nil {
		return nil, err
	}
	for _, id := range order {
		nd := nodes[id]
		if nd.n > 0 {
			lat, lon := nd.lat/float64(nd.n), nd.lon/float64(nd.n)
			nd.p.Lat, nd.p.Lon = &lat, &lon
		}
		out = append(out, nd.p)
	}
	err = readCSV(fsys, "routes.txt", func(r map[string]string) {
		name := strings.TrimSpace(r["route_short_name"])
		if name == "" {
			name = strings.TrimSpace(r["route_long_name"])
		}
		if name == "" || r["route_id"] == "" {
			return
		}
		out = append(out, Place{
			ID: "route:" + o.Feed + ":" + r["route_id"], Kind: places.KindRoute, Name: name,
			Subtype: routeType(r["route_type"]), Region: o.Region, Source: src,
		})
	})
	return out, err
}

// ParseZoneRegions parses "P=CZ-PHA,0=CZ-PHA,B=CZ-PHA".
func ParseZoneRegions(s string) (map[string]string, error) {
	m := map[string]string{}
	for _, kv := range strings.Split(s, ",") {
		if strings.TrimSpace(kv) == "" {
			continue
		}
		k, v, ok := strings.Cut(kv, "=")
		if !ok || strings.TrimSpace(k) == "" || strings.TrimSpace(v) == "" {
			return nil, fmt.Errorf("zone regions: bad pair %q", kv)
		}
		m[strings.TrimSpace(k)] = strings.TrimSpace(v)
	}
	return m, nil
}

func routeType(t string) string {
	switch t {
	case "0", "900":
		return "tram"
	case "1", "401":
		return "metro"
	case "2", "100", "109":
		return "rail"
	case "3", "700":
		return "bus"
	case "4", "1000":
		return "ferry"
	case "7", "1400":
		return "funicular"
	case "11", "800":
		return "trolleybus"
	default:
		return "transit"
	}
}

func readCSV(fsys fs.FS, name string, row func(map[string]string)) error {
	f, err := fsys.Open(name)
	if err != nil {
		return fmt.Errorf("gtfs %s: %w", name, err)
	}
	defer f.Close()
	cr := csv.NewReader(f)
	cr.FieldsPerRecord = -1
	cr.LazyQuotes = true
	head, err := cr.Read()
	if err != nil {
		return fmt.Errorf("gtfs %s header: %w", name, err)
	}
	head[0] = strings.TrimPrefix(head[0], "\ufeff")
	for {
		rec, err := cr.Read()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("gtfs %s: %w", name, err)
		}
		m := make(map[string]string, len(head))
		for i, h := range head {
			if i < len(rec) {
				m[strings.TrimSpace(h)] = rec[i]
			}
		}
		row(m)
	}
}

func parseFloat(s string) *float64 {
	var f float64
	if _, err := fmt.Sscan(strings.TrimSpace(s), &f); err != nil {
		return nil
	}
	return &f
}

// overpass is the subset of Overpass API JSON (`out center tags;`) we read.
type overpass struct {
	Elements []struct {
		Type   string                      `json:"type"`
		ID     int64                       `json:"id"`
		Lat    *float64                    `json:"lat"`
		Lon    *float64                    `json:"lon"`
		Center *struct{ Lat, Lon float64 } `json:"center"`
		Tags   map[string]string           `json:"tags"`
	} `json:"elements"`
}

// OSM reads Overpass JSON and keeps only allowed, named places.
func OSM(r io.Reader, region string) ([]Place, error) {
	var doc overpass
	if err := json.NewDecoder(r).Decode(&doc); err != nil {
		return nil, fmt.Errorf("overpass json: %w", err)
	}
	var out []Place
	seen := map[string]bool{}
	for _, e := range doc.Elements {
		kind, sub, ok := Classify(e.Tags)
		if !ok {
			continue
		}
		prefix := map[string]string{"node": "n", "way": "w", "relation": "r"}[e.Type]
		if prefix == "" {
			continue
		}
		id := fmt.Sprintf("%s:osm:%s%d", kind, prefix, e.ID)
		if seen[id] {
			continue
		}
		seen[id] = true
		p := Place{ID: id, Kind: kind, Name: strings.TrimSpace(e.Tags["name"]), Subtype: sub, Region: region, Source: "osm"}
		switch {
		case e.Lat != nil && e.Lon != nil:
			p.Lat, p.Lon = e.Lat, e.Lon
		case e.Center != nil:
			lat, lon := e.Center.Lat, e.Center.Lon
			p.Lat, p.Lon = &lat, &lon
		}
		out = append(out, p)
	}
	return out, nil
}

var (
	poiAmenity = set("bar", "pub", "cafe", "library", "nightclub", "restaurant", "cinema", "theatre", "arts_centre", "community_centre", "biergarten")
	poiLeisure = set("fitness_centre", "sports_centre", "swimming_pool", "dog_park", "track", "climbing", "ice_rink", "bowling_alley")
	eduAmenity = set("university", "college") // VŠ and VOŠ only; never school/kindergarten
	// Sensitive places: never in the catalog.
	deniedAmenity = set("hospital", "clinic", "doctors", "dentist", "pharmacy", "social_facility",
		"school", "kindergarten", "childcare", "prison", "place_of_worship", "shelter", "police")
	deniedBuilding = set("residential", "house", "apartments", "detached", "semidetached_house",
		"terrace", "bungalow", "dormitory", "hospital", "school", "kindergarten")
)

// Classify maps OSM tags to a catalog kind, or ok=false if excluded.
func Classify(tags map[string]string) (kind places.Kind, subtype string, ok bool) {
	if strings.TrimSpace(tags["name"]) == "" {
		return "", "", false
	}
	if deniedAmenity[tags["amenity"]] || deniedBuilding[tags["building"]] ||
		tags["healthcare"] != "" || tags["landuse"] == "residential" || tags["access"] == "private" {
		return "", "", false
	}
	switch a := tags["amenity"]; {
	case eduAmenity[a]:
		return places.KindEdu, a, true
	case poiAmenity[a]:
		return places.KindPOI, a, true
	}
	if l := tags["leisure"]; poiLeisure[l] {
		return places.KindPOI, l, true
	}
	if tags["sport"] == "climbing" {
		return places.KindPOI, "climbing", true
	}
	if tags["building"] == "office" {
		return places.KindOffice, "office", true
	}
	return "", "", false
}

func set(xs ...string) map[string]bool {
	m := make(map[string]bool, len(xs))
	for _, x := range xs {
		m[x] = true
	}
	return m
}

// ReadOSMFile is a convenience for the import command.
func ReadOSMFile(path, region string) ([]Place, error) {
	f, err := os.Open(filepath.Clean(path))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return OSM(f, region)
}
