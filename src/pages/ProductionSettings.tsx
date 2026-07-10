import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { ArrowLeft, Boxes, CheckCircle2, FileEdit, Loader2, Printer, Scale, Settings } from 'lucide-react'
import { fetchFlag, fetchSetting, setFlag, setSetting } from './Admin'
import LabelDesigner from './LabelDesigner'
import ProductsPage from './Products'

function ToggleRow({
  title,
  description,
  enabled,
  onChange,
  icon,
}: {
  title: string
  description: string
  enabled: boolean
  onChange: (value: boolean) => void
  icon: ReactNode
}) {
  return (
    <button
      onClick={() => onChange(!enabled)}
      className={`w-full rounded-3xl border p-5 text-left transition-all ${
        enabled
          ? 'border-green-500/50 bg-green-500/10'
          : 'border-slate-700 bg-slate-900 hover:border-slate-500'
      }`}
    >
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-start gap-4">
          <div className={`rounded-2xl p-3 ${enabled ? 'bg-green-500/20 text-green-300' : 'bg-slate-800 text-slate-400'}`}>
            {icon}
          </div>
          <div>
            <p className="text-white text-xl font-black">{title}</p>
            <p className="text-slate-400 text-sm mt-1">{description}</p>
          </div>
        </div>
        <div className={`w-16 h-9 rounded-full p-1 transition-colors ${enabled ? 'bg-green-500' : 'bg-slate-700'}`}>
          <div className={`h-7 w-7 rounded-full bg-white transition-transform ${enabled ? 'translate-x-7' : ''}`} />
        </div>
      </div>
      <p className={`mt-4 text-sm font-bold ${enabled ? 'text-green-300' : 'text-slate-500'}`}>
        {enabled ? 'เปิดอยู่' : 'ปิดอยู่'}
      </p>
    </button>
  )
}

export default function ProductionSettings() {
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [fakeKgEnabled, setFakeKgEnabled] = useState(false)
  const [printLabelEnabled, setPrintLabelEnabled] = useState(true)
  const [showLabelDesigner, setShowLabelDesigner] = useState(false)
  const [showProducts, setShowProducts] = useState(false)

  useEffect(() => {
    let alive = true
    async function load() {
      setLoading(true)
      try {
        const [fakeKg, printLabelValue] = await Promise.all([
          fetchFlag('enable_test_random'),
          fetchSetting('print_labels_enabled'),
        ])
        if (!alive) return
        setFakeKgEnabled(fakeKg)
        setPrintLabelEnabled(printLabelValue !== '0')
      } finally {
        if (alive) setLoading(false)
      }
    }
    load()
    return () => { alive = false }
  }, [])

  async function updateFakeKg(value: boolean) {
    setFakeKgEnabled(value)
    setSaving(true)
    setSaved(false)
    try {
      await setFlag('enable_test_random', value)
      setSaved(true)
    } catch (error: any) {
      setFakeKgEnabled(!value)
      alert('บันทึกตั้งค่าเฟคกิโลไม่สำเร็จ: ' + (error?.message ?? error))
    } finally {
      setSaving(false)
      window.setTimeout(() => setSaved(false), 1600)
    }
  }

  async function updatePrintLabel(value: boolean) {
    setPrintLabelEnabled(value)
    setSaving(true)
    setSaved(false)
    try {
      await setSetting('print_labels_enabled', value ? '1' : '0')
      setSaved(true)
    } catch (error: any) {
      setPrintLabelEnabled(!value)
      alert('บันทึกตั้งค่าใบปะหน้าไม่สำเร็จ: ' + (error?.message ?? error))
    } finally {
      setSaving(false)
      window.setTimeout(() => setSaved(false), 1600)
    }
  }

  if (showLabelDesigner) {
    return (
      <div className="h-[calc(100vh-48px)] bg-[#0a0f1e] flex flex-col">
        <div className="flex items-center gap-3 px-5 py-3 border-b border-slate-800 bg-slate-900 shrink-0">
          <button onClick={() => setShowLabelDesigner(false)}
            className="flex items-center gap-1.5 text-slate-300 hover:text-white text-sm font-bold">
            <ArrowLeft size={16} /> กลับตั้งค่า
          </button>
          <span className="text-slate-600">|</span>
          <p className="text-white font-black flex items-center gap-1.5"><FileEdit size={16} className="text-brand-300" /> ออกแบบใบลาเบล</p>
        </div>
        <div className="flex-1 overflow-auto">
          <LabelDesigner />
        </div>
      </div>
    )
  }

  if (showProducts) {
    return (
      <div className="h-[calc(100vh-48px)] bg-[#0a0f1e] flex flex-col">
        <div className="flex items-center gap-3 px-5 py-3 border-b border-slate-800 bg-slate-900 shrink-0">
          <button onClick={() => setShowProducts(false)}
            className="flex items-center gap-1.5 text-slate-300 hover:text-white text-sm font-bold">
            <ArrowLeft size={16} /> กลับตั้งค่า
          </button>
          <span className="text-slate-600">|</span>
          <p className="text-white font-black flex items-center gap-1.5"><Boxes size={16} className="text-brand-300" /> คลังข้อมูล (สินค้า / ลูกค้า)</p>
        </div>
        <div className="flex-1 overflow-auto">
          <ProductsPage />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-[calc(100vh-48px)] bg-[#0a0f1e] p-5">
      <div className="max-w-4xl mx-auto space-y-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-white text-2xl md:text-3xl font-black flex items-center gap-2">
              <Settings className="text-brand-300" size={28} /> ตั้งค่า
            </h1>
            <p className="text-slate-400 text-sm mt-1">หน้านี้เข้าได้ด้วยรหัสเท่านั้น</p>
          </div>
          <div className="min-w-24 text-right">
            {loading && <span className="inline-flex items-center gap-1 text-slate-400 text-sm"><Loader2 size={14} className="animate-spin" /> โหลด</span>}
            {saving && <span className="inline-flex items-center gap-1 text-amber-300 text-sm"><Loader2 size={14} className="animate-spin" /> บันทึก</span>}
            {saved && !saving && <span className="inline-flex items-center gap-1 text-green-300 text-sm"><CheckCircle2 size={14} /> บันทึกแล้ว</span>}
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4">
          <ToggleRow
            title="เฟคจำนวนกิโล"
            description="เปิดแล้วหน้า ชั่ง จะมีปุ่มสุ่มค่าทดสอบ ใช้ตอนทดลองระบบเท่านั้น"
            enabled={fakeKgEnabled}
            onChange={updateFakeKg}
            icon={<Scale size={28} />}
          />
          <ToggleRow
            title="พิมพ์ใบปะหน้า"
            description="เปิดแล้วชั่งเสร็จจะพิมพ์ใบปะหน้าอัตโนมัติ ปิดแล้วบันทึกน้ำหนักอย่างเดียว"
            enabled={printLabelEnabled}
            onChange={updatePrintLabel}
            icon={<Printer size={28} />}
          />
          <button onClick={() => setShowLabelDesigner(true)}
            className="w-full rounded-3xl border border-slate-700 bg-slate-900 hover:border-brand-500 p-5 text-left transition-all">
            <div className="flex items-center gap-4">
              <div className="rounded-2xl p-3 bg-slate-800 text-brand-300">
                <FileEdit size={28} />
              </div>
              <div>
                <p className="text-white text-xl font-black">ออกแบบใบลาเบล</p>
                <p className="text-slate-400 text-sm mt-1">แก้ตำแหน่ง/ฟิลด์ใบปะหน้า (ใบสั้น 76×76) และใบเศษ</p>
              </div>
            </div>
          </button>
          <button onClick={() => setShowProducts(true)}
            className="w-full rounded-3xl border border-slate-700 bg-slate-900 hover:border-brand-500 p-5 text-left transition-all">
            <div className="flex items-center gap-4">
              <div className="rounded-2xl p-3 bg-slate-800 text-brand-300">
                <Boxes size={28} />
              </div>
              <div>
                <p className="text-white text-xl font-black">คลังข้อมูล (สินค้า / ลูกค้า)</p>
                <p className="text-slate-400 text-sm mt-1">เพิ่ม/แก้ไขสินค้า · ตั้ง Barcode No. · นำเข้า Excel</p>
              </div>
            </div>
          </button>
        </div>
      </div>
    </div>
  )
}
