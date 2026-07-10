-- ============================================================
-- BWP PRINTING RESET + RECREATE ALL TABLES
-- คำเตือน: ไฟล์นี้ลบข้อมูลทุกตารางของระบบนี้ใน schema public แล้วสร้างใหม่
-- วิธีใช้: เปิด Supabase SQL Editor แล้ววาง/รันทั้งไฟล์นี้ครั้งเดียว
-- ============================================================

BEGIN;

-- ลบ View ก่อน เพราะอ้างอิงตาราง
DROP VIEW IF EXISTS products_with_customer CASCADE;
DROP VIEW IF EXISTS v_production_rolls_export CASCADE;

-- ลบ RPC / Trigger helper ของระบบ
DROP FUNCTION IF EXISTS delete_roll_atomic(UUID, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS return_to_rework_atomic(UUID, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS next_roll_no(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS trg_set_updated_at() CASCADE;

-- ลบตารางทั้งหมดของระบบ BWP Printing
DROP TABLE IF EXISTS
  rework_withdrawals,
  rework_jobs,
  job_summaries,
  production_jobs,
  parked_jobs,
  transfer_documents,
  roll_deletion_logs,
  production_rolls,
  production_roll,
  print_rolls,
  print_products,
  rework_rolls,
  machine_job_log,
  production_records,
  label_layouts,
  app_settings,
  weigh_logs,
  sales_orders,
  machine_profiles,
  products,
  customers
CASCADE;

COMMIT;

-- ============================================================
-- เริ่มสร้าง schema ใหม่ทั้งหมด
-- ============================================================
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
--  BWP เนเธเธเธเธเธดเธกเธเน (Printing) โ€” Baseline schema เธชเธณเธซเธฃเธฑเธ DB เนเธซเธกเน (เน€เธฃเธดเนเธกเธเธฒเธเธจเธนเธเธขเน)
--  Supabase project: vmvpnjgwdbbqrszxiapt
--  เธฃเธฑเธเธเธฃเธฑเนเธเน€เธ”เธตเธขเธงเนเธ SQL Editor  (idempotent โ€” เธฃเธฑเธเธเนเธณเนเธ”เน)
--
--  เธซเธกเธฒเธขเน€เธซเธ•เธธ: schema เธเธตเน reconstruct เธเธฒเธเนเธเนเธ”เนเธญเธ + db/*.sql เน€เธ”เธดเธก
--  เธเธฃเธญเธเธเธฅเธธเธกเธ—เธธเธเธ•เธฒเธฃเธฒเธ/เธเธญเธฅเธฑเธกเธเน/RPC เธ—เธตเนเนเธญเธเนเธเธเธเธเธดเธกเธเนเน€เธฃเธตเธขเธเนเธเน
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- helper trigger: เธญเธฑเธเน€เธ”เธ• updated_at เธญเธฑเธ•เนเธเธกเธฑเธ•เธด
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END $$ LANGUAGE plpgsql;

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 1) customers
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS customers (
  id            BIGSERIAL PRIMARY KEY,
  cust_code     TEXT NOT NULL UNIQUE,
  cust_name     TEXT NOT NULL,
  cust_address  TEXT,
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customers_code ON customers(cust_code);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(cust_name);
DROP TRIGGER IF EXISTS customers_set_updated_at ON customers;
CREATE TRIGGER customers_set_updated_at BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "customers_all" ON customers;
CREATE POLICY "customers_all" ON customers FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 2) products (master Item Code)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS products (
  id            BIGSERIAL PRIMARY KEY,
  item_code     TEXT NOT NULL UNIQUE,
  mat_code      TEXT,
  product_code  TEXT,
  product_name  TEXT,
  width_cm      TEXT,
  width_unit    TEXT DEFAULT 'cm',
  thick_mc      TEXT,
  core_weight   TEXT,
  length        TEXT,
  pcs           TEXT,
  barcode_no    TEXT,
  cust_code     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_products_item_code ON products(item_code);
CREATE INDEX IF NOT EXISTS idx_products_cust_code ON products(cust_code);
DROP TRIGGER IF EXISTS products_set_updated_at ON products;
CREATE TRIGGER products_set_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "products_all" ON products;
CREATE POLICY "products_all" ON products FOR ALL USING (true) WITH CHECK (true);
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_cust_code_fkey;
ALTER TABLE products ADD CONSTRAINT products_cust_code_fkey
  FOREIGN KEY (cust_code) REFERENCES customers(cust_code)
  ON UPDATE CASCADE ON DELETE SET NULL;

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 3) machine_profiles โ€” เนเธเธฃเนเธเธฅเนเธเธฒเธเธเธฑเธเธเธธเธเธฑเธเธ•เนเธญเน€เธเธฃเธทเนเธญเธ (P1..Pn / SL1..SL4)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS machine_profiles (
  machine_no      TEXT PRIMARY KEY,
  section         TEXT,
  -- เธฅเธนเธเธเนเธฒ
  cust_code       TEXT,
  cust_name       TEXT,
  cust_address    TEXT,
  cust_branch     TEXT,
  -- เธชเธดเธเธเนเธฒ
  item_code       TEXT,
  mat_code        TEXT,
  product_code    TEXT,
  product_name    TEXT,
  width_cm        TEXT,
  width_unit      TEXT DEFAULT 'cm',
  thick_mc        TEXT,
  -- เธเธฒเธ
  lot_no          TEXT,
  sale_order      TEXT,
  work_order      TEXT,
  delivery_date   DATE,
  planned_qty     TEXT,
  length          TEXT,
  pcs             TEXT,
  core_weight     TEXT DEFAULT '1.25',
  decimal_places  INT  DEFAULT 2,
  inspector       TEXT,
  -- เนเธเธเธฐเธซเธเนเธฒ
  label_size      TEXT DEFAULT 'long',
  header_text     TEXT,
  blank_header    BOOLEAN DEFAULT FALSE,
  -- เธชเธ–เธฒเธเธฐ
  locked          BOOLEAN DEFAULT FALSE,
  fresh_start     BOOLEAN DEFAULT FALSE,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_machine_profiles_item_code ON machine_profiles(item_code);
DROP TRIGGER IF EXISTS machine_profiles_set_updated_at ON machine_profiles;
CREATE TRIGGER machine_profiles_set_updated_at BEFORE UPDATE ON machine_profiles
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
ALTER TABLE machine_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "machine_profiles_all" ON machine_profiles;
CREATE POLICY "machine_profiles_all" ON machine_profiles FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 4) production_rolls โ€” เธกเนเธงเธเธ—เธตเนเธเธฑเนเธ (เธซเธฑเธงเนเธเธเธญเธเธฃเธฐเธเธ)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS production_rolls (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section         TEXT DEFAULT 'blow',
  machine_no      TEXT,
  lot_no          TEXT,
  roll_no         INT,
  roll_type       TEXT DEFAULT 'good',     -- 'good' | 'bad'
  -- เธเนเธณเธซเธเธฑเธ
  weight          NUMERIC,
  gross_weight    NUMERIC,
  core_weight     NUMERIC,
  length          TEXT,
  pcs             TEXT,
  -- เธชเธดเธเธเนเธฒ / เธฅเธนเธเธเนเธฒ
  customer        TEXT,
  cust_code       TEXT,
  cust_branch     TEXT,
  item_code       TEXT,
  mat_code        TEXT,
  product_code    TEXT,
  product_name    TEXT,
  width_cm        TEXT,
  width_unit      TEXT DEFAULT 'cm',
  thick_mc        TEXT,
  -- เธเธฒเธ
  sale_order      TEXT,
  work_order      TEXT,
  inspector       TEXT,
  remark          TEXT,
  -- เนเธญเธ/เธชเนเธ
  transferred     BOOLEAN DEFAULT FALSE,
  transferred_at  TIMESTAMPTZ,
  transferred_by  TEXT,
  transfer_doc_id TEXT,
  transfer_type   TEXT,
  shipped         BOOLEAN DEFAULT FALSE,
  shipped_at      TIMESTAMPTZ,
  shipped_by      TEXT,
  doc_no          TEXT,
  -- เธเธฃเธญ / เธฃเธตเน€เธงเธดเธฃเนเธ
  rework_status        TEXT,
  rework_dest_id       UUID,
  rework_remark        TEXT,
  rework_received_at   TIMESTAMPTZ,
  rework_received_by   TEXT,
  rework_source_lot    TEXT,
  rework_source_roll_id UUID,
  rework_source_weight NUMERIC,
  inbound_type    TEXT,
  -- เธเธดเธเธฒเธฃเธ“เธฒ (review)
  review_status        TEXT,
  review_action        TEXT,
  review_action_reason TEXT,
  review_decision_by   TEXT,
  review_decision_at   TIMESTAMPTZ,
  -- เธญเธทเนเธ เน
  so_id           UUID,
  is_legacy       BOOLEAN DEFAULT FALSE,
  withdrawn_to_job_id UUID,
  new_system      BOOLEAN DEFAULT TRUE,
  total_kg        NUMERIC,
  total_rolls     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pr_machine_lot ON production_rolls(machine_no, lot_no);
CREATE INDEX IF NOT EXISTS idx_pr_section ON production_rolls(section);
CREATE INDEX IF NOT EXISTS idx_pr_created ON production_rolls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pr_review_status ON production_rolls(review_status) WHERE review_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_barcode_no ON products(barcode_no);
CREATE INDEX IF NOT EXISTS idx_production_rolls_withdrawn_to_job
  ON production_rolls(withdrawn_to_job_id)
  WHERE withdrawn_to_job_id IS NOT NULL;
DROP INDEX IF EXISTS uniq_production_rolls_lot_rollno;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_production_rolls_lot_wo_rollno
  ON production_rolls (machine_no, lot_no, COALESCE(work_order, ''), roll_no, roll_type, COALESCE(inbound_type, ''))
  WHERE roll_type IN ('good','bad') AND roll_no > 0;

ALTER TABLE production_rolls ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "production_rolls_select" ON production_rolls;
CREATE POLICY "production_rolls_select" ON production_rolls FOR SELECT USING (true);
DROP POLICY IF EXISTS "production_rolls_insert" ON production_rolls;
CREATE POLICY "production_rolls_insert" ON production_rolls FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "production_rolls_update" ON production_rolls;
CREATE POLICY "production_rolls_update" ON production_rolls FOR UPDATE USING (true) WITH CHECK (true);
-- โ เนเธกเนเธกเธต policy DELETE โ’ เธฅเธเธ•เธฃเธเนเธกเนเนเธ”เน เธ•เนเธญเธเธเนเธฒเธ RPC delete_roll_atomic เน€เธ—เนเธฒเธเธฑเนเธ

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 5) roll_deletion_logs โ€” log เธเธฒเธฃเธฅเธเธกเนเธงเธ
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS roll_deletion_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_id   UUID,
  deleted_by    TEXT,
  deleted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason        TEXT,
  section       TEXT,
  machine_no    TEXT,
  lot_no        TEXT,
  roll_no       INT,
  roll_type     TEXT,
  weight        NUMERIC,
  gross_weight  NUMERIC,
  core_weight   NUMERIC,
  length        TEXT,
  pcs           TEXT,
  product_name  TEXT,
  product_code  TEXT,
  item_code     TEXT,
  mat_code      TEXT,
  cust_code     TEXT,
  cust_name     TEXT,
  cust_branch   TEXT,
  width_cm      TEXT,
  width_unit    TEXT DEFAULT 'cm',
  thick_mc      TEXT,
  sale_order    TEXT,
  work_order    TEXT,
  inspector     TEXT,
  started_at    TIMESTAMPTZ
);
ALTER TABLE roll_deletion_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "roll_deletion_logs_all" ON roll_deletion_logs;
CREATE POLICY "roll_deletion_logs_all" ON roll_deletion_logs FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 6) transfer_documents โ€” เนเธเนเธญเธเน€เธเนเธฒเธเธฅเธฑเธ
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS transfer_documents (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_no         TEXT UNIQUE,
  transfer_type  TEXT,
  machine_no     TEXT,
  lot_no         TEXT,
  customer       TEXT,
  product_name   TEXT,
  size           TEXT,
  sale_order     TEXT,
  work_order     TEXT,
  total_kg       NUMERIC,
  total_rolls    INT,
  transferred_by TEXT,
  transferred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE transfer_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "transfer_documents_all" ON transfer_documents;
CREATE POLICY "transfer_documents_all" ON transfer_documents FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 7) parked_jobs โ€” เธเธฒเธเธ—เธตเนเธเธฑเธเนเธงเน (เธเธฑเธเนเธ”เนเธซเธฅเธฒเธขเธเธฒเธ/เน€เธเธฃเธทเนเธญเธ)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS parked_jobs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_no       TEXT NOT NULL,
  lot_no           TEXT,
  profile_snapshot JSONB,
  parked_by        TEXT,
  parked_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_parked_machine_lot
  ON parked_jobs (machine_no, COALESCE(lot_no, ''));
ALTER TABLE parked_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "parked_jobs_all" ON parked_jobs;
CREATE POLICY "parked_jobs_all" ON parked_jobs FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 8) job_summaries โ€” เนเธเธเธดเธ”เธเธฒเธเธ–เธฒเธงเธฃ
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS job_summaries (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_no     TEXT,
  lot_no         TEXT,
  customer       TEXT,
  product_name   TEXT,
  item_code      TEXT,
  mat_code       TEXT,
  sale_order     TEXT,
  work_order     TEXT,
  delivery_date  DATE,
  planned_qty    TEXT,
  good_rolls     INT,
  bad_rolls      INT,
  good_kg        NUMERIC,
  bad_kg         NUMERIC,
  scrap_kg       NUMERIC,
  transferred_kg NUMERIC,
  yield_pct      NUMERIC,
  inspector      TEXT,
  closed_by      TEXT,
  closed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_job_summaries_lot ON job_summaries(lot_no);
ALTER TABLE job_summaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "job_summaries_all" ON job_summaries;
CREATE POLICY "job_summaries_all" ON job_summaries FOR ALL USING (true) WITH CHECK (true);

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
CREATE INDEX IF NOT EXISTS idx_production_jobs_status ON production_jobs(status);
CREATE INDEX IF NOT EXISTS idx_production_jobs_so ON production_jobs(sale_order);
DROP TRIGGER IF EXISTS production_jobs_set_updated_at ON production_jobs;
CREATE TRIGGER production_jobs_set_updated_at BEFORE UPDATE ON production_jobs
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
ALTER TABLE production_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "production_jobs_all" ON production_jobs;
CREATE POLICY "production_jobs_all" ON production_jobs FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 9) rework_jobs โ€” เธเธฒเธเธเธฃเธญ (job-centric)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS rework_jobs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_no          TEXT NOT NULL,
  sale_order      TEXT,
  work_order      TEXT,
  delivery_date   DATE,
  item_code       TEXT,
  mat_code        TEXT,
  product_code    TEXT,
  product_name    TEXT,
  width_cm        TEXT,
  width_unit      TEXT DEFAULT 'cm',
  thick_mc        TEXT,
  cust_code       TEXT,
  cust_name       TEXT,
  cust_branch     TEXT,
  core_weight     TEXT DEFAULT '1.25',
  decimal_places  INT  DEFAULT 2,
  planned_qty     TEXT,
  inspector       TEXT,
  label_size      TEXT DEFAULT 'long',
  header_text     TEXT,
  blank_header    BOOLEAN DEFAULT FALSE,
  source          TEXT DEFAULT 'manual',
  source_roll_id  UUID,
  source_lot_no   TEXT,
  source_roll_count INTEGER DEFAULT 1,
  source_defect_reason TEXT,
  rework_reason   TEXT,
  rewinder_name   TEXT,
  new_system      BOOLEAN DEFAULT TRUE,
  status          TEXT DEFAULT 'active',
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  closed_by       TEXT,
  closed_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_rework_jobs_status ON rework_jobs(status);
CREATE INDEX IF NOT EXISTS idx_rework_jobs_lot ON rework_jobs(lot_no);
ALTER TABLE rework_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rework_jobs_all" ON rework_jobs;
CREATE POLICY "rework_jobs_all" ON rework_jobs FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 10) rework_withdrawals โ€” เน€เธเธดเธเธกเนเธงเธเน€เธเนเธฒเธเธฒเธเธเธฃเธญ
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS rework_withdrawals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id         UUID,
  source_roll_id UUID,
  lot_no         TEXT,
  sale_order     TEXT,
  work_order     TEXT,
  item_code      TEXT,
  product_name   TEXT,
  weight         NUMERIC,
  withdrawn_by   TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE rework_withdrawals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rework_withdrawals_all" ON rework_withdrawals;
CREATE POLICY "rework_withdrawals_all" ON rework_withdrawals FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 11) sales_orders โ€” เนเธเธชเธฑเนเธเธเธฒเธข (target เธเธฅเธดเธ•)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS sales_orders (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  so_no        TEXT UNIQUE,
  customer     TEXT,
  product_name TEXT,
  target_kg    NUMERIC,
  status       TEXT DEFAULT 'open',
  note         TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sales_orders_all" ON sales_orders;
CREATE POLICY "sales_orders_all" ON sales_orders FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 12) weigh_logs โ€” log เธเธฒเธฃเธเธฑเนเธเธ”เธดเธ (audit)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS weigh_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_no   TEXT,
  lot_no       TEXT,
  roll_no      INT,
  roll_type    TEXT,
  weight       NUMERIC,
  net_weight   NUMERIC,
  gross_weight NUMERIC,
  core_weight  NUMERIC,
  customer     TEXT,
  cust_branch  TEXT,
  product_name TEXT,
  item_code    TEXT,
  sale_order   TEXT,
  work_order   TEXT,
  inspector    TEXT,
  width_unit   TEXT DEFAULT 'cm',
  remark       TEXT,
  weighed_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_weigh_logs_created ON weigh_logs(created_at DESC);
ALTER TABLE weigh_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "weigh_logs_all" ON weigh_logs;
CREATE POLICY "weigh_logs_all" ON weigh_logs FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 13) app_settings โ€” เธเนเธฒเธ•เธฑเนเธเธเนเธฒเธฃเธฐเธเธ (announcement, PIN เธฏเธฅเธฏ)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_settings_all" ON app_settings;
CREATE POLICY "app_settings_all" ON app_settings FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 14) label_layouts โ€” เน€เธฅเธขเนเน€เธญเธฒเธ•เนเนเธเธเธฐเธซเธเนเธฒ (LabelDesigner)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS label_layouts (
  id         TEXT PRIMARY KEY,      -- 'long' | 'short'
  layout     JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE label_layouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "label_layouts_all" ON label_layouts;
CREATE POLICY "label_layouts_all" ON label_layouts FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 15) production_records / machine_job_log (legacy/aux โ€” เธชเธฃเนเธฒเธเน€เธเธทเนเธญเนเธเนเธ”เธญเนเธฒเธ)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
CREATE TABLE IF NOT EXISTS production_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  row_key         TEXT,
  production_date DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE production_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "production_records_all" ON production_records;
CREATE POLICY "production_records_all" ON production_records FOR ALL USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS machine_job_log (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section    TEXT,
  machine_no TEXT,
  lot_no     TEXT,
  work_order TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE machine_job_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "machine_job_log_all" ON machine_job_log;
CREATE POLICY "machine_job_log_all" ON machine_job_log FOR ALL USING (true) WITH CHECK (true);

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 16) VIEWs
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
DROP VIEW IF EXISTS products_with_customer;
CREATE VIEW products_with_customer AS
SELECT p.*, c.cust_name, c.cust_address
FROM products p LEFT JOIN customers c ON c.cust_code = p.cust_code;

DROP VIEW IF EXISTS v_production_rolls_export;
CREATE VIEW v_production_rolls_export AS
SELECT
  id, machine_no, lot_no, roll_no, roll_type, weight, gross_weight, core_weight,
  product_name, product_code, item_code, mat_code, customer, cust_code,
  width_cm, thick_mc, length, pcs, remark, inspector,
  section, transferred, transferred_at, transferred_by, transfer_doc_id,
  rework_status, rework_dest_id, rework_remark, inbound_type,
  created_at
FROM production_rolls ORDER BY created_at DESC;
GRANT SELECT ON v_production_rolls_export TO anon, authenticated;

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- 17) RPCs (เธเธฒเธ hardening.sql)
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
DROP FUNCTION IF EXISTS delete_roll_atomic(UUID, TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION delete_roll_atomic(
  p_roll_id UUID, p_deleted_by TEXT, p_reason TEXT,
  p_work_order TEXT DEFAULT NULL, p_sale_order TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_roll production_rolls%ROWTYPE; v_logid UUID;
BEGIN
  IF p_deleted_by IS NULL OR length(trim(p_deleted_by))=0 THEN RAISE EXCEPTION 'deleted_by required'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason))=0 THEN RAISE EXCEPTION 'reason required'; END IF;
  SELECT * INTO v_roll FROM production_rolls WHERE id=p_roll_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'roll % not found', p_roll_id; END IF;
  INSERT INTO roll_deletion_logs (
    deleted_by, reason, machine_no, lot_no, work_order, sale_order, roll_no, roll_type,
    weight, gross_weight, core_weight, length, pcs, product_name, product_code, item_code,
    mat_code, cust_code, cust_name, width_cm, thick_mc, inspector, started_at, section
  ) VALUES (
    trim(p_deleted_by), trim(p_reason), v_roll.machine_no, v_roll.lot_no,
    COALESCE(p_work_order, v_roll.work_order, ''), COALESCE(p_sale_order, v_roll.sale_order, ''),
    v_roll.roll_no, v_roll.roll_type, v_roll.weight, v_roll.gross_weight, v_roll.core_weight,
    v_roll.length, v_roll.pcs, v_roll.product_name, v_roll.product_code, v_roll.item_code,
    v_roll.mat_code, v_roll.cust_code, v_roll.customer, v_roll.width_cm, v_roll.thick_mc,
    v_roll.inspector, v_roll.created_at, COALESCE(v_roll.section,'blow')
  ) RETURNING id INTO v_logid;
  DELETE FROM production_rolls WHERE id=p_roll_id;
  RETURN v_logid;
END $$;
GRANT EXECUTE ON FUNCTION delete_roll_atomic(UUID, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

DROP FUNCTION IF EXISTS return_to_rework_atomic(UUID, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION return_to_rework_atomic(
  p_roll_id UUID, p_inbound_type TEXT, p_reason TEXT, p_by TEXT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_roll production_rolls%ROWTYPE; v_logid UUID;
BEGIN
  IF p_by IS NULL OR length(trim(p_by))=0 THEN RAISE EXCEPTION 'by required'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason))=0 THEN RAISE EXCEPTION 'reason required'; END IF;
  SELECT * INTO v_roll FROM production_rolls WHERE id=p_roll_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'roll % not found', p_roll_id; END IF;
  IF v_roll.roll_type <> 'good' THEN RAISE EXCEPTION 'roll % is not good (current=%)', p_roll_id, v_roll.roll_type; END IF;
  INSERT INTO roll_deletion_logs (
    deleted_by, reason, machine_no, lot_no, roll_no, roll_type, weight, gross_weight,
    core_weight, length, product_name, product_code, item_code, mat_code, cust_code,
    cust_name, width_cm, thick_mc, inspector, started_at, section
  ) VALUES (
    trim(p_by), '[เธชเนเธเธเธฅเธฑเธเธเธฃเธญ] ' || trim(p_reason), v_roll.machine_no, v_roll.lot_no,
    v_roll.roll_no, 'good', v_roll.weight, v_roll.gross_weight, v_roll.core_weight, v_roll.length,
    v_roll.product_name, v_roll.product_code, v_roll.item_code, v_roll.mat_code, v_roll.cust_code,
    v_roll.customer, v_roll.width_cm, v_roll.thick_mc, v_roll.inspector, v_roll.created_at, 'rewind'
  ) RETURNING id INTO v_logid;
  UPDATE production_rolls SET
    roll_type='bad', remark=trim(p_reason), inbound_type=p_inbound_type, rework_status=NULL,
    transferred=TRUE, transferred_by=trim(p_by), transferred_at=NOW(), transfer_doc_id=NULL, section='rewind'
  WHERE id=p_roll_id;
  RETURN v_logid;
END $$;
GRANT EXECUTE ON FUNCTION return_to_rework_atomic(UUID, TEXT, TEXT, TEXT) TO anon, authenticated;

DROP FUNCTION IF EXISTS next_roll_no(TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION next_roll_no(
  p_machine_no TEXT, p_lot_no TEXT, p_roll_type TEXT
) RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_next INT;
BEGIN
  SELECT COALESCE(MIN(g), (SELECT COALESCE(MAX(roll_no),0)+1 FROM production_rolls
                           WHERE machine_no=p_machine_no AND lot_no=p_lot_no AND roll_type=p_roll_type))
  INTO v_next
  FROM generate_series(1, COALESCE((SELECT MAX(roll_no) FROM production_rolls
                                    WHERE machine_no=p_machine_no AND lot_no=p_lot_no AND roll_type=p_roll_type),0)+1) g
  WHERE g NOT IN (SELECT roll_no FROM production_rolls
                  WHERE machine_no=p_machine_no AND lot_no=p_lot_no AND roll_type=p_roll_type
                    AND roll_no IS NOT NULL AND roll_no>0);
  RETURN COALESCE(v_next, 1);
END $$;
GRANT EXECUTE ON FUNCTION next_roll_no(TEXT, TEXT, TEXT) TO anon, authenticated;

-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
-- เน€เธชเธฃเนเธ โ€” เธ•เธฃเธงเธเธเธฑเธเธ•เธฒเธฃเธฒเธ
-- โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•โ•
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' ORDER BY table_name;
