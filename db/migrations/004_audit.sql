CREATE TABLE IF NOT EXISTS audit_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID,
  event_type    VARCHAR(64) NOT NULL,
  actor         VARCHAR(128),
  payload       JSONB,
  ip_address    INET,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
