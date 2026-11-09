-- name: CreateAccount :one
INSERT INTO users (adult_confirmed_at, special_consent_at, vl_enabled, token_hash)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- name: UserByTokenHash :one
SELECT id FROM users WHERE token_hash = $1 AND deleted_at IS NULL;

-- name: Me :one
SELECT u.id AS user_id, (u.special_consent_at IS NOT NULL)::bool AS mood_consent, u.vl_enabled,
       (p.user_id IS NOT NULL)::bool AS has_profile,
       COALESCE(p.nickname, '')::text AS nickname, (p.photo_key IS NOT NULL)::bool AS has_photo,
       COALESCE(p.generation::text, '')::text AS generation, COALESCE(p.status::text, '')::text AS status,
       p.kids_count, COALESCE(p.kids_flags, '{}')::text[] AS kids_flags, COALESCE(p.region, '')::text AS region,
       COALESCE(p.seek_generations::text[], '{}')::text[] AS seek_generations,
       COALESCE(p.seek_statuses::text[], '{}')::text[] AS seek_statuses,
       COALESCE(p.can_be_beacon, false)::bool AS can_be_beacon,
       COALESCE(p.wants_encouragement, false)::bool AS wants_encouragement,
       COALESCE(p.beacon_only, false)::bool AS beacon_only,
       ARRAY(SELECT t.tag FROM profile_tags t WHERE t.user_id = u.id ORDER BY t.tag)::text[] AS intents
FROM users u LEFT JOIN profiles p ON p.user_id = u.id
WHERE u.id = $1 AND u.deleted_at IS NULL;

-- name: UpsertProfile :exec
INSERT INTO profiles (user_id, nickname, generation, status, kids_count, kids_flags, region,
                      seek_generations, seek_statuses, can_be_beacon, wants_encouragement, beacon_only, updated_at)
VALUES (sqlc.arg(user_id), sqlc.narg(nickname), sqlc.arg(generation), sqlc.arg(status), sqlc.narg(kids_count), sqlc.arg(kids_flags)::text[], sqlc.arg(region), CAST(sqlc.arg(seek_generations)::text[] AS generation[]), CAST(sqlc.arg(seek_statuses)::text[] AS rel_status[]), sqlc.arg(can_be_beacon), sqlc.arg(wants_encouragement), sqlc.arg(beacon_only), sqlc.arg(now))
ON CONFLICT (user_id) DO UPDATE SET
    nickname = EXCLUDED.nickname, generation = EXCLUDED.generation, status = EXCLUDED.status,
    kids_count = EXCLUDED.kids_count, kids_flags = EXCLUDED.kids_flags, region = EXCLUDED.region,
    seek_generations = EXCLUDED.seek_generations, seek_statuses = EXCLUDED.seek_statuses,
    can_be_beacon = EXCLUDED.can_be_beacon, wants_encouragement = EXCLUDED.wants_encouragement,
    beacon_only = EXCLUDED.beacon_only, updated_at = EXCLUDED.updated_at;

-- name: ClearTags :exec
DELETE FROM profile_tags WHERE user_id = $1;

-- name: AddTag :exec
INSERT INTO profile_tags (user_id, tag) VALUES ($1, $2);

-- name: SwapPhoto :one
-- Returns the previous key so the caller can delete the old file.
WITH old AS (SELECT photo_key FROM profiles WHERE user_id = @user_id FOR UPDATE)
UPDATE profiles p SET photo_key = @photo_key, updated_at = @now
FROM old WHERE p.user_id = @user_id
RETURNING COALESCE(old.photo_key, '')::text AS previous;

-- name: PhotoKey :one
SELECT COALESCE(photo_key, '')::text FROM profiles WHERE user_id = $1;

-- name: DeleteAccount :one
-- Hard delete; all user rows cascade. Returns the photo key for media cleanup.
WITH p AS (SELECT COALESCE(photo_key, '')::text AS k FROM profiles WHERE user_id = $1)
DELETE FROM users u WHERE u.id = $1
RETURNING COALESCE((SELECT k FROM p), '')::text AS photo_key;
