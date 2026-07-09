-- ให้ 1 SO มีหลาย WO ได้ และแต่ละ WO เริ่มม้วน #1 ของตัวเองได้
-- กติกาใหม่: ห้ามเลขม้วนซ้ำเฉพาะในชุด machine + lot + work_order + roll_type
-- ตัวอย่าง:
--   SO-001 / Lot A / WO-01 / ม้วน #1  = ได้
--   SO-001 / Lot A / WO-02 / ม้วน #1  = ได้
--   SO-001 / Lot A / WO-01 / ม้วน #1  = ซ้ำ ไม่ให้บันทึก

DROP INDEX IF EXISTS uniq_production_rolls_lot_rollno;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_production_rolls_lot_wo_rollno
  ON production_rolls (
    machine_no,
    lot_no,
    COALESCE(work_order, ''),
    roll_no,
    roll_type
  )
  WHERE roll_type IN ('good','bad') AND roll_no > 0;
