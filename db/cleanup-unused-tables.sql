-- ════════════════════════════════════════════════════════════════════════
--  BWP แผนกพิมพ์ — ลบตารางที่ไม่ใช้ (cleanup)
--  รันใน Supabase SQL Editor (project: vmvpnjgwdbbqrszxiapt)
--
--  ทั้ง 3 ตารางว่างเปล่า (0 แถว) และไม่มีฟีเจอร์ในแอปใช้จริง:
--   • production_records — legacy aux "สร้างเผื่อโค้ดอ้าง" (ไม่มีโค้ดอ้าง)
--   • machine_job_log    — legacy aux เดียวกัน (ไม่มีโค้ดอ้าง)
--   • sales_orders       — ฟีเจอร์ SO ไม่ได้ทำ (เดิมถูกอ้างแค่ใน backup list — เอาออกแล้ว)
-- ════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS
  production_records,
  machine_job_log,
  sales_orders
CASCADE;

-- เช็กตารางที่เหลือ
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
