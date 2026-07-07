CREATE TABLE IF NOT EXISTS sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id   VARCHAR(64) NOT NULL,
  department    VARCHAR(32) NOT NULL,
  queue_slot    INTEGER,
  patient_id    VARCHAR(128),
  patient_name  VARCHAR(256),
  patient_phone VARCHAR(20),
  patient_age   INTEGER,
  patient_gender CHAR(1),
  language      VARCHAR(8) DEFAULT 'en',
  state         VARCHAR(32) DEFAULT 'INIT',
  triage_level  VARCHAR(8),
  consent_given BOOLEAN DEFAULT FALSE,
  consent_at    TIMESTAMPTZ,
  is_attender_mode BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS session_documents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID REFERENCES sessions(id),
  doc_type      VARCHAR(32),
  storage_key   VARCHAR(512),
  ocr_raw       TEXT,
  ocr_structured JSONB,
  ocr_confidence FLOAT,
  patient_confirmed BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS session_answers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID REFERENCES sessions(id),
  question_id   VARCHAR(128) NOT NULL,
  answer_raw    TEXT,
  answer_structured JSONB,
  input_mode    VARCHAR(8) DEFAULT 'text',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS session_vitals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID REFERENCES sessions(id),
  bp_systolic   INTEGER,
  bp_diastolic  INTEGER,
  bp_side       VARCHAR(8),
  weight_kg     FLOAT,
  spo2_pct      INTEGER,
  heart_rate    INTEGER,
  temperature_c FLOAT,
  source        VARCHAR(32) DEFAULT 'manual',
  recorded_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS session_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID REFERENCES sessions(id),
  report_md     TEXT,
  report_json   JSONB,
  fhir_bundle   JSONB,
  his_pushed    BOOLEAN DEFAULT FALSE,
  his_pushed_at TIMESTAMPTZ,
  his_response  JSONB,
  doctor_feedback VARCHAR(16),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
