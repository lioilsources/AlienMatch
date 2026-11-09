-- name: InsertCheckin :one
INSERT INTO checkins (user_id, at, self_score, vl_energy, vl_valence, vl_confidence, mood, disagreement)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING id;

-- name: RecentCheckins :many
SELECT at, mood, COALESCE(vl_valence, mood)::real AS valence
FROM checkins
WHERE user_id = $1
ORDER BY at DESC
LIMIT $2;

-- name: UpsertMoodState :exec
INSERT INTO mood_state (user_id, level, trend, mood, last_checkin_at, support_pause, computed_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (user_id) DO UPDATE SET
    level = EXCLUDED.level,
    trend = EXCLUDED.trend,
    mood = EXCLUDED.mood,
    last_checkin_at = EXCLUDED.last_checkin_at,
    support_pause = EXCLUDED.support_pause,
    computed_at = EXCLUDED.computed_at;

-- name: UserWeights :one
SELECT vl_enabled, w_self, w_vl FROM users WHERE id = $1 AND deleted_at IS NULL;
