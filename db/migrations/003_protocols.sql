CREATE TABLE IF NOT EXISTS protocols (
  id             VARCHAR(64) PRIMARY KEY,
  name           VARCHAR(256) NOT NULL,
  department     VARCHAR(32) NOT NULL,
  trigger_conditions JSONB,
  trigger_medications JSONB,
  required_tests JSONB,
  required_vitals JSONB,
  pre_visit_msg_en TEXT,
  pre_visit_msg_hi TEXT,
  pre_visit_msg_te TEXT,
  authored_by    VARCHAR(128),
  is_active      BOOLEAN DEFAULT TRUE,
  version        VARCHAR(16),
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS protocol_sessions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id     UUID REFERENCES sessions(id),
  protocol_id    VARCHAR(64) REFERENCES protocols(id),
  triggered_by   JSONB,
  advisory_sent  BOOLEAN DEFAULT FALSE,
  advisory_sent_at TIMESTAMPTZ,
  advisory_channel VARCHAR(16),
  test_compliance JSONB,
  all_required_complete BOOLEAN DEFAULT FALSE,
  waivers        JSONB,
  ai_flags       JSONB,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
