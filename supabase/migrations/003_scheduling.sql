-- Schedule the wind engine to run every 15 minutes
-- Requires pg_cron extension (enabled on Supabase Pro)

-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the wind engine function
SELECT cron.schedule(
    'wind-engine',
    '*/15 * * * *', -- Every 15 minutes
    $$
    SELECT net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/wind-engine',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Also schedule expiration cleanup
SELECT cron.schedule(
    'expire-notes',
    '0 * * * *', -- Every hour
    $$
    UPDATE notes
    SET status = 'expired'
    WHERE status = 'active'
        AND expires_at < NOW();
    $$
);
