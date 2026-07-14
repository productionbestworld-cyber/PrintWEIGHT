import { useEffect, useMemo, useState } from 'react'
import { BriefcaseBusiness, RefreshCw, Save, Search, Wand2 } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { fetchCustomers, fetchProducts, type Customer, type Product } from './Products'

type Job = {
  id?: string
  status?: string
  sale_order?: string
  work_order: string
  lot_no: string
  print_machine?: string
  slit_machine?: string
  customer?: string
  cust_code?: string
  cust_branch?: string
  item_code?: string
  mat_code?: string
  product_code?: string
  product_name?: string
  width_cm?: string
  width_unit?: string
  thick_mc?: string
  core_weight?: string
  length?: string
  pcs?: string
  planned_qty?: string
  delivery_date?: string
  note?: string
  created_by?: string
  header_text?: string   // ชื่อบริษัทบนใบปะหน้า (เว้นว่าง = ใช้ชื่อปกติ เบสท์เวิลด์ฯ)
}

const emptyJob: Job = {
  status: 'open',
  sale_order: '',
  work_order: '',
  lot_no: '',
  print_machine: 'P1',
  slit_machine: '',
  customer: '',
  cust_code: '',
  item_code: '',
  product_name: '',
  planned_qty: '',
  delivery_date: '',
  note: '',
  header_text: '',
}

const PRINT_MACHINES = ['P1', 'P2', 'P3']
const SLIT_MACHINES = ['SL1', 'SL2', 'SL3', 'SL4']

// ชื่อบริษัทบนใบปะหน้า — งานบางตัวต้องพิมพ์ในนามบริษัทอื่น (private label)
// value ว่าง = ใช้ชื่อปกติ (บริษัท เบสท์เวิลด์ อินเตอร์พลาส จำกัด)
const COMPANY_OPTIONS = [
  { value: '', label: 'บริษัท เบสท์เวิลด์ อินเตอร์พลาส จำกัด (ปกติ)' },
  { value: 'บริษัท แอดวานซ์ โนเลดจ์ เซอร์วิสเซส จำกัด', label: 'บริษัท แอดวานซ์ โนเลดจ์ เซอร์วิสเซส จำกัด (C0012)' },
  { value: 'บริษัท เจ.เอส. อุตสาหกรรมพลาสติก จำกัด', label: 'บริษัท เจ.เอส. อุตสาหกรรมพลาสติก จำกัด (C0013)' },
]

function lotYearMonth(dateText?: string) {
  const date = dateText ? new Date(`${dateText}T00:00:00`) : new Date()
  const buddhistYear = date.getFullYear() + 543
  const yy = String(buddhistYear).slice(-2)
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  return { yy, mm }
}

function cleanProductCode(code?: string) {
  return (code ?? '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
}

// เครื่องสลิตไม่บังคับตอนตั้งงาน → ถ้ายังไม่เลือก จะได้ "lot ยังไม่ครบ" ใส่ __ แทน SL#
// เช่น 69__P1TC00107 · เมื่อเลือกเครื่องสลิตตอนชั่งสลิต จะเติม SL# ให้ครบเป็น 69SL1P1TC00107
function genLotNo(job: Job) {
  const productCode = cleanProductCode(job.product_code || job.item_code)
  if (!job.print_machine || !productCode) return ''
  const { yy, mm } = lotYearMonth(job.delivery_date)
  const slit = (job.slit_machine || '').trim() || '__'
  return `${yy}${slit}${job.print_machine}${productCode}${mm}`
}

function withAutoLot(prev: Job, next: Job) {
  const oldAuto = genLotNo(prev)
  const nextAuto = genLotNo(next)
  if (!nextAuto) return next
  const currentLot = (prev.lot_no ?? '').trim()
  if (!currentLot || currentLot === oldAuto) return { ...next, lot_no: nextAuto }
  return next
}

export default function JobsPage() {
  const [customers, setCustomers] = useState<Customer[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [jobs, setJobs] = useState<Job[]>([])
  const [form, setForm] = useState<Job>(emptyJob)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [q, setQ] = useState('')

  async function reload() {
    setLoading(true)
    const [cs, ps, js] = await Promise.all([
      fetchCustomers(),
      fetchProducts(),
      supabase.from('production_jobs').select('*').order('created_at', { ascending: false }).limit(200),
    ])
    setCustomers(cs)
    setProducts(ps)
    setJobs((js.data ?? []) as Job[])
    setLoading(false)
  }

  useEffect(() => { reload() }, [])

  const productOptions = useMemo(() => {
    const custCode = (form.cust_code ?? '').trim()
    return custCode ? products.filter(p => (p.cust_code ?? '').trim() === custCode) : products
  }, [products, form.cust_code])

  const filteredJobs = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return jobs
    return jobs.filter(j =>
      `${j.sale_order ?? ''} ${j.work_order ?? ''} ${j.lot_no ?? ''} ${j.customer ?? ''} ${j.product_name ?? ''} ${j.item_code ?? ''}`
        .toLowerCase().includes(needle))
  }, [jobs, q])

  function setCustomer(custCode: string) {
    const c = customers.find(x => x.cust_code === custCode)
    setForm(prev => withAutoLot(prev, {
      ...prev,
      cust_code: custCode,
      customer: c?.cust_name ?? '',
      item_code: '',
      mat_code: '',
      product_code: '',
      product_name: '',
      lot_no: '',
      width_cm: '',
      width_unit: 'cm',
      thick_mc: '',
      core_weight: '',
      length: '',
      pcs: '',
    }))
  }

  function setProduct(itemCode: string) {
    const p = products.find(x => x.item_code === itemCode)
    if (!p) {
      setForm(prev => ({ ...prev, item_code: itemCode }))
      return
    }
    setForm(prev => withAutoLot(prev, {
      ...prev,
      item_code: p.item_code,
      mat_code: p.mat_code ?? '',
      product_code: p.product_code ?? '',
      product_name: p.product_name ?? '',
      width_cm: p.width_cm ?? '',
      width_unit: p.width_unit ?? 'cm',
      thick_mc: p.thick_mc ?? '',
      core_weight: p.core_weight ?? '',
      length: p.length ?? '',
      pcs: p.pcs ?? '',
      cust_code: p.cust_code ?? prev.cust_code,
      customer: p.cust_name ?? prev.customer,
    }))
  }

  function applyAutoLot() {
    const lot = genLotNo(form)
    if (!lot) {
      alert('เลือกเครื่องสลิท / เครื่องพิมพ์ / สินค้าก่อน แล้วระบบจะเจน Lot ให้')
      return
    }
    setForm(prev => ({ ...prev, lot_no: lot }))
  }

  function editJob(job: Job) {
    setForm({
      ...emptyJob,
      ...job,
      delivery_date: job.delivery_date ? String(job.delivery_date).slice(0, 10) : '',
    })
  }

  async function saveJob() {
    if (!form.work_order?.trim()) { alert('กรุณากรอก WO'); return }
    const autoLot = form.lot_no?.trim() || genLotNo(form)
    if (!autoLot) { alert('กรุณาเลือกเครื่องสลิท / เครื่องพิมพ์ / สินค้า เพื่อสร้าง Lot'); return }
    if (!form.item_code?.trim()) { alert('กรุณาเลือกสินค้า'); return }
    setSaving(true)
    const payload = {
      status: form.status || 'open',
      sale_order: form.sale_order?.trim() || null,
      work_order: form.work_order.trim(),
      lot_no: autoLot,
      print_machine: form.print_machine?.trim() || null,
      slit_machine: form.slit_machine?.trim() || null,
      customer: form.customer?.trim() || null,
      cust_code: form.cust_code?.trim() || null,
      cust_branch: form.cust_branch?.trim() || null,
      item_code: form.item_code?.trim() || null,
      mat_code: form.mat_code?.trim() || null,
      product_code: form.product_code?.trim() || null,
      product_name: form.product_name?.trim() || null,
      width_cm: form.width_cm?.trim() || null,
      width_unit: form.width_unit || 'cm',
      thick_mc: form.thick_mc?.trim() || null,
      core_weight: form.core_weight?.trim() || null,
      length: form.length?.trim() || null,
      pcs: form.pcs?.trim() || null,
      planned_qty: form.planned_qty?.trim() || null,
      delivery_date: form.delivery_date || null,
      note: form.note?.trim() || null,
      created_by: form.created_by?.trim() || null,
      // ใส่เฉพาะเมื่อมีค่า → งานปกติไม่ส่ง key นี้ (ไม่ต้องมีคอลัมน์ก็ตั้งงานได้)
      ...(form.header_text?.trim() ? { header_text: form.header_text.trim() } : {}),
    }
    const req = form.id
      ? supabase.from('production_jobs').update(payload).eq('id', form.id)
      : supabase.from('production_jobs').insert(payload)
    const { error } = await req
    setSaving(false)
    if (error) { alert('บันทึกงานไม่สำเร็จ: ' + error.message); return }
    setForm(emptyJob)
    await reload()
  }

  return (
    <div className="min-h-[calc(100vh-48px)] bg-[#0a0f1e] p-5">
      <div className="max-w-7xl mx-auto space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-white text-xl font-black flex items-center gap-2">
              <BriefcaseBusiness size={22} className="text-brand-400" />
              ตั้งงานผลิต
            </h1>
            <p className="text-slate-400 text-xs mt-1">ตั้ง SO / WO / Lot ก่อนชั่ง แล้วเลือกสินค้าเป็นดรอปดาวจากฐานข้อมูล</p>
          </div>
          <button onClick={reload} className="bg-slate-800 hover:bg-slate-700 text-slate-300 px-3 py-2 rounded-lg text-sm flex items-center gap-1.5">
            <RefreshCw size={14}/> รีเฟรช
          </button>
        </div>

        <div className="grid grid-cols-1 xl:grid-cols-[440px_1fr] gap-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-4 space-y-3">
            <p className="text-white font-bold">{form.id ? 'แก้ไขงาน' : 'สร้างงานใหม่'}</p>
            <div className="grid grid-cols-2 gap-3">
              <Input label="SO" value={form.sale_order ?? ''} onChange={v => setForm(p => ({ ...p, sale_order: v }))} />
              <Input label="WO *" value={form.work_order ?? ''} onChange={v => setForm(p => ({ ...p, work_order: v }))} />
              <Select label="เครื่องพิมพ์ *" value={form.print_machine ?? ''} options={PRINT_MACHINES} onChange={v => setForm(p => withAutoLot(p, { ...p, print_machine: v }))} />
              <label className="block">
                <span className="text-[10px] text-slate-500 font-bold">เครื่องสลิท (เลือกตอนชั่งสลิตได้)</span>
                <select value={form.slit_machine ?? ''} onChange={e => setForm(p => withAutoLot(p, { ...p, slit_machine: e.target.value }))}
                  className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm">
                  <option value="">— ยังไม่กำหนด (เลือกตอนชั่งสลิต) —</option>
                  {SLIT_MACHINES.map(m => <option key={m} value={m}>{m}</option>)}
                </select>
              </label>
              <label className="block col-span-2">
                <span className="text-[10px] text-slate-500 font-bold">Lot *</span>
                <div className="mt-1 flex gap-2">
                  <input value={form.lot_no ?? ''} onChange={e => setForm(p => ({ ...p, lot_no: e.target.value.toUpperCase() }))}
                    placeholder="กดเจน Lot"
                    className="flex-1 bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm font-mono" />
                  <button type="button" onClick={applyAutoLot}
                    className="bg-emerald-600 hover:bg-emerald-500 text-white px-3 rounded-xl text-xs font-bold flex items-center gap-1.5">
                    <Wand2 size={14}/> เจน
                  </button>
                </div>
                <p className="text-[10px] text-slate-500 mt-1">สูตร: ปี + (เครื่องสลิท) + เครื่องพิมพ์ + รหัสสินค้า + เดือน · ยังไม่เลือกสลิต = lot ยังไม่ครบ 69__P1TC00107 → เติมเป็น 69SL1P1TC00107 ตอนชั่งสลิต</p>
              </label>
              <Input label="จำนวนสั่ง Kg" value={form.planned_qty ?? ''} onChange={v => setForm(p => ({ ...p, planned_qty: v }))} />
            </div>
            <label className="block">
              <span className="text-[10px] text-slate-500 font-bold">ลูกค้า</span>
              <select value={form.cust_code ?? ''} onChange={e => setCustomer(e.target.value)}
                className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm">
                <option value="">-- เลือกลูกค้า --</option>
                {customers.map(c => <option key={c.cust_code} value={c.cust_code}>{c.cust_name}</option>)}
              </select>
            </label>
            <label className="block">
              <span className="text-[10px] text-slate-500 font-bold">สินค้า / Item Code *</span>
              <select value={form.item_code ?? ''} onChange={e => setProduct(e.target.value)}
                className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm">
                <option value="">-- เลือกสินค้า --</option>
                {productOptions.map(p => (
                  <option key={p.item_code} value={p.item_code}>{p.item_code} · {p.product_name}</option>
                ))}
              </select>
            </label>
            <div className="grid grid-cols-2 gap-3">
              <Input label="Mat Code" value={form.mat_code ?? ''} onChange={v => setForm(p => ({ ...p, mat_code: v }))} />
              <Input label="รหัสสินค้า" value={form.product_code ?? ''} onChange={v => setForm(p => ({ ...p, product_code: v }))} />
              <Input label="หน้ากว้าง" value={form.width_cm ?? ''} onChange={v => setForm(p => ({ ...p, width_cm: v }))} />
              <Input label="หนา mc" value={form.thick_mc ?? ''} onChange={v => setForm(p => ({ ...p, thick_mc: v }))} />
              <Input label="นน.แกน" value={form.core_weight ?? ''} onChange={v => setForm(p => ({ ...p, core_weight: v }))} />
              <Input label="ความยาว" value={form.length ?? ''} onChange={v => setForm(p => ({ ...p, length: v }))} />
              <Input label="วันส่ง" type="date" value={form.delivery_date ?? ''} onChange={v => setForm(p => withAutoLot(p, { ...p, delivery_date: v }))} />
              <Input label="ผู้ตั้งงาน" value={form.created_by ?? ''} onChange={v => setForm(p => ({ ...p, created_by: v }))} />
            </div>
            <label className="block">
              <span className="text-[10px] text-slate-500 font-bold">ชื่อบริษัทบนใบปะหน้า</span>
              <select value={form.header_text ?? ''} onChange={e => setForm(p => ({ ...p, header_text: e.target.value }))}
                className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm">
                {COMPANY_OPTIONS.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
              <p className="text-[10px] text-amber-300/70 mt-1">เลือกบริษัทอื่นเมื่องานนี้ต้องพิมพ์ในนามบริษัทอื่น — จะขึ้นหัวใบม้วนสลิต (ส่งลูกค้า)</p>
            </label>
            <label className="block">
              <span className="text-[10px] text-slate-500 font-bold">หมายเหตุ</span>
              <textarea value={form.note ?? ''} onChange={e => setForm(p => ({ ...p, note: e.target.value }))}
                className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm min-h-[70px]" />
            </label>
            <div className="flex gap-2">
              <button onClick={saveJob} disabled={saving}
                className="flex-1 bg-brand-600 hover:bg-brand-500 disabled:opacity-50 text-white py-3 rounded-xl font-bold flex items-center justify-center gap-2">
                <Save size={16}/> {saving ? 'กำลังบันทึก...' : 'บันทึกงาน'}
              </button>
              {form.id && (
                <button onClick={() => setForm(emptyJob)} className="px-4 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl">
                  งานใหม่
                </button>
              )}
            </div>
          </div>

          <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden">
            <div className="px-4 py-3 border-b border-slate-800 flex items-center justify-between gap-3">
              <p className="text-white font-bold">รายการงาน</p>
              <div className="relative w-80 max-w-full">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500"/>
                <input value={q} onChange={e => setQ(e.target.value)} placeholder="ค้นหา SO / WO / Lot / ลูกค้า..."
                  className="w-full bg-slate-800 border border-slate-700 rounded-xl pl-9 pr-3 py-2 text-white text-sm" />
              </div>
            </div>
            <div className="divide-y divide-slate-800">
              {loading ? <div className="p-8 text-center text-slate-500">กำลังโหลด...</div> : filteredJobs.map(j => (
                <button key={j.id} onClick={() => editJob(j)}
                  className="w-full text-left px-4 py-3 hover:bg-slate-800/60 transition-colors">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-white font-bold">{j.product_name || 'ไม่ระบุสินค้า'}</p>
                      <p className="text-slate-400 text-xs mt-0.5">
                        {j.customer || 'ไม่ระบุลูกค้า'} · Lot <span className="font-mono">{j.lot_no}</span>
                        {(j.slit_machine || j.print_machine) && <span> · {j.slit_machine || '-'} / {j.print_machine || '-'}</span>}
                      </p>
                    </div>
                    <div className="text-right text-xs">
                      <p><span className="text-amber-300 font-bold">SO</span> <span className="text-slate-300">{j.sale_order || '—'}</span></p>
                      <p><span className="text-orange-300 font-bold">WO</span> <span className="text-slate-300">{j.work_order}</span></p>
                    </div>
                  </div>
                </button>
              ))}
              {!loading && filteredJobs.length === 0 && <div className="p-8 text-center text-slate-500">ยังไม่มีงาน</div>}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function Select({ label, value, options, onChange }: {
  label: string
  value: string
  options: string[]
  onChange: (v: string) => void
}) {
  return (
    <label className="block">
      <span className="text-[10px] text-slate-500 font-bold">{label}</span>
      <select value={value} onChange={e => onChange(e.target.value)}
        className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm">
        {options.map(option => <option key={option} value={option}>{option}</option>)}
      </select>
    </label>
  )
}

function Input({ label, value, onChange, type = 'text' }: {
  label: string
  value: string
  onChange: (v: string) => void
  type?: string
}) {
  return (
    <label className="block">
      <span className="text-[10px] text-slate-500 font-bold">{label}</span>
      <input type={type} value={value} onChange={e => onChange(e.target.value)}
        className="mt-1 w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm" />
    </label>
  )
}
