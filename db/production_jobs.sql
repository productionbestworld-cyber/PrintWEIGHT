CREATE TABLE IF NOT EXISTS production_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status TEXT DEFAULT 'open',
  sale_order TEXT,
  work_order TEXT NOT NULL,
  lot_no TEXT NOT NULL,
  print_machine TEXT,
  slit_machine TEXT,
  customer TEXT,
  cust_code TEXT,
  cust_branch TEXT,
  item_code TEXT,
  mat_code TEXT,
  product_code TEXT,
  product_name TEXT,
  width_cm TEXT,
  width_unit TEXT DEFAULT 'cm',
  thick_mc TEXT,
  core_weight TEXT,
  length TEXT,
  pcs TEXT,
  planned_qty TEXT,
  delivery_date DATE,
  note TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_production_jobs_wo_lot
  ON production_jobs (work_order, lot_no);
CREATE INDEX IF NOT EXISTS idx_production_jobs_status
  ON production_jobs(status);
CREATE INDEX IF NOT EXISTS idx_production_jobs_so
  ON production_jobs(sale_order);

DROP TRIGGER IF EXISTS production_jobs_set_updated_at ON production_jobs;
CREATE TRIGGER production_jobs_set_updated_at BEFORE UPDATE ON production_jobs
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

ALTER TABLE production_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "production_jobs_all" ON production_jobs;
CREATE POLICY "production_jobs_all" ON production_jobs FOR ALL USING (true) WITH CHECK (true);
