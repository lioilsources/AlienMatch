-- MIMO core schema. Deployed migrations are immutable: add a new file instead.
-- Privacy: check-ins keep scores only; no video, audio or raw frames are ever stored.

CREATE TYPE mood_level AS ENUM ('LOW', 'MID', 'HIGH');
CREATE TYPE mood_trend AS ENUM ('RISING', 'FLAT', 'FALLING');
CREATE TYPE generation AS ENUM ('genz', 'millennial', 'genx', 'boomer');
CREATE TYPE rel_status AS ENUM ('single', 'married', 'divorced', 'complicated');
CREATE TYPE match_kind AS ENUM ('match', 'encourage');

CREATE TABLE users (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at            timestamptz NOT NULL DEFAULT now(),
    adult_confirmed_at    timestamptz NOT NULL,          -- 18+ checkbox (store requirement), no birth date
    special_consent_at    timestamptz,                   -- GDPR art. 9 consent for mood scoring; NULL = self-score only
    vl_enabled            boolean NOT NULL DEFAULT true, -- user can switch VL scoring off at any time
    w_self                real NOT NULL DEFAULT 0.6,
    w_vl                  real NOT NULL DEFAULT 0.4,
    checkin_local_time    time,                          -- one push per day max
    deleted_at            timestamptz
);

CREATE TABLE profiles (
    user_id               uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    nickname              varchar(12),                   -- only free text in the product; moderated
    photo_key             text NOT NULL,                 -- MinIO key of the chosen mirror variant (WebP <= 1024 px)
    generation            generation NOT NULL,
    status                rel_status NOT NULL,
    kids_count            smallint CHECK (kids_count BETWEEN 0 AND 5),
    kids_flags            text[] NOT NULL DEFAULT '{}',  -- boys/girls/twins/triplets
    region                text NOT NULL,                 -- coarse district/region code, never GPS
    seek_generations      generation[] NOT NULL DEFAULT '{}',
    seek_statuses         rel_status[] NOT NULL DEFAULT '{}',
    can_be_beacon         boolean NOT NULL DEFAULT false,
    wants_encouragement   boolean NOT NULL DEFAULT false,
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE profile_tags (
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tag                   text NOT NULL,                 -- intent sticker id: flirt, sex, chat, coffee, ...
    PRIMARY KEY (user_id, tag)
);

CREATE TABLE checkins (
    id                    bigserial PRIMARY KEY,
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    at                    timestamptz NOT NULL,
    self_score            real NOT NULL CHECK (self_score BETWEEN 0 AND 1),
    vl_energy             real CHECK (vl_energy BETWEEN 0 AND 1),
    vl_valence            real CHECK (vl_valence BETWEEN 0 AND 1),
    vl_confidence         real CHECK (vl_confidence BETWEEN 0 AND 1),
    mood                  real NOT NULL CHECK (mood BETWEEN 0 AND 1),
    disagreement          boolean NOT NULL DEFAULT false
);
CREATE INDEX checkins_user_at ON checkins (user_id, at DESC);

CREATE TABLE mood_state (
    user_id               uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    level                 mood_level NOT NULL,
    trend                 mood_trend NOT NULL,
    mood                  real NOT NULL,
    last_checkin_at       timestamptz NOT NULL,
    support_pause         boolean NOT NULL DEFAULT false,
    computed_at           timestamptz NOT NULL
);

CREATE TABLE waves (
    from_user             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sticker_id            bigint,
    created_at            timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (from_user, to_user),
    CHECK (from_user <> to_user)
);

CREATE TABLE matches (
    id                    bigserial PRIMARY KEY,
    user_a                uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b                uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind                  match_kind NOT NULL,
    created_at            timestamptz NOT NULL DEFAULT now(),
    ended_at              timestamptz,
    CHECK (user_a < user_b),
    UNIQUE (user_a, user_b)
);

-- Hard safety rule, enforced in the database so no code path (or manual SQL)
-- can create it: two LOW users are never connected; a LOW user never gets a
-- romantic match; encouragement needs a HIGH beacon and both opt-ins.
CREATE FUNCTION matches_guard() RETURNS trigger AS $$
DECLARE
    la mood_level;
    lb mood_level;
    pa profiles%ROWTYPE;
    pb profiles%ROWTYPE;
BEGIN
    SELECT level INTO la FROM mood_state WHERE user_id = NEW.user_a;
    SELECT level INTO lb FROM mood_state WHERE user_id = NEW.user_b;
    IF la IS NULL OR lb IS NULL THEN
        RAISE EXCEPTION 'mimo: match needs mood state for both users' USING ERRCODE = 'check_violation';
    END IF;
    IF la = 'LOW' AND lb = 'LOW' THEN
        RAISE EXCEPTION 'mimo: LOW x LOW is never allowed' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.kind = 'match' AND (la = 'LOW' OR lb = 'LOW') THEN
        RAISE EXCEPTION 'mimo: LOW user cannot get a romantic match' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.kind = 'encourage' THEN
        SELECT * INTO pa FROM profiles WHERE user_id = NEW.user_a;
        SELECT * INTO pb FROM profiles WHERE user_id = NEW.user_b;
        IF NOT (
            (la = 'HIGH' AND lb = 'LOW' AND pa.can_be_beacon AND pb.wants_encouragement) OR
            (lb = 'HIGH' AND la = 'LOW' AND pb.can_be_beacon AND pa.wants_encouragement)
        ) THEN
            RAISE EXCEPTION 'mimo: encouragement needs HIGH beacon x LOW seeker with both opt-ins' USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER matches_guard
    BEFORE INSERT OR UPDATE OF user_a, user_b, kind ON matches
    FOR EACH ROW EXECUTE FUNCTION matches_guard();

CREATE TABLE walls (
    id                    bigserial PRIMARY KEY,
    match_id              bigint NOT NULL UNIQUE REFERENCES matches(id) ON DELETE CASCADE,
    gentle                boolean NOT NULL DEFAULT false, -- encouragement visual
    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE stickers (
    id                    bigserial PRIMARY KEY,
    wall_id               bigint NOT NULL REFERENCES walls(id) ON DELETE CASCADE,
    author_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_id             uuid NOT NULL,                  -- idempotency for the offline queue
    media_key             text NOT NULL,                  -- MinIO key (SVG/WebP), never text
    x                     real NOT NULL,
    y                     real NOT NULL,
    rotation              real NOT NULL DEFAULT 0,
    scale                 real NOT NULL DEFAULT 1,
    z                     integer NOT NULL DEFAULT 0,
    moderation            text NOT NULL DEFAULT 'pending' CHECK (moderation IN ('pending', 'ok', 'hidden', 'review')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    removed_at            timestamptz,
    UNIQUE (author_id, client_id)
);
CREATE INDEX stickers_wall ON stickers (wall_id, z);

CREATE TABLE reports (
    id                    bigserial PRIMARY KEY,
    reporter_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user           uuid REFERENCES users(id) ON DELETE CASCADE,
    sticker_id            bigint REFERENCES stickers(id) ON DELETE CASCADE,
    block                 boolean NOT NULL DEFAULT false,
    created_at            timestamptz NOT NULL DEFAULT now(),
    resolved_at           timestamptz
);

CREATE TABLE entitlements (
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product               text NOT NULL,                 -- signal_plus, pack:<id>, gift:<id>, flare
    source                text NOT NULL,                 -- apple, google, ol1n_pass
    expires_at            timestamptz,                   -- NULL = lifetime
    remaining             integer,                       -- consumables
    PRIMARY KEY (user_id, product, source)
);

CREATE TABLE iap_receipts (
    id                    bigserial PRIMARY KEY,
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    store                 text NOT NULL CHECK (store IN ('apple', 'google')),
    transaction_id        text NOT NULL UNIQUE,
    product               text NOT NULL,
    verified_at           timestamptz NOT NULL,
    raw                   jsonb NOT NULL
);
