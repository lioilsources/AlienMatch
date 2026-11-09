-- name: MatchingPool :many
-- Fresh profiles in one region; freshness cutoff is passed in (now - 36h).
SELECT p.user_id, p.generation, p.status, p.region,
       p.seek_generations::text[] AS seek_generations, p.seek_statuses::text[] AS seek_statuses, p.can_be_beacon, p.wants_encouragement, p.beacon_only,
       s.level, s.trend, s.mood, s.last_checkin_at, s.support_pause,
       COALESCE(array_agg(t.tag) FILTER (WHERE t.tag IS NOT NULL), '{}')::text[] AS intents
FROM profiles p
JOIN users u ON u.id = p.user_id AND u.deleted_at IS NULL
JOIN mood_state s ON s.user_id = p.user_id
LEFT JOIN profile_tags t ON t.user_id = p.user_id
WHERE p.region = $1 AND s.last_checkin_at > $2
GROUP BY p.user_id, s.user_id;

-- name: CreateMatch :one
-- matches_guard trigger enforces LOW x LOW = never.
INSERT INTO matches (user_a, user_b, kind)
VALUES (LEAST(@x::uuid, @y::uuid), GREATEST(@x::uuid, @y::uuid), @kind)
RETURNING id;

-- name: InsertWave :exec
INSERT INTO waves (from_user, to_user, sticker_id) VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING;

-- name: IsMutualWave :one
SELECT EXISTS (SELECT 1 FROM waves w WHERE w.from_user = $2 AND w.to_user = $1);

-- name: ProfileRegion :one
SELECT region FROM profiles WHERE user_id = $1;
