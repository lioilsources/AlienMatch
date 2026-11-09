-- name: SetFlyby :exec
UPDATE users SET flyby_enabled = @enabled WHERE id = @id;

-- name: FlybyEnabled :one
SELECT flyby_enabled FROM users WHERE id = $1 AND deleted_at IS NULL;

-- name: WipeFlyby :exec
WITH t AS (DELETE FROM tek_uploads WHERE user_id = @id)
DELETE FROM encounters WHERE user_a = @id OR user_b = @id;

-- name: InsertTEK :execrows
INSERT INTO tek_uploads (user_id, day, tek, region) VALUES ($1, $2, $3, $4)
ON CONFLICT DO NOTHING;

-- name: RegionTEKs :many
-- Keys of other opted-in users in my region; the client matches them locally.
SELECT t.day, t.tek FROM tek_uploads t JOIN users u ON u.id = t.user_id AND u.flyby_enabled AND u.deleted_at IS NULL
WHERE t.region = @region AND t.day >= @since::date AND t.user_id <> @me
ORDER BY t.day, t.tek;

-- name: OwnerOfTEK :one
SELECT t.user_id FROM tek_uploads t JOIN users u ON u.id = t.user_id AND u.flyby_enabled AND u.deleted_at IS NULL
WHERE t.tek = $1 AND t.day = $2;

-- name: HasTEKSince :one
SELECT EXISTS (SELECT 1 FROM tek_uploads WHERE user_id = $1 AND day >= $2::date)::bool;

-- name: WaveEncounter :exec
-- One row per pair and day; each side's wave is recorded separately.
INSERT INTO encounters (user_a, user_b, kind, day, a_waved, b_waved)
VALUES (LEAST(@me::uuid, @other::uuid), GREATEST(@me::uuid, @other::uuid), @kind, @day,
        @me::uuid < @other::uuid, @me::uuid > @other::uuid)
ON CONFLICT (user_a, user_b, day) DO UPDATE SET
    a_waved = encounters.a_waved OR EXCLUDED.a_waved,
    b_waved = encounters.b_waved OR EXCLUDED.b_waved;

-- name: Comets :many
-- Fly-bys both sides waved at; shown as a comet with the contact type only.
SELECT DISTINCT ON (other) (CASE WHEN user_a = @me::uuid THEN user_b ELSE user_a END)::uuid AS other, kind::text AS kind
FROM encounters
WHERE (user_a = @me::uuid OR user_b = @me::uuid) AND a_waved AND b_waved
ORDER BY other, day DESC;
