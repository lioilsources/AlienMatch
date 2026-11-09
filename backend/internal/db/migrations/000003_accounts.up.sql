-- Anonymous accounts: no e-mail, no phone. The app holds a random token;
-- the server stores only its SHA-256. Apple/Google sign-in for recovery later.
ALTER TABLE users ADD COLUMN token_hash bytea UNIQUE CHECK (length(token_hash) = 32);

-- The profile is filled in onboarding before the live photo is taken.
ALTER TABLE profiles ALTER COLUMN photo_key DROP NOT NULL;

-- Self-score-only check-in: the user switched VL off ("no signal" profile).
ALTER TYPE checkin_mode ADD VALUE IF NOT EXISTS 'self';
