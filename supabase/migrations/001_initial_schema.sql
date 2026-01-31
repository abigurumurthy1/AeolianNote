-- Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    home_zip_code TEXT,
    uses_live_location BOOLEAN DEFAULT FALSE,
    current_lat DOUBLE PRECISION,
    current_lon DOUBLE PRECISION,
    push_token TEXT,
    stats JSONB DEFAULT '{"notesLaunched": 0, "notesCaught": 0, "totalMilesTraveled": 0, "longestJourney": 0}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ZIP codes reference table (US data)
CREATE TABLE zip_codes (
    zip_code TEXT PRIMARY KEY,
    city TEXT NOT NULL,
    state_code TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    population INTEGER DEFAULT 0,
    is_inhabited BOOLEAN DEFAULT TRUE
);

-- Notes table
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) <= 140),
    is_anonymous BOOLEAN DEFAULT FALSE,
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lon DOUBLE PRECISION NOT NULL,
    current_lat DOUBLE PRECISION NOT NULL,
    current_lon DOUBLE PRECISION NOT NULL,
    current_location GEOGRAPHY(POINT, 4326),
    journey_path JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'caught', 'expired', 'dissolved')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '72 hours')
);

-- Wind cache table
CREATE TABLE wind_cache (
    region_key TEXT PRIMARY KEY,
    wind_speed_mph DOUBLE PRECISION NOT NULL,
    wind_bearing_degrees DOUBLE PRECISION NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

-- Note encounters table
CREATE TABLE note_encounters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    distance_miles DOUBLE PRECISION NOT NULL,
    was_tapped BOOLEAN DEFAULT FALSE,
    encountered_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(note_id, user_id)
);

-- Create indexes
CREATE INDEX idx_notes_status ON notes(status) WHERE status = 'active';
CREATE INDEX idx_notes_current_location ON notes USING GIST (current_location);
CREATE INDEX idx_notes_sender ON notes(sender_id);
CREATE INDEX idx_notes_expires ON notes(expires_at) WHERE status = 'active';
CREATE INDEX idx_encounters_user ON note_encounters(user_id);
CREATE INDEX idx_encounters_note ON note_encounters(note_id);
CREATE INDEX idx_zip_codes_location ON zip_codes(lat, lon);

-- Trigger to update current_location geography column
CREATE OR REPLACE FUNCTION update_note_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.current_location = ST_SetSRID(ST_MakePoint(NEW.current_lon, NEW.current_lat), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_note_location
    BEFORE INSERT OR UPDATE OF current_lat, current_lon ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_note_location();

-- Function to get nearby notes using PostGIS
CREATE OR REPLACE FUNCTION get_nearby_notes(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    radius_miles DOUBLE PRECISION DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    sender_id UUID,
    content TEXT,
    is_anonymous BOOLEAN,
    origin_lat DOUBLE PRECISION,
    origin_lon DOUBLE PRECISION,
    current_lat DOUBLE PRECISION,
    current_lon DOUBLE PRECISION,
    journey_path JSONB,
    status TEXT,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    sender_display_name TEXT,
    sender_avatar_url TEXT,
    distance_from_user DOUBLE PRECISION
)
LANGUAGE plpgsql
AS $$
DECLARE
    user_point GEOGRAPHY;
    radius_meters DOUBLE PRECISION;
BEGIN
    user_point := ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography;
    radius_meters := radius_miles * 1609.34;

    RETURN QUERY
    SELECT
        n.id,
        n.sender_id,
        n.content,
        n.is_anonymous,
        n.origin_lat,
        n.origin_lon,
        n.current_lat,
        n.current_lon,
        n.journey_path,
        n.status,
        n.created_at,
        n.expires_at,
        CASE WHEN n.is_anonymous THEN NULL ELSE u.display_name END,
        CASE WHEN n.is_anonymous THEN NULL ELSE u.avatar_url END,
        ST_Distance(n.current_location, user_point) / 1609.34 AS distance_from_user
    FROM notes n
    LEFT JOIN users u ON n.sender_id = u.id
    WHERE n.status = 'active'
        AND ST_DWithin(n.current_location, user_point, radius_meters)
    ORDER BY distance_from_user ASC;
END;
$$;

-- Function to get inbox notes for a user
CREATE OR REPLACE FUNCTION get_inbox_notes(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    sender_id UUID,
    content TEXT,
    is_anonymous BOOLEAN,
    origin_lat DOUBLE PRECISION,
    origin_lon DOUBLE PRECISION,
    current_lat DOUBLE PRECISION,
    current_lon DOUBLE PRECISION,
    journey_path JSONB,
    status TEXT,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    sender_display_name TEXT,
    sender_avatar_url TEXT,
    distance_from_user DOUBLE PRECISION
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id,
        n.sender_id,
        n.content,
        n.is_anonymous,
        n.origin_lat,
        n.origin_lon,
        n.current_lat,
        n.current_lon,
        n.journey_path,
        n.status,
        n.created_at,
        n.expires_at,
        CASE WHEN n.is_anonymous THEN NULL ELSE u.display_name END,
        CASE WHEN n.is_anonymous THEN NULL ELSE u.avatar_url END,
        e.distance_miles
    FROM note_encounters e
    JOIN notes n ON e.note_id = n.id
    LEFT JOIN users u ON n.sender_id = u.id
    WHERE e.user_id = p_user_id
        AND e.was_tapped = FALSE
        AND n.status = 'active'
        AND n.sender_id != p_user_id
    ORDER BY e.encountered_at DESC;
END;
$$;

-- Function to increment notes caught stat
CREATE OR REPLACE FUNCTION increment_notes_caught(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users
    SET stats = jsonb_set(
        stats,
        '{notesCaught}',
        to_jsonb((stats->>'notesCaught')::int + 1)
    )
    WHERE id = p_user_id;
END;
$$;

-- Function to increment notes launched stat
CREATE OR REPLACE FUNCTION increment_notes_launched(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users
    SET stats = jsonb_set(
        stats,
        '{notesLaunched}',
        to_jsonb((stats->>'notesLaunched')::int + 1)
    )
    WHERE id = p_user_id;
END;
$$;

-- Trigger to increment notes launched on insert
CREATE OR REPLACE FUNCTION on_note_created()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM increment_notes_launched(NEW.sender_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_note_created
    AFTER INSERT ON notes
    FOR EACH ROW
    EXECUTE FUNCTION on_note_created();
