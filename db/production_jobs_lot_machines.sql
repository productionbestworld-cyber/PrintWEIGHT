ALTER TABLE production_jobs ADD COLUMN IF NOT EXISTS print_machine TEXT;
ALTER TABLE production_jobs ADD COLUMN IF NOT EXISTS slit_machine TEXT;

CREATE INDEX IF NOT EXISTS idx_production_jobs_print_machine
  ON production_jobs(print_machine);
CREATE INDEX IF NOT EXISTS idx_production_jobs_slit_machine
  ON production_jobs(slit_machine);
