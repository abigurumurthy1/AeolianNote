-- Row Level Security Policies

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_encounters ENABLE ROW LEVEL SECURITY;
ALTER TABLE zip_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE wind_cache ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Notes policies
CREATE POLICY "Anyone can view active notes"
    ON notes FOR SELECT
    USING (status = 'active');

CREATE POLICY "Users can view their own notes"
    ON notes FOR SELECT
    USING (sender_id = auth.uid());

CREATE POLICY "Authenticated users can create notes"
    ON notes FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own notes"
    ON notes FOR UPDATE
    USING (sender_id = auth.uid());

-- Service role can update any note (for wind engine)
CREATE POLICY "Service role can update notes"
    ON notes FOR UPDATE
    USING (auth.role() = 'service_role');

-- Note encounters policies
CREATE POLICY "Users can view their encounters"
    ON note_encounters FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Service role can manage encounters"
    ON note_encounters FOR ALL
    USING (auth.role() = 'service_role');

-- ZIP codes are public read
CREATE POLICY "Anyone can read zip codes"
    ON zip_codes FOR SELECT
    TO PUBLIC
    USING (true);

-- Wind cache is public read, service write
CREATE POLICY "Anyone can read wind cache"
    ON wind_cache FOR SELECT
    TO PUBLIC
    USING (true);

CREATE POLICY "Service role can manage wind cache"
    ON wind_cache FOR ALL
    USING (auth.role() = 'service_role');
