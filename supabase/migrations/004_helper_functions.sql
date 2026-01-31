-- Helper function to check if a location is in an inhabited area
CREATE OR REPLACE FUNCTION check_inhabited_area(
    check_lat DOUBLE PRECISION,
    check_lon DOUBLE PRECISION,
    radius_miles DOUBLE PRECISION DEFAULT 20
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    inhabited_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO inhabited_count
    FROM zip_codes
    WHERE is_inhabited = TRUE
        AND (
            -- Approximate distance calculation
            -- 1 degree latitude ≈ 69 miles
            -- 1 degree longitude ≈ 69 * cos(lat) miles
            SQRT(
                POWER((lat - check_lat) * 69, 2) +
                POWER((lon - check_lon) * 69 * COS(RADIANS(check_lat)), 2)
            ) <= radius_miles
        );

    RETURN inhabited_count > 0;
END;
$$;
