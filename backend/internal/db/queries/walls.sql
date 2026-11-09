-- name: CountWavesSince :one
SELECT count(*)::int FROM waves WHERE from_user = $1 AND created_at >= $2;

-- name: AddWave :exec
INSERT INTO waves (from_user, to_user, created_at) VALUES ($1, $2, $3)
ON CONFLICT (from_user, to_user) DO NOTHING;

-- name: HasWave :one
SELECT EXISTS (SELECT 1 FROM waves WHERE from_user = $1 AND to_user = $2)::bool;

-- name: ActiveMatchBetween :one
SELECT m.id, w.id AS wall_id FROM matches m JOIN walls w ON w.match_id = m.id
WHERE m.user_a = LEAST(@x::uuid, @y::uuid) AND m.user_b = GREATEST(@x::uuid, @y::uuid) AND m.ended_at IS NULL;

-- name: CreateWall :one
INSERT INTO walls (match_id, gentle) VALUES ($1, $2) RETURNING id;

-- name: ListMatches :many
SELECT m.id AS match_id, w.id AS wall_id, m.kind::text AS kind, m.created_at,
       (CASE WHEN m.user_a = @me::uuid THEN m.user_b ELSE m.user_a END)::uuid AS other_id,
       COALESCE(p.nickname, '')::text AS other_nickname,
       ARRAY(SELECT pl.name FROM profile_places x
             JOIN profile_places y ON y.place_id = x.place_id AND y.user_id = (CASE WHEN m.user_a = @me::uuid THEN m.user_b ELSE m.user_a END)
             JOIN places pl ON pl.place_id = x.place_id
             WHERE x.user_id = @me::uuid ORDER BY pl.name)::text[] AS shared_places
FROM matches m
JOIN walls w ON w.match_id = m.id
LEFT JOIN profiles p ON p.user_id = (CASE WHEN m.user_a = @me::uuid THEN m.user_b ELSE m.user_a END)
WHERE (m.user_a = @me::uuid OR m.user_b = @me::uuid) AND m.ended_at IS NULL
ORDER BY m.created_at DESC;

-- name: WallMember :one
-- The wall is visible only to its two members while the match is active.
SELECT w.id, w.gentle, (CASE WHEN m.user_a = @me::uuid THEN m.user_b ELSE m.user_a END)::uuid AS other_id
FROM walls w JOIN matches m ON m.id = w.match_id
WHERE w.id = @wall_id AND (m.user_a = @me::uuid OR m.user_b = @me::uuid) AND m.ended_at IS NULL;

-- name: ListStickers :many
SELECT id, author_id, client_id, kind, COALESCE(media_key, '')::text AS media_key, ink, x, y, rotation, scale, z, created_at
FROM stickers
WHERE wall_id = $1 AND removed_at IS NULL AND moderation = 'ok' AND id > $2
ORDER BY id;

-- name: NextZ :one
SELECT (COALESCE(max(z), 0) + 1)::int FROM stickers WHERE wall_id = $1;

-- name: InsertSticker :one
-- Idempotent per (author, client_id): the offline queue may resend.
INSERT INTO stickers (wall_id, author_id, client_id, kind, media_key, ink, x, y, rotation, scale, z, created_at)
VALUES (@wall_id, @author_id, @client_id, @kind, sqlc.narg(media_key), sqlc.narg(ink), @x, @y, @rotation, @scale, @z, @now)
ON CONFLICT (author_id, client_id) DO UPDATE SET author_id = EXCLUDED.author_id
RETURNING id, wall_id, author_id, client_id, kind, COALESCE(media_key, '')::text AS media_key, ink, x, y, rotation, scale, z, created_at;

-- name: MoveSticker :one
UPDATE stickers SET x = @x, y = @y, rotation = @rotation, scale = @scale, z = @z
WHERE id = @id AND wall_id = @wall_id AND author_id = @author_id AND removed_at IS NULL
RETURNING id;

-- name: PeelSticker :one
UPDATE stickers SET removed_at = @now
WHERE id = @id AND wall_id = @wall_id AND author_id = @author_id AND removed_at IS NULL
RETURNING id;

-- name: HideSticker :one
-- Report: hide immediately, queue for manual review.
UPDATE stickers s SET moderation = 'review'
FROM walls w JOIN matches m ON m.id = w.match_id
WHERE s.id = @id AND s.wall_id = w.id AND (m.user_a = @me::uuid OR m.user_b = @me::uuid) AND s.author_id <> @me::uuid
RETURNING s.wall_id;

-- name: InsertReport :exec
INSERT INTO reports (reporter_id, target_user, sticker_id, block, created_at)
VALUES (@reporter_id, sqlc.narg(target_user), sqlc.narg(sticker_id), @block, @now);

-- name: AddBlock :exec
INSERT INTO blocks (blocker, blocked, created_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING;

-- name: EndMatchBetween :many
UPDATE matches SET ended_at = @now
WHERE user_a = LEAST(@x::uuid, @y::uuid) AND user_b = GREATEST(@x::uuid, @y::uuid) AND ended_at IS NULL
RETURNING id;

-- name: RadarExclusions :many
-- People I must not see: blocked either way, or already matched.
SELECT blocked AS other FROM blocks WHERE blocker = @me::uuid
UNION SELECT blocker FROM blocks WHERE blocked = @me::uuid
UNION SELECT CASE WHEN user_a = @me::uuid THEN user_b ELSE user_a END FROM matches
      WHERE (user_a = @me::uuid OR user_b = @me::uuid) AND ended_at IS NULL;

-- name: HasEntitlement :one
SELECT EXISTS (SELECT 1 FROM entitlements WHERE user_id = $1 AND product = $2 AND (expires_at IS NULL OR expires_at > $3))::bool;
