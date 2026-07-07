-- Add scribe columns to session_reports
ALTER TABLE session_reports ADD COLUMN IF NOT EXISTS scribe_transcript TEXT;
ALTER TABLE session_reports ADD COLUMN IF NOT EXISTS scribe_soap JSONB;
ALTER TABLE session_reports ADD COLUMN IF NOT EXISTS scribe_created_at TIMESTAMPTZ;
