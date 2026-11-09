#!/bin/bash
# Downloads open data for the Prague place catalog into run/ and imports it.
#   bin/fetch-catalog-praha.sh            # download + dry-run counts
#   bin/fetch-catalog-praha.sh --import   # download + write to ALIENMATCH_DATABASE_URL
# Sources: PID GTFS (CC BY 4.0, data.pid.cz), OpenStreetMap via Overpass (ODbL).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
run="$root/run/catalog"
mkdir -p "$run"
ua="AlienMatch-catalog/0.1"

curl -fsSL -A "$ua" -o "$run/pid-gtfs.zip" https://data.pid.cz/PID_GTFS.zip

# Only allowed categories; health, residential and schools are never queried.
# Bounding box of Prague (area lookups are missing on some mirrors).
cat >"$run/praha.overpass" <<'Q'
[out:json][timeout:180][bbox:49.94,14.22,50.18,14.71];
(
  nwr["name"]["amenity"~"^(bar|pub|cafe|library|nightclub|restaurant|cinema|theatre|arts_centre|community_centre|biergarten|university|college)$"];
  nwr["name"]["leisure"~"^(fitness_centre|sports_centre|swimming_pool|dog_park|track|climbing|ice_rink|bowling_alley)$"];
  nwr["name"]["sport"="climbing"];
  nwr["name"]["building"="office"];
);
out center tags;
Q
ok=
for ep in https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter https://overpass.private.coffee/api/interpreter; do
  # Mirrors without area data answer with zero elements; treat that as a failure too.
  if curl -fsSL -A "$ua" --retry 2 --max-time 300 --data-urlencode "data@$run/praha.overpass" -o "$run/praha-osm.json" "$ep" \
    && grep -q '"type"' "$run/praha-osm.json"; then ok=1; break; fi
  echo "overpass $ep failed, trying next" >&2
done
[ -n "$ok" ] || { echo "all Overpass endpoints failed" >&2; exit 1; }

mode=(-dry-run)
[ "${1:-}" = "--import" ] && mode=()
cd "$root/backend"
# PID zones P, 0 and B are Prague; the rest of the PID network is Středočeský kraj.
go run ./cmd/places-import -region CZ-STC -zone-regions P=CZ-PHA,0=CZ-PHA,B=CZ-PHA -gtfs "$run/pid-gtfs.zip" -feed pid "${mode[@]}"
go run ./cmd/places-import -region CZ-PHA -osm "$run/praha-osm.json" "${mode[@]}"
