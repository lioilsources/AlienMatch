ALTER TABLE profiles ALTER COLUMN photo_key SET NOT NULL;
ALTER TABLE users DROP COLUMN IF EXISTS token_hash;
-- Postgres cannot drop an enum value; 'self' stays.
