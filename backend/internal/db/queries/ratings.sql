-- name: RateFace :exec
INSERT INTO face_ratings (rater_id, target_id, photo_key, value, updated_at)
VALUES (@rater_id, @target_id, @photo_key, @value, @now)
ON CONFLICT (rater_id, photo_key) DO UPDATE SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at;

-- name: RatingsByRater :many
SELECT photo_key, value FROM face_ratings
WHERE rater_id = @rater_id AND photo_key = ANY(@photo_keys::text[]);

-- name: FaceStats :many
-- Counts per face of one user, newest face first. Raters stay anonymous.
SELECT photo_key,
       count(*) FILTER (WHERE value = 1)::int AS likes,
       count(*) FILTER (WHERE value = -1)::int AS dislikes,
       count(*)::int AS seen,
       min(updated_at)::timestamptz AS first_at
FROM face_ratings
WHERE target_id = $1
GROUP BY photo_key
ORDER BY first_at DESC;

-- name: LikedTargets :many
-- People whose face I liked (any of their faces), latest like first,
-- without anyone blocked either way.
SELECT target_id, max(updated_at)::timestamptz AS at
FROM face_ratings r
WHERE r.rater_id = @me::uuid AND r.value = 1
  AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker = @me::uuid AND b.blocked = r.target_id)
                                          OR (b.blocked = @me::uuid AND b.blocker = r.target_id))
GROUP BY target_id
ORDER BY at DESC
LIMIT 200;

-- name: OwnLevel :one
SELECT level::text FROM mood_state WHERE user_id = $1;
