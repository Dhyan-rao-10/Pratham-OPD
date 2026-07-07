-- Patient allergies (keyed by phone since no persistent patient table)
CREATE TABLE IF NOT EXISTS patient_allergies (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_phone  VARCHAR(20) NOT NULL,
  allergen       VARCHAR(256) NOT NULL,
  reaction_type  VARCHAR(64),
  severity       VARCHAR(32) DEFAULT 'unknown',
  source         VARCHAR(32) DEFAULT 'patient_reported',
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_allergies_phone ON patient_allergies(patient_phone);

-- Prescriptions
CREATE TABLE IF NOT EXISTS prescriptions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id     UUID REFERENCES sessions(id),
  doctor_id      UUID REFERENCES doctors(id),
  patient_phone  VARCHAR(20),
  status         VARCHAR(32) DEFAULT 'active',
  qr_payload     TEXT,
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Prescription line items
CREATE TABLE IF NOT EXISTS prescription_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id  UUID REFERENCES prescriptions(id) ON DELETE CASCADE,
  drug_name        VARCHAR(256) NOT NULL,
  dose             VARCHAR(64),
  frequency        VARCHAR(32),
  duration         VARCHAR(64),
  instructions     TEXT,
  warnings         JSONB,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
