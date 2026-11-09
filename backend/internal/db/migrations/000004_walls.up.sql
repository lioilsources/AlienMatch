-- Walls: handwritten stickers are stored as vector ink (strokes), presets
-- are image stickers by id. Neither is text.
ALTER TABLE stickers
    ADD COLUMN kind text NOT NULL DEFAULT 'ink' CHECK (kind IN ('ink', 'preset', 'gift')),
    ADD COLUMN ink jsonb,
    ALTER COLUMN media_key DROP NOT NULL,
    ADD CONSTRAINT stickers_payload CHECK (
        (kind = 'ink' AND ink IS NOT NULL) OR (kind <> 'ink' AND media_key IS NOT NULL)
    );
-- Until the VL moderation worker exists, stickers are delivered right away;
-- a report hides them at once ('review').
ALTER TABLE stickers ALTER COLUMN moderation SET DEFAULT 'ok';

CREATE TABLE blocks (
    blocker               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at            timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker, blocked),
    CHECK (blocker <> blocked)
);
CREATE INDEX blocks_blocked ON blocks (blocked);
CREATE INDEX waves_to ON waves (to_user);
CREATE INDEX waves_from_created ON waves (from_user, created_at);
