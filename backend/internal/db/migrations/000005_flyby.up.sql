-- Layer B "fly-by" (Prompts/01-GPS.md): BLE proximity without any location.
-- Opt-in, default off. Turning it off deletes the user's keys and encounters.
ALTER TABLE users ADD COLUMN flyby_enabled boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX tek_uploads_tek_day ON tek_uploads (tek, day);
