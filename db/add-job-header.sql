-- ════════════════════════════════════════════════════════════════════════
--  เพิ่ม "ชื่อบริษัทบนใบปะหน้า" ต่องาน (header_text)
--  บางงานต้องพิมพ์ในนามบริษัทอื่น → ตั้งชื่อบริษัทตอน "ตั้งงาน"
--  รันใน Supabase SQL Editor (idempotent — รันซ้ำได้)
-- ════════════════════════════════════════════════════════════════════════

-- ตั้งค่าตอนตั้งงาน (ต่อ 1 งาน)
ALTER TABLE production_jobs  ADD COLUMN IF NOT EXISTS header_text TEXT;

-- เก็บติดม้วน → รีปริ้นใบปะหน้าได้ชื่อบริษัทเดิม
ALTER TABLE production_rolls ADD COLUMN IF NOT EXISTS header_text TEXT;
