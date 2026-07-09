-- ลบตารางเก่าที่ไม่ใช้แล้วหลัง reset
-- ใช้เมื่อรัน reset ไปแล้ว แต่ยังเห็นตารางเก่าค้างใน Supabase Table Editor

DROP TABLE IF EXISTS
  production_roll,
  print_rolls,
  print_products,
  rework_rolls
CASCADE;

-- เช็กตารางที่เหลือ
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
