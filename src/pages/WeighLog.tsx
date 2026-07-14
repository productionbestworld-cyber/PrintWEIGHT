import { useEffect, useMemo, useState } from 'react'
import { ClipboardList, RefreshCw, Search } from 'lucide-react'
import { supabase, fetchAll } from '../lib/supabase'
import ExportButton from '../components/ExportButton'

// ── Log ชั่งจริงทั้งหมด — ทุกม้วน ทุกสเตจ (ม้วนพิมพ์/ม้วนสลิท/เมตรไม่ถึง/แก้ไข/NCR/เศษ) ──
// อ้างอิงม้วนต้นทาง: ม้วนสลิทที่เลือกม้วนพิมพ์ตอนชั่ง (rework_source_roll_id) จะ join กลับไปหาเวลา/WO/SO ของม้วนต้นทางให้

type Roll = {
  id: string
  created_at: string
  machine_no: string | null
  roll_no: number | null
  roll_type: string | null
  inbound_type: string | null
  weight: number | null
  gross_weight: number | null
  core_weight: number | null
  work_order: string | null
  sale_order: string | null
  lot_no: string | null
  customer: string | null
  item_code: string | null
  product_name: string | null
  inspector: string | null
  remark: string | null
  rework_source_roll_id: string | null
  rework_source_lot: string | null
  rework_source_weight: number | null
  job_id: string | null
}

const STAGE_LABEL: Record<string, string> = {
  input_roll: 'ม้วนก่อนพิมพ์',
  printed_jumbo: 'ม้วนพิมพ์',
  slit_roll: 'ม้วนสลิท',
  short_meter: 'เมตรไม่ถึง (พักไว้)',
  rework: 'ม้วนแก้ไข',
  ncr: 'NCR',
  scrap_print_color: 'เศษพิมพ์/เศษสี',
  scrap_glue: 'เศษกาว',
  scrap_slit_side: 'เศษข้างสลิท',
}

function stageLabel(r: Roll) {
  if (r.roll_type === 'good') return STAGE_LABEL[r.inbound_type ?? ''] ?? (r.inbound_type || 'ม้วนดี')
  if (r.roll_type === 'bad') return STAGE_LABEL[r.inbound_type ?? ''] ?? 'ม้วนแก้ไข/NCR'
  if ((r.roll_type ?? '').startsWith('scrap')) return STAGE_LABEL[r.roll_type ?? ''] ?? 'เศษ'
  return r.roll_type ?? '-'
}

function stageTone(r: Roll) {
  if (r.roll_type === 'good' && r.inbound_type === 'printed_jumbo') return 'text-purple-300 border-purple-500/30 bg-purple-500/10'
  if (r.roll_type === 'good' && r.inbound_type === 'slit_roll') return 'text-blue-300 border-blue-500/30 bg-blue-500/10'
  if (r.roll_type === 'good' && r.inbound_type === 'short_meter') return 'text-cyan-300 border-cyan-500/30 bg-cyan-500/10'
  if (r.roll_type === 'bad') return r.inbound_type === 'ncr' ? 'text-purple-300 border-purple-500/30 bg-purple-500/10' : 'text-orange-300 border-orange-500/30 bg-orange-500/10'
  if ((r.roll_type ?? '').startsWith('scrap')) return 'text-amber-300 border-amber-500/30 bg-amber-500/10'
  return 'text-slate-300 border-slate-600 bg-slate-800'
}

const fmt = (n: number | null | undefined, dec = 2) =>
  (n ?? 0).toLocaleString('th-TH', { minimumFractionDigits: dec, maximumFractionDigits: dec })

const fmtTime = (iso: string) => {
  const d = new Date(iso)
  const date = d.toLocaleDateString('th-TH', { timeZone: 'Asia/Bangkok', day: '2-digit', month: '2-digit', year: '2-digit' })
  const time = d.toLocaleTimeString('th-TH', { timeZone: 'Asia/Bangkok', hour: '2-digit', minute: '2-digit', second: '2-digit' })
  return { date, time }
}

export default function WeighLog() {
  const [rolls, setRolls] = useState<Roll[]>([])
  const [sourceMap, setSourceMap] = useState<Record<string, Roll>>({})
  const [loading, setLoading] = useState(true)
  const [q, setQ] = useState('')
  const [stageFilter, setStageFilter] = useState<'all' | 'printed_jumbo' | 'slit_roll' | 'short_meter' | 'bad' | 'scrap'>('all')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  async function load() {
    setLoading(true)
    // ⚠ ต้องสร้าง query ใหม่ทุกครั้งในนี้ (ห้าม build ไว้นอกแล้วส่งตัวแปรซ้ำ) —
    //   fetchAll ยิงหลายหน้าพร้อมกัน แต่ละหน้าเรียก makeQuery() แล้ว .range() ต่อ ถ้าใช้ query builder ตัวเดียวกัน
    //   การเรียก .range() ซ้อนกันแบบขนานจะชนกัน ทำให้ได้ผลลัพธ์ว่าง/ผิดเงียบๆ
    const data = await fetchAll<Roll>(() => {
      let query = supabase.from('production_rolls')
        .select('id, created_at, machine_no, roll_no, roll_type, inbound_type, weight, gross_weight, core_weight, work_order, sale_order, lot_no, customer, item_code, product_name, inspector, remark, rework_source_roll_id, rework_source_lot, rework_source_weight, job_id')
        .order('created_at', { ascending: false })
      if (dateFrom) query = query.gte('created_at', `${dateFrom}T00:00:00+07:00`)
      if (dateTo) query = query.lte('created_at', `${dateTo}T23:59:59+07:00`)
      return query
    })
    setRolls(data)

    // ดึงม้วนต้นทาง (ม้วนพิมพ์ที่ถูกเลือกตอนชั่งสลิท) มา join ให้เห็นเวลา/WO/SO ของต้นทางครบ
    const srcIds = [...new Set(data.map(r => r.rework_source_roll_id).filter(Boolean))] as string[]
    if (srcIds.length) {
      const { data: srcRows } = await supabase.from('production_rolls')
        .select('id, created_at, machine_no, roll_no, roll_type, inbound_type, weight, gross_weight, core_weight, work_order, sale_order, lot_no, customer, item_code, product_name, inspector, remark, rework_source_roll_id, rework_source_lot, rework_source_weight, job_id')
        .in('id', srcIds)
      const map: Record<string, Roll> = {}
      for (const s of (srcRows ?? []) as Roll[]) map[s.id] = s
      setSourceMap(map)
    } else {
      setSourceMap({})
    }
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(() => {
    let list = rolls
    if (stageFilter === 'printed_jumbo') list = list.filter(r => r.roll_type === 'good' && r.inbound_type === 'printed_jumbo')
    else if (stageFilter === 'slit_roll') list = list.filter(r => r.roll_type === 'good' && r.inbound_type === 'slit_roll')
    else if (stageFilter === 'short_meter') list = list.filter(r => r.roll_type === 'good' && r.inbound_type === 'short_meter')
    else if (stageFilter === 'bad') list = list.filter(r => r.roll_type === 'bad')
    else if (stageFilter === 'scrap') list = list.filter(r => (r.roll_type ?? '').startsWith('scrap'))

    const needle = q.trim().toLowerCase()
    if (!needle) return list
    return list.filter(r =>
      `${r.work_order ?? ''} ${r.sale_order ?? ''} ${r.lot_no ?? ''} ${r.customer ?? ''} ${r.product_name ?? ''} ${r.item_code ?? ''} ${r.machine_no ?? ''} ${r.inspector ?? ''} ${r.roll_no ?? ''}`
        .toLowerCase().includes(needle))
  }, [rolls, q, stageFilter])

  const totalKg = filtered.reduce((s, r) => s + (r.weight ?? 0), 0)

  const exportCols = [
    { header: 'เวลาชั่ง', value: (r: Roll) => { const t = fmtTime(r.created_at); return `${t.date} ${t.time}` } },
    { header: 'เครื่อง', value: (r: Roll) => r.machine_no ?? '' },
    { header: 'สเตจ', value: (r: Roll) => stageLabel(r) },
    { header: 'ม้วนที่', value: (r: Roll) => r.roll_no ?? '' },
    { header: 'นน.เต็ม', value: (r: Roll) => r.gross_weight ?? 0 },
    { header: 'นน.แกน', value: (r: Roll) => r.core_weight ?? 0 },
    { header: 'นน.สุทธิ', value: (r: Roll) => r.weight ?? 0 },
    { header: 'WO', value: (r: Roll) => r.work_order ?? '' },
    { header: 'SO', value: (r: Roll) => r.sale_order ?? '' },
    { header: 'Lot', value: (r: Roll) => r.lot_no ?? '' },
    { header: 'ลูกค้า', value: (r: Roll) => r.customer ?? '' },
    { header: 'สินค้า', value: (r: Roll) => r.product_name ?? '' },
    { header: 'ผู้ตรวจสอบ', value: (r: Roll) => r.inspector ?? '' },
    { header: 'ม้วนต้นทาง (เลขที่)', value: (r: Roll) => r.rework_source_roll_id ? (sourceMap[r.rework_source_roll_id]?.roll_no ?? '') : '' },
    { header: 'ม้วนต้นทาง (เวลาชั่ง)', value: (r: Roll) => {
        if (!r.rework_source_roll_id) return ''
        const s = sourceMap[r.rework_source_roll_id]; return s ? `${fmtTime(s.created_at).date} ${fmtTime(s.created_at).time}` : ''
      } },
    { header: 'ม้วนต้นทาง WO', value: (r: Roll) => r.rework_source_roll_id ? (sourceMap[r.rework_source_roll_id]?.work_order ?? '') : '' },
    { header: 'ม้วนต้นทาง SO', value: (r: Roll) => r.rework_source_roll_id ? (sourceMap[r.rework_source_roll_id]?.sale_order ?? '') : '' },
    { header: 'ม้วนต้นทาง Lot', value: (r: Roll) => r.rework_source_lot ?? '' },
    { header: 'ม้วนต้นทาง นน.', value: (r: Roll) => r.rework_source_weight ?? '' },
    { header: 'หมายเหตุ', value: (r: Roll) => r.remark ?? '' },
  ]

  return (
    <div className="min-h-[calc(100vh-48px)] bg-[#0a0f1e] p-5">
      <div className="max-w-7xl mx-auto space-y-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-white text-xl font-black flex items-center gap-2">
              <ClipboardList size={22} className="text-brand-400" />
              Log ชั่ง
            </h1>
            <p className="text-slate-400 text-xs mt-1">บันทึกการชั่งจริงทุกม้วน ทุกสเตจ — อ้างอิงม้วนต้นทางเมื่อเลือกไว้ตอนชั่ง</p>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={load} className="bg-slate-800 hover:bg-slate-700 text-slate-300 px-3 py-2 rounded-lg text-sm flex items-center gap-1.5">
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> รีเฟรช
            </button>
            <ExportButton rows={filtered} cols={exportCols} fileName="log-ชั่ง" sheetName="Log ชั่ง" />
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <div className="relative flex-1 min-w-[220px]">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <input value={q} onChange={e => setQ(e.target.value)}
              placeholder="ค้นหา WO / SO / Lot / ลูกค้า / สินค้า / เครื่อง / ผู้ตรวจสอบ / เลขม้วน..."
              className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-3 py-2 text-white text-sm" />
          </div>
          <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)}
            className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm" />
          <span className="text-slate-500 text-xs">ถึง</span>
          <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)}
            className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white text-sm" />
          {dateFrom || dateTo ? (
            <button onClick={() => { setDateFrom(''); setDateTo(''); }} className="text-xs text-slate-400 hover:text-white">ล้างช่วงวัน</button>
          ) : null}
        </div>

        <div className="flex flex-wrap gap-1.5">
          {[
            { key: 'all', label: 'ทั้งหมด' },
            { key: 'printed_jumbo', label: 'ม้วนพิมพ์' },
            { key: 'slit_roll', label: 'ม้วนสลิท' },
            { key: 'short_meter', label: 'เมตรไม่ถึง' },
            { key: 'bad', label: 'แก้ไข/NCR' },
            { key: 'scrap', label: 'เศษ' },
          ].map(f => (
            <button key={f.key} onClick={() => setStageFilter(f.key as any)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-colors ${
                stageFilter === f.key ? 'bg-brand-600 border-brand-500 text-white' : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
              }`}>
              {f.label}
            </button>
          ))}
          <span className="text-xs text-slate-500 ml-auto self-center">{filtered.length} รายการ · {fmt(totalKg)} Kgs.</span>
        </div>

        <div className="rounded-2xl border border-slate-800 bg-slate-900 overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="bg-slate-950/60 text-slate-500 uppercase text-[10px]">
              <tr>
                <th className="text-left px-3 py-2.5">เวลา</th>
                <th className="text-left px-3 py-2.5">เครื่อง</th>
                <th className="text-left px-3 py-2.5">สเตจ</th>
                <th className="text-right px-3 py-2.5">ม้วน</th>
                <th className="text-right px-3 py-2.5">นน.เต็ม</th>
                <th className="text-right px-3 py-2.5">นน.สุทธิ</th>
                <th className="text-left px-3 py-2.5">WO / SO</th>
                <th className="text-left px-3 py-2.5">ลูกค้า / สินค้า</th>
                <th className="text-left px-3 py-2.5">ผู้ตรวจสอบ</th>
                <th className="text-left px-3 py-2.5">ม้วนต้นทาง</th>
                <th className="text-left px-3 py-2.5">หมายเหตุ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {loading && (
                <tr><td colSpan={11} className="text-center py-10 text-slate-500">กำลังโหลด...</td></tr>
              )}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={11} className="text-center py-10 text-slate-500">ไม่พบข้อมูล</td></tr>
              )}
              {!loading && filtered.map(r => {
                const t = fmtTime(r.created_at)
                const src = r.rework_source_roll_id ? sourceMap[r.rework_source_roll_id] : null
                return (
                  <tr key={r.id} className="hover:bg-slate-800/40">
                    <td className="px-3 py-2 text-slate-300 whitespace-nowrap">
                      <div>{t.date}</div>
                      <div className="text-slate-500">{t.time}</div>
                    </td>
                    <td className="px-3 py-2 text-slate-300 font-mono">{r.machine_no || '-'}</td>
                    <td className="px-3 py-2">
                      <span className={`inline-block px-2 py-0.5 rounded-full border text-[10px] font-bold ${stageTone(r)}`}>{stageLabel(r)}</span>
                    </td>
                    <td className="px-3 py-2 text-right text-white font-bold">#{r.roll_no ?? '-'}</td>
                    <td className="px-3 py-2 text-right text-slate-400">{fmt(r.gross_weight)}</td>
                    <td className="px-3 py-2 text-right text-white font-black">{fmt(r.weight)}</td>
                    <td className="px-3 py-2 text-slate-300 whitespace-nowrap">
                      <div className="text-amber-300">{r.work_order || '—'}</div>
                      <div className="text-slate-500">{r.sale_order || '—'}</div>
                    </td>
                    <td className="px-3 py-2 text-slate-300 max-w-[220px]">
                      <div className="truncate">{r.customer || '—'}</div>
                      <div className="text-slate-500 truncate">{r.product_name || r.item_code || '—'}</div>
                    </td>
                    <td className="px-3 py-2 text-slate-300">{r.inspector || '—'}</td>
                    <td className="px-3 py-2 text-slate-400 max-w-[240px]">
                      {r.rework_source_roll_id ? (
                        src ? (
                          <div className="rounded-lg border border-purple-500/25 bg-purple-500/5 px-2 py-1">
                            <p className="text-purple-300 font-bold">#{src.roll_no} · {fmt(src.weight)} Kg</p>
                            <p className="text-slate-500">{fmtTime(src.created_at).date} {fmtTime(src.created_at).time}</p>
                            <p className="text-slate-500">WO {src.work_order || '—'} · SO {src.sale_order || '—'}</p>
                          </div>
                        ) : (
                          <p className="text-slate-500">Lot {r.rework_source_lot || '—'} · {fmt(r.rework_source_weight)} Kg</p>
                        )
                      ) : '—'}
                    </td>
                    <td className="px-3 py-2 text-slate-500 max-w-[220px] truncate" title={r.remark ?? ''}>{r.remark || '—'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
