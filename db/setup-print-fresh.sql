-- ════════════════════════════════════════════════════════════════════════
--  BWP แผนกพิมพ์ (Printing) — Baseline schema สำหรับ DB ใหม่ (เริ่มจากศูนย์)
--  Supabase project: vmvpnjgwdbbqrszxiapt
--  รันครั้งเดียวใน SQL Editor  (idempotent — รันซ้ำได้)
--
--  หมายเหตุ: schema นี้ reconstruct จากโค้ดแอป + db/*.sql เดิม
--  ครอบคลุมทุกตาราง/คอลัมน์/RPC ที่แอปแผนกพิมพ์เรียกใช้
-- ════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- helper trigger: อัปเดต updated_at อัตโนมัติ
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END $$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════════════════
-- 1) customers
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 2) products (master Item Code)
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 3) machine_profiles — โปรไฟล์งานปัจจุบันต่อเครื่อง (P1..Pn / SL1..SL4)
-- ════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS machine_profiles (
  machine_no      TEXT PRIMARY KEY,
  section         TEXT,
  -- ลูกค้า
  cust_code       TEXT,
  cust_name       TEXT,
  cust_address    TEXT,
  cust_branch     TEXT,
  -- สินค้า
  item_code       TEXT,
  mat_code        TEXT,
  product_code    TEXT,
  product_name    TEXT,
  width_cm        TEXT,
  width_unit      TEXT DEFAULT 'cm',
  thick_mc        TEXT,
  -- งาน
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
  -- ใบปะหน้า
  label_size      TEXT DEFAULT 'long',
  header_text     TEXT,
  blank_header    BOOLEAN DEFAULT FALSE,
  -- สถานะ
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

-- ════════════════════════════════════════════════════════════════════════
-- 4) production_rolls — ม้วนที่ชั่ง (หัวใจของระบบ)
-- ════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS production_rolls (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section         TEXT DEFAULT 'blow',
  machine_no      TEXT,
  lot_no          TEXT,
  roll_no         INT,
  roll_type       TEXT DEFAULT 'good',     -- 'good' | 'bad'
  -- น้ำหนัก
  weight          NUMERIC,
  gross_weight    NUMERIC,
  core_weight     NUMERIC,
  length          TEXT,
  pcs             TEXT,
  -- สินค้า / ลูกค้า
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
  -- งาน
  sale_order      TEXT,
  work_order      TEXT,
  inspector       TEXT,
  remark          TEXT,
  -- โอน/ส่ง
  transferred     BOOLEAN DEFAULT FALSE,
  transferred_at  TIMESTAMPTZ,
  transferred_by  TEXT,
  transfer_doc_id TEXT,
  transfer_type   TEXT,
  shipped         BOOLEAN DEFAULT FALSE,
  shipped_at      TIMESTAMPTZ,
  shipped_by      TEXT,
  doc_no          TEXT,
  -- กรอ / รีเวิร์ก
  rework_status        TEXT,
  rework_dest_id       UUID,
  rework_remark        TEXT,
  rework_received_at   TIMESTAMPTZ,
  rework_received_by   TEXT,
  rework_source_lot    TEXT,
  rework_source_roll_id UUID,
  rework_source_weight NUMERIC,
  inbound_type    TEXT,
  -- พิจารณา (review)
  review_status        TEXT,
  review_action        TEXT,
  review_action_reason TEXT,
  review_decision_by   TEXT,
  review_decision_at   TIMESTAMPTZ,
  -- อื่น ๆ
  so_id           UUID,
  job_id          UUID,   -- อ้างอิง production_jobs.id (FK เพิ่มทีหลังหลังตาราง production_jobs ถูกสร้าง)
  withdrawn_to_job_id UUID,  -- เบิกม้วนพักไว้ไปเข้างานปลายทาง (rework_status='withdrawn')
  is_legacy       BOOLEAN DEFAULT FALSE,
  new_system      BOOLEAN DEFAULT TRUE,
  total_kg        NUMERIC,
  total_rolls     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pr_machine_lot ON production_rolls(machine_no, lot_no);
CREATE INDEX IF NOT EXISTS idx_pr_section ON production_rolls(section);
CREATE INDEX IF NOT EXISTS idx_pr_created ON production_rolls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pr_review_status ON production_rolls(review_status) WHERE review_status IS NOT NULL;
DROP INDEX IF EXISTS uniq_production_rolls_lot_rollno;
-- เลขม้วนแยกตามสเตจงานพิมพ์ (ก่อนพิมพ์/หลังพิมพ์/สลิท = inbound_type) — ของใครของมัน ไม่ชนกันข้าม stage
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
-- ❌ ไม่มี policy DELETE → ลบตรงไม่ได้ ต้องผ่าน RPC delete_roll_atomic เท่านั้น

-- ════════════════════════════════════════════════════════════════════════
-- 5) roll_deletion_logs — log การลบม้วน
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 6) transfer_documents — ใบโอนเข้าคลัง
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 7) parked_jobs — งานที่พักไว้ (พักได้หลายงาน/เครื่อง)
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 8) job_summaries — ใบปิดงานถาวร
-- ════════════════════════════════════════════════════════════════════════
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

-- เชื่อมม้วนกับงาน (production_rolls.job_id → production_jobs.id) — WeighStation.tsx เขียนคอลัมน์นี้ตอนบันทึกม้วน
ALTER TABLE production_rolls DROP CONSTRAINT IF EXISTS production_rolls_job_id_fkey;
ALTER TABLE production_rolls ADD CONSTRAINT production_rolls_job_id_fkey
  FOREIGN KEY (job_id) REFERENCES production_jobs(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_pr_job_id ON production_rolls(job_id) WHERE job_id IS NOT NULL;

-- ════════════════════════════════════════════════════════════════════════
-- 9) rework_jobs — งานกรอ (job-centric)
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 10) rework_withdrawals — เบิกม้วนเข้างานกรอ
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 11) sales_orders — ใบสั่งขาย (target ผลิต)
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 12) weigh_logs — log การชั่งดิบ (audit)
-- ════════════════════════════════════════════════════════════════════════
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
  mat_code     TEXT,
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

-- ════════════════════════════════════════════════════════════════════════
-- 13) app_settings — ค่าตั้งค่าระบบ (announcement, PIN ฯลฯ)
-- ════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_settings_all" ON app_settings;
CREATE POLICY "app_settings_all" ON app_settings FOR ALL USING (true) WITH CHECK (true);

-- ════════════════════════════════════════════════════════════════════════
-- 14) label_layouts — เลย์เอาต์ใบปะหน้า (LabelDesigner)
-- ════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS label_layouts (
  id         TEXT PRIMARY KEY,      -- 'long' | 'short'
  layout     JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE label_layouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "label_layouts_all" ON label_layouts;
CREATE POLICY "label_layouts_all" ON label_layouts FOR ALL USING (true) WITH CHECK (true);

-- ════════════════════════════════════════════════════════════════════════
-- 15) production_records / machine_job_log (legacy/aux — สร้างเผื่อโค้ดอ้าง)
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 16) VIEWs
-- ════════════════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════════════════
-- 17) RPCs (จาก hardening.sql)
-- ════════════════════════════════════════════════════════════════════════
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
    trim(p_by), '[ส่งกลับกรอ] ' || trim(p_reason), v_roll.machine_no, v_roll.lot_no,
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

-- ════════════════════════════════════════════════════════════════════════
-- เสร็จ — ตรวจนับตาราง
-- ════════════════════════════════════════════════════════════════════════
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' ORDER BY table_name;
