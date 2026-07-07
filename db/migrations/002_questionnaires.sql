CREATE TABLE IF NOT EXISTS questionnaire_nodes (
  id            VARCHAR(128) PRIMARY KEY,
  department    VARCHAR(32) NOT NULL,
  text_en       TEXT NOT NULL,
  text_hi       TEXT,
  text_te       TEXT,
  q_type        VARCHAR(32) NOT NULL,
  options_json  JSONB,
  required      BOOLEAN DEFAULT TRUE,
  triage_flag   VARCHAR(8),
  triage_answer VARCHAR(64),
  next_default  VARCHAR(128),
  next_rules    JSONB,
  fhir_mapping  VARCHAR(128),
  is_active     BOOLEAN DEFAULT TRUE,
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
