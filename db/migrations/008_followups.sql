CREATE TABLE IF NOT EXISTS scheduled_followups (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id     UUID REFERENCES sessions(id),
  protocol_id    VARCHAR(64) REFERENCES protocols(id),
  patient_phone  VARCHAR(20) NOT NULL,
  message        TEXT,
  send_at        TIMESTAMPTZ NOT NULL,
  sent_at        TIMESTAMPTZ,
  channel        VARCHAR(16) DEFAULT 'whatsapp',
  status         VARCHAR(32) DEFAULT 'pending',
  patient_response TEXT,
  response_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_followups_pending ON scheduled_followups(status, send_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_followups_phone ON scheduled_followups(patient_phone);
