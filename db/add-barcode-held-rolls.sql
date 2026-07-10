-- เพิ่มช่อง Barcode No. ให้คลังสินค้า และช่องผูกม้วนพักไป WO ปลายทาง
-- รันใน Supabase SQL Editor ได้เลย ปลอดภัยกับฐานเดิมเพราะใช้ IF NOT EXISTS

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS barcode_no TEXT;

ALTER TABLE production_rolls
  ADD COLUMN IF NOT EXISTS withdrawn_to_job_id UUID;

CREATE INDEX IF NOT EXISTS idx_products_barcode_no
  ON products(barcode_no);

CREATE INDEX IF NOT EXISTS idx_production_rolls_withdrawn_to_job
  ON production_rolls(withdrawn_to_job_id)
  WHERE withdrawn_to_job_id IS NOT NULL;

-- อัปเดต view ให้ products_with_customer เห็น barcode_no ด้วย
-- ถ้า view เดิมสร้างก่อนเพิ่มคอลัมน์ใหม่ บางโปรเจคจะยังไม่เห็นช่องนี้
DROP VIEW IF EXISTS products_with_customer;

CREATE VIEW products_with_customer AS
SELECT p.*, c.cust_name, c.cust_address, c.note AS cust_note
FROM products p
LEFT JOIN customers c ON c.cust_code = p.cust_code;

-- เลขม้วนงานพิมพ์ควรแยกตามขั้นตอนด้วย inbound_type
-- เช่น ม้วนก่อนพิมพ์ #1 และม้วนหลังพิมพ์ #1 ต้องอยู่ร่วม WO/Lot เดียวกันได้
DROP INDEX IF EXISTS uniq_production_rolls_lot_wo_rollno;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_production_rolls_lot_wo_rollno
  ON production_rolls (
    machine_no,
    lot_no,
    COALESCE(work_order, ''),
    roll_no,
    roll_type,
    COALESCE(inbound_type, '')
  )
  WHERE roll_type IN ('good','bad') AND roll_no > 0;
