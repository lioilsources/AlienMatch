-- Star ratings: the brightest stars on my radar can be rated per face
-- (photo_key), so their owner sees how each profile photo lands. A rating is
-- like (+1), dislike (-1) or seen-and-skipped (0). Never a match signal.
CREATE TABLE face_ratings (
    rater_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    photo_key             text NOT NULL,
    value                 smallint NOT NULL CHECK (value IN (-1, 0, 1)),
    updated_at            timestamptz NOT NULL,
    PRIMARY KEY (rater_id, photo_key),
    CHECK (rater_id <> target_id)
);
CREATE INDEX face_ratings_target ON face_ratings (target_id, photo_key);
CREATE INDEX face_ratings_rater_value ON face_ratings (rater_id, value, updated_at DESC);
