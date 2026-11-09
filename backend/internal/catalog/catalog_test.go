package catalog

import (
	"strings"
	"testing"
	"testing/fstest"

	"github.com/lioilsources/AlienMatch/backend/internal/places"
)

func TestGTFSFoldsPlatformsIntoStations(t *testing.T) {
	fsys := fstest.MapFS{
		"stops.txt": {Data: []byte("\ufeffstop_id,stop_name,stop_lat,stop_lon,location_type,parent_station\n" +
			"U1040S1,Anděl,50.07,14.40,1,\n" +
			"U1040Z101P,Anděl,50.07,14.40,0,U1040S1\n" +
			"U1040Z1,Anděl,50.071,14.403,0,\n" +
			"U1040E1,Anděl vstup,50.07,14.40,2,U1040S1\n")},
		"routes.txt": {Data: []byte("route_id,route_short_name,route_long_name,route_type\n" +
			"L22,22,Bílá Hora - Nádraží Hostivař,0\n" +
			"L991,,Metro B,1\n")},
	}
	got, err := GTFS(fsys, GTFSOptions{Feed: "pid", Region: "CZ-PHA"})
	if err != nil {
		t.Fatal(err)
	}
	ids := map[string]Place{}
	for _, p := range got {
		ids[p.ID] = p
	}
	for _, want := range []string{"stop:pid:U1040S1", "stop:pid:U1040Z1", "route:pid:L22", "route:pid:L991"} {
		if _, ok := ids[want]; !ok {
			t.Errorf("missing %s in %v", want, got)
		}
	}
	if len(got) != 4 {
		t.Errorf("got %d places, want 4 (platform with parent and entrance dropped)", len(got))
	}
	if r := ids["route:pid:L22"]; r.Subtype != "tram" || r.Lat != nil {
		t.Errorf("route = %+v", r)
	}
	if r := ids["route:pid:L991"]; r.Name != "Metro B" || r.Subtype != "metro" {
		t.Errorf("long-name fallback = %+v", r)
	}
	if s := ids["stop:pid:U1040Z1"]; s.Lat == nil || *s.Lat != 50.071 {
		t.Errorf("stop coords = %+v", s)
	}
}

func TestClassifyExclusions(t *testing.T) {
	cases := []struct {
		tags map[string]string
		kind places.Kind
		ok   bool
	}{
		{map[string]string{"name": "Kavárna", "amenity": "cafe"}, places.KindPOI, true},
		{map[string]string{"name": "ČVUT FEL", "amenity": "university"}, places.KindEdu, true},
		{map[string]string{"name": "VOŠ", "amenity": "college"}, places.KindEdu, true},
		{map[string]string{"name": "Rustonka", "building": "office"}, places.KindOffice, true},
		{map[string]string{"name": "Gym", "leisure": "fitness_centre"}, places.KindPOI, true},
		{map[string]string{"name": "Stěna", "sport": "climbing"}, places.KindPOI, true},
		// never in the catalog
		{map[string]string{"name": "ZŠ", "amenity": "school"}, "", false},
		{map[string]string{"name": "Gymnázium", "amenity": "school", "building": "school"}, "", false},
		{map[string]string{"name": "Nemocnice", "amenity": "hospital"}, "", false},
		{map[string]string{"name": "Ordinace", "amenity": "doctors"}, "", false},
		{map[string]string{"name": "Kavárna v poliklinice", "amenity": "cafe", "healthcare": "centre"}, "", false},
		{map[string]string{"name": "Dům", "building": "residential"}, "", false},
		{map[string]string{"name": "Bar u domu", "amenity": "bar", "building": "apartments"}, "", false},
		{map[string]string{"amenity": "cafe"}, "", false},
		{map[string]string{"name": "Klub", "amenity": "bar", "access": "private"}, "", false},
	}
	for _, c := range cases {
		k, _, ok := Classify(c.tags)
		if ok != c.ok || k != c.kind {
			t.Errorf("Classify(%v) = %v,%v want %v,%v", c.tags, k, ok, c.kind, c.ok)
		}
	}
}

func TestOSMOverpassJSON(t *testing.T) {
	js := `{"elements":[
	 {"type":"node","id":1,"lat":50.1,"lon":14.4,"tags":{"name":"U Chřestýše","amenity":"pub"}},
	 {"type":"way","id":2,"center":{"lat":50.2,"lon":14.5},"tags":{"name":"ČVUT","amenity":"university"}},
	 {"type":"way","id":3,"center":{"lat":50.2,"lon":14.5},"tags":{"name":"Panelák","building":"apartments"}},
	 {"type":"node","id":1,"lat":50.1,"lon":14.4,"tags":{"name":"U Chřestýše","amenity":"pub"}}
	]}`
	got, err := OSM(strings.NewReader(js), "CZ-PHA")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].ID != "poi:osm:n1" || got[1].ID != "edu:osm:w2" || *got[1].Lat != 50.2 {
		t.Fatalf("got %+v", got)
	}
}

func TestGTFSFoldsPIDNodesAndMapsZones(t *testing.T) {
	fsys := fstest.MapFS{
		"stops.txt": {Data: []byte("stop_id,stop_name,stop_lat,stop_lon,zone_id,location_type,parent_station,asw_node_id\n" +
			"U1Z1P,Boletická,50.10,14.50,P,0,,1\n" +
			"U1Z2P,Boletická,50.12,14.52,P,0,,1\n" +
			"U9Z1P,Kladno,50.14,14.10,\"5,6\",0,,9\n")},
		"routes.txt": {Data: []byte("route_id,route_short_name,route_type\n")},
	}
	zones, err := ParseZoneRegions("P=CZ-PHA, 0=CZ-PHA,B=CZ-PHA")
	if err != nil {
		t.Fatal(err)
	}
	got, err := GTFS(fsys, GTFSOptions{Feed: "pid", Region: "CZ-STC", ZoneRegions: zones})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("got %+v, want 2 nodes", got)
	}
	b := got[0]
	if b.ID != "stop:pid:N1" || b.Region != "CZ-PHA" || *b.Lat < 50.109 || *b.Lat > 50.111 {
		t.Errorf("folded node = %+v lat=%v", b, *b.Lat)
	}
	if got[1].ID != "stop:pid:N9" || got[1].Region != "CZ-STC" {
		t.Errorf("outer zone = %+v", got[1])
	}
	if _, err := ParseZoneRegions("P"); err == nil {
		t.Error("bad pair accepted")
	}
}
