-- name: UpsertPlace :exec
INSERT INTO places (place_id, kind, name, name_search, subtype, lat, lon, region, source, expires_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
ON CONFLICT (place_id) DO UPDATE SET
    kind = EXCLUDED.kind, name = EXCLUDED.name, name_search = EXCLUDED.name_search,
    subtype = EXCLUDED.subtype, lat = EXCLUDED.lat, lon = EXCLUDED.lon,
    region = EXCLUDED.region, source = EXCLUDED.source, expires_at = EXCLUDED.expires_at;

-- name: SearchPlaces :many
SELECT place_id, kind, name, subtype, lat, lon
FROM places
WHERE region = @region
  AND name_search LIKE '%' || @q::text || '%'
  AND (expires_at IS NULL OR expires_at > @now)
ORDER BY (name_search LIKE @q::text || '%') DESC, length(name), place_id
LIMIT @lim;

-- name: ExistingPlaces :many
SELECT place_id FROM places
WHERE place_id = ANY(@ids::text[]) AND (expires_at IS NULL OR expires_at > @now);

-- name: ClearProfilePlaces :exec
DELETE FROM profile_places WHERE user_id = $1;

-- name: AddProfilePlace :exec
INSERT INTO profile_places (user_id, place_id, added_at) VALUES ($1, $2, $3);

-- name: ProfilePlaces :many
SELECT p.place_id, p.kind, p.name, p.subtype
FROM profile_places pp JOIN places p ON p.place_id = pp.place_id
WHERE pp.user_id = $1
ORDER BY pp.added_at, p.place_id;

-- name: PlaceCounts :many
SELECT place_id, active_count FROM place_counts WHERE place_id = ANY(@ids::text[]);

-- name: RefreshPlaceCounts :exec
-- Active member = not deleted and checked in within the freshness window.
WITH c AS (
    SELECT pp.place_id, p.region, count(*)::int AS n
    FROM profile_places pp
    JOIN places p ON p.place_id = pp.place_id
    JOIN users u ON u.id = pp.user_id AND u.deleted_at IS NULL
    JOIN mood_state s ON s.user_id = pp.user_id AND s.last_checkin_at > @fresh_after
    GROUP BY pp.place_id, p.region
), del AS (
    DELETE FROM place_counts pc WHERE NOT EXISTS (SELECT 1 FROM c WHERE c.place_id = pc.place_id)
)
INSERT INTO place_counts (place_id, region, active_count, computed_at)
SELECT place_id, region, n, @now FROM c
ON CONFLICT (place_id) DO UPDATE SET
    region = EXCLUDED.region, active_count = EXCLUDED.active_count, computed_at = EXCLUDED.computed_at;

-- name: PurgeExpiredTEK :execrows
DELETE FROM tek_uploads WHERE day < @cutoff::date;

-- name: PurgeExpiredEncounters :execrows
DELETE FROM encounters WHERE day < @cutoff::date;

-- name: PurgeExpiredVenueCheckins :execrows
DELETE FROM venue_checkins WHERE expires_at <= @now;

-- name: PurgeExpiredEvents :execrows
DELETE FROM places WHERE kind = 'event' AND expires_at <= @now;

-- name: ActiveTEKCount :one
SELECT count(*)::int FROM tek_uploads WHERE user_id = $1;

-- name: ActiveVenueCheckins :many
SELECT place_id FROM venue_checkins WHERE user_id = $1 AND expires_at > @now;
