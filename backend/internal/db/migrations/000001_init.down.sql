DROP TABLE IF EXISTS iap_receipts, entitlements, reports, stickers, walls, matches, waves,
    mood_state, checkins, profile_tags, profiles, users CASCADE;
DROP FUNCTION IF EXISTS matches_guard();
DROP TYPE IF EXISTS checkin_mode, match_kind, rel_status, generation, mood_trend, mood_level;
