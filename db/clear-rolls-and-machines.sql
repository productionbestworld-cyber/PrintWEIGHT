-- ════════════════════════════════════════════════════════════════════════
--  ล้างข้อมูลม้วน + การตั้งเครื่อง (เตรียมใช้งานจริง)
--  รันใน Supabase SQL Editor (service role → DELETE ตรงได้ ไม่ติด RLS)
--  ไม่แตะ: customers, products (master ลูกค้า/สินค้า)
-- ════════════════════════════════════════════════════════════════════════

-- 1) ม้วนที่ชั่งไปแล้วทั้งหมด + log ที่เกี่ยวข้อง
DELETE FROM production_rolls;
DELETE FROM weigh_logs;
DELETE FROM roll_deletion_logs;
DELETE FROM transfer_documents;
DELETE FROM parked_jobs;
DELETE FROM job_summaries;
DELETE FROM rework_withdrawals;

-- 2) เครื่องที่ตั้งค่าไว้ (machine_profiles) — ลบทั้งแถว
--    เครื่องจะกลับไปว่าง ต้องตั้งค่าใหม่ตอนเข้าใช้งานครั้งถัดไป
DELETE FROM machine_profiles;

-- 3) งานที่ตั้งไว้ (production_jobs) — เอาคอมเมนต์ -- ออกถ้าต้องการล้างงานด้วย
-- DELETE FROM production_jobs;

-- ── ตรวจสอบหลังลบ ──────────────────────────────────────────────────────
SELECT 'production_rolls' AS tbl, COUNT(*) FROM production_rolls
UNION ALL SELECT 'weigh_logs', COUNT(*) FROM weigh_logs
UNION ALL SELECT 'machine_profiles', COUNT(*) FROM machine_profiles
UNION ALL SELECT 'production_jobs', COUNT(*) FROM production_jobs
UNION ALL SELECT 'customers (ต้องไม่หาย)', COUNT(*) FROM customers
UNION ALL SELECT 'products (ต้องไม่หาย)', COUNT(*) FROM products;
