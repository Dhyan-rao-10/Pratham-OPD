CREATE TABLE IF NOT EXISTS departments (
  code          VARCHAR(32) PRIMARY KEY,
  name          VARCHAR(256) NOT NULL,
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Seed a single neutral starter department so the app runs out of the box.
-- Add your hospital's real departments in the Admin dashboard (HIS → Departments).
INSERT INTO departments (code, name) VALUES
  ('OPD', 'General OPD')
ON CONFLICT (code) DO NOTHING;
