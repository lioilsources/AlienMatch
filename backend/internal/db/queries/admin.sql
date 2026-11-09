-- name: OpenReports :many
SELECT r.id, r.created_at, r.block, r.reporter_id,
       r.target_user, r.sticker_id,
       COALESCE(s.kind, '')::text AS sticker_kind, COALESCE(s.media_key, '')::text AS sticker_media,
       s.ink AS sticker_ink, COALESCE(s.moderation, '')::text AS sticker_moderation,
       s.author_id AS sticker_author
FROM reports r LEFT JOIN stickers s ON s.id = r.sticker_id
WHERE r.resolved_at IS NULL
ORDER BY r.created_at
LIMIT @lim;

-- name: ReportSticker :one
SELECT sticker_id FROM reports WHERE id = $1 AND resolved_at IS NULL;

-- name: ResolveReport :exec
UPDATE reports SET resolved_at = @now WHERE id = @id;

-- name: SetModeration :exec
UPDATE stickers SET moderation = @moderation WHERE id = @id;

-- name: RemoveSticker :exec
UPDATE stickers SET moderation = 'hidden', removed_at = @now WHERE id = @id;
