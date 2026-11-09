-- Places without tracking (Prompts/01-GPS.md).
-- Hard rule: user coordinates never exist in this database. lat/lon live only in
-- the public `places` catalog (OSM/GTFS data). An integration test audits this.

CREATE TYPE place_kind AS ENUM ('stop', 'route', 'poi', 'edu', 'office', 'partner', 'event');
CREATE TYPE encounter_kind AS ENUM ('vehicle', 'stop', 'venue');

-- Public catalog (layer A). Open data: OSM (ODbL) and GTFS (CC BY 4.0).
CREATE TABLE places (
    place_id              text PRIMARY KEY,               -- e.g. stop:pid:U1040Z1, route:pid:22, poi:osm:n123
    kind                  place_kind NOT NULL,
    name                  text NOT NULL,
    name_search           text NOT NULL,                  -- lower-case, diacritics stripped (Go side)
    subtype               text NOT NULL DEFAULT '',       -- tram, bus, cafe, fitness_centre, ...
    lat                   double precision,               -- catalog only, never a user
    lon                   double precision,
    region                text NOT NULL,
    source                text NOT NULL,                  -- gtfs:pid, osm, curated
    partner_id            bigint,
    expires_at            timestamptz,                    -- events: 48 h
    CHECK (place_id LIKE kind::text || ':%')
);
CREATE INDEX places_region_kind ON places (region, kind);

-- A user's constellation: up to 8 places, chosen by hand. No visit timestamps.
CREATE TABLE profile_places (
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id              text NOT NULL REFERENCES places(place_id) ON DELETE CASCADE,
    added_at              timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, place_id)
);
CREATE INDEX profile_places_place ON profile_places (place_id);

CREATE FUNCTION profile_places_limit() RETURNS trigger AS $$
BEGIN
    IF (SELECT count(*) FROM profile_places WHERE user_id = NEW.user_id) >= 8 THEN
        RAISE EXCEPTION 'alienmatch: at most 8 places per profile' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profile_places_limit
    BEFORE INSERT ON profile_places
    FOR EACH ROW EXECUTE FUNCTION profile_places_limit();

-- Materialised member counts for k-anonymity (k >= 5). Never shown to users.
CREATE TABLE place_counts (
    place_id              text PRIMARY KEY REFERENCES places(place_id) ON DELETE CASCADE,
    region                text NOT NULL,
    active_count          integer NOT NULL,
    computed_at           timestamptz NOT NULL
);

-- Layer B (BLE "fly-by"): yesterday's temporary exposure key, kept 14 days.
CREATE TABLE tek_uploads (
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day                   date NOT NULL,
    tek                   bytea NOT NULL CHECK (length(tek) = 16),
    region                text NOT NULL,
    PRIMARY KEY (user_id, day)
);
CREATE INDEX tek_uploads_region_day ON tek_uploads (region, day);

-- Layer B: "X and Y were together for a while on day D". A day, never a time or a place.
CREATE TABLE encounters (
    id                    bigserial PRIMARY KEY,
    user_a                uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b                uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind                  encounter_kind NOT NULL,
    day                   date NOT NULL,
    a_waved               boolean NOT NULL DEFAULT false,
    b_waved               boolean NOT NULL DEFAULT false,
    CHECK (user_a < user_b),
    UNIQUE (user_a, user_b, day)
);

-- Layer C: optional "I'm here" at a partner venue, 6 hours.
CREATE TABLE venue_checkins (
    user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id              text NOT NULL REFERENCES places(place_id) ON DELETE CASCADE,
    hour_bucket           timestamptz NOT NULL CHECK (date_trunc('hour', hour_bucket) = hour_bucket),
    expires_at            timestamptz NOT NULL,
    PRIMARY KEY (user_id, place_id)
);

CREATE TABLE partners (
    partner_id            bigserial PRIMARY KEY,
    place_id              text NOT NULL UNIQUE REFERENCES places(place_id),
    beacon_major          integer NOT NULL,
    beacon_minor          integer NOT NULL,
    plan                  text NOT NULL,
    since                 date NOT NULL,
    UNIQUE (beacon_major, beacon_minor)
);
