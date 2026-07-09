import { useEffect, useMemo, useState } from 'react'
import { Boxes, RefreshCw, Search } from 'lucide-react'
import { supabase, fetchAll } from '../lib/supabase'

// ── กล่องม้วนพักไว้ (Held Rolls) ─────────────────────────────────────────────
// เก็บม้วน 3 ชนิดที่ "ยังไม่จบ" — เมตรไม่ถึง / แก้ไข / NCR — จัดกลุ่มตาม WO → สินค้า
// เบิกไปแก้แล้วชั่งเป็น WO ใหม่ ที่หน้า "ชั่ง" (ม้วนที่เบิกแล้วจะหายจากกล่องนี้)

type Dept = 'blow' | 'print' | 'rewind'

const HELD_INBOUND = ['short_meter', 'internal', 'ncr'] as const

// ชนิดม้วนพักไว้ + สี/ป้าย
function heldKind(r: any): { key: 'short_meter' | 'rework' | 'ncr'; label: string; tone: string } {
  if (r.inbound_type === 'short_meter') return { key: 'short_meter', label: 'เมตรไม่ถึง', tone: 'text-cyan-300 border-cyan-500/40 bg-cyan-500/10' }
  if (r.inbound_type === 'ncr')         return { key: 'ncr',        label: 'NCR',        tone: 'text-purple-300 border-purple-500/40 bg-purple-500/10' }
  return { key: 'rework', label: 'แก้ไข', tone: 'text-orange-300 border-orange-500/40 bg-orange-500/10' }
}

const fmt = (n: number) => (n ?? 0).toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export default function HeldRolls({ dept }: { dept?: Dept }) {
  const [rolls, setRolls] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [q, setQ] = useState('')
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({})
  // งานที่เปิดอยู่ (ใช้ตอนเบิก — ต้องเลือกงานที่ชั่งสินค้าตัวเดียวกัน)
  const [openJobs, setOpenJobs] = useState<any[]>([])
  const [withdrawRoll, setWithdrawRoll] = useState<any | null>(null)
  const [withdrawBy, setWithdrawBy] = useState('')
  const [targetJobId, setTargetJobId] = useState('')
  const [saving, setSaving] = useState(false)

  async function load() {
    setLoading(true)
    const [data, jobs] = await Promise.all([
      fetchAll(() => {
        let query = supabase.from('production_rolls')
          .select('id, roll_no, roll_type, inbound_type, weight, work_order, sale_order, lot_no, item_code, product_name, customer, review_status, rework_status, remark, machine_no, created_at')
          .eq('transferred', false)
          .in('inbound_type', HELD_INBOUND as unknown as string[])
          .order('created_at', { ascending: false })
        if (dept) query = query.or(`section.eq.${dept},section.is.null`)
        return query
      }),
      supabase.from('production_jobs').select('id, work_order, sale_order, lot_no, item_code, product_name, customer, print_machine, slit_machine')
        .neq('status', 'closed').order('created_at', { ascending: false }).limit(200)
        .then(({ data }) => data ?? []),
    ])
    // เอาเฉพาะที่ยังอยู่ในกล่อง — ตัด 'reworked' (ใช้ไปแล้ว) และ 'withdrawn' (เบิกไปงานแล้ว) ออก
    setRolls((data ?? []).filter((r: any) => r.rework_status !== 'reworked' && r.rework_status !== 'withdrawn'))
    setOpenJobs(jobs)
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  // งานที่เลือกเบิกเข้าได้ = งานที่กำลังชั่ง "สินค้าตัวเดียวกัน" กับม้วนที่จะเบิก
  const eligibleJobs = useMemo(
    () => withdrawRoll ? openJobs.filter(j => (j.item_code ?? '') === (withdrawRoll.item_code ?? '')) : [],
    [openJobs, withdrawRoll])

  function openWithdraw(roll: any) {
    setWithdrawRoll(roll)
    setWithdrawBy('')
    setTargetJobId('')
  }

  async function confirmWithdraw() {
    if (!withdrawRoll) return
    if (!withdrawBy.trim()) { alert('กรอกชื่อผู้เบิกก่อน'); return }
    if (!targetJobId) { alert('เลือกงานปลายทาง (งานที่กำลังชั่งสินค้าตัวนี้)'); return }
    setSaving(true)
    const { error } = await supabase.from('production_rolls').update({
      rework_status: 'withdrawn',
      rework_received_by: withdrawBy.trim(),
      rework_received_at: new Date().toISOString(),
      withdrawn_to_job_id: targetJobId,
    }).eq('id', withdrawRoll.id)
    setSaving(false)
    if (error) { alert('เบิกไม่สำเร็จ: ' + error.message); return }
    const job = openJobs.find(j => j.id === targetJobId)
    alert(`✓ เบิกม้วน #${withdrawRoll.roll_no} ไปงาน WO ${job?.work_order ?? ''} แล้ว — ไปชั่งแก้ที่หน้า "ชั่ง"`)
    setWithdrawRoll(null)
    load()
  }

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return rolls
    return rolls.filter(r =>
      `${r.work_order ?? ''} ${r.sale_order ?? ''} ${r.item_code ?? ''} ${r.product_name ?? ''} ${r.customer ?? ''} ${r.lot_no ?? ''}`
        .toLowerCase().includes(needle))
  }, [rolls, q])

  // จัดกลุ่ม WO → สินค้า (item_code)
  const groups = useMemo(() => {
    const map = new Map<string, { wo: string; item: string; productName: string; customer: string; rows: any[] }>()
    for (const r of filtered) {
      const key = `${r.work_order ?? '—'}__${r.item_code ?? '—'}`
      if (!map.has(key)) map.set(key, {
        wo: r.work_order ?? '—', item: r.item_code ?? '—',
        productName: r.product_name ?? '', customer: r.customer ?? '', rows: [],
      })
      map.get(key)!.rows.push(r)
    }
    return Array.from(map.entries()).map(([key, g]) => ({ key, ...g }))
  }, [filtered])

  const totalKg = filtered.reduce((s, r) => s + (r.weight ?? 0), 0)

  return (
    <div className="min-h-[calc(100vh-48px)] bg-[#0a0f1e] p-5">
      <div className="max-w-5xl mx-auto space-y-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-white text-2xl md:text-3xl font-black flex items-center gap-2">
              <Boxes className="text-cyan-300" size={28} /> ม้วนพักไว้
            </h1>
            <p className="text-slate-400 text-sm mt-1">ม้วนเมตรไม่ถึง / แก้ไข / NCR ที่รอเบิกไปทำต่อ — จัดกลุ่มตาม WO → สินค้า</p>
          </div>
          <button onClick={load}
            className="flex items-center gap-1.5 rounded-xl border border-slate-700 bg-slate-900 px-4 py-2 text-sm font-bold text-slate-300 hover:border-brand-500 hover:text-white transition-colors">
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> รีเฟรช
          </button>
        </div>

        <div className="flex items-center gap-2 rounded-2xl border border-slate-700 bg-slate-900 px-4 py-2.5">
          <Search size={16} className="text-slate-500 shrink-0" />
          <input value={q} onChange={e => setQ(e.target.value)}
            placeholder="ค้นหา WO / SO / สินค้า / ลูกค้า / Lot..."
            className="flex-1 bg-transparent text-white text-sm outline-none placeholder:text-slate-600" />
          <span className="text-xs text-slate-500 shrink-0">{filtered.length} ม้วน · {fmt(totalKg)} Kg</span>
        </div>

        {loading ? (
          <p className="text-center py-16 text-slate-500">กำลังโหลด...</p>
        ) : groups.length === 0 ? (
          <div className="rounded-3xl border border-slate-800 bg-slate-900/50 p-10 text-center">
            <p className="text-slate-400 font-bold">ยังไม่มีม้วนพักไว้</p>
            <p className="text-slate-600 text-sm mt-1">ม้วนเมตรไม่ถึง / แก้ไข / NCR ที่ชั่งไว้จะมาโผล่ที่นี่</p>
          </div>
        ) : (
          <div className="space-y-3">
            {groups.map(g => {
              const open = openGroups[g.key] ?? false
              const kinds = ['short_meter', 'rework', 'ncr'].map(k => {
                const rs = g.rows.filter((r: any) => heldKind(r).key === k)
                return { k, rows: rs, kg: rs.reduce((s: number, r: any) => s + (r.weight ?? 0), 0), info: rs[0] ? heldKind(rs[0]) : null }
              }).filter(x => x.rows.length > 0)
              const groupKg = g.rows.reduce((s: number, r: any) => s + (r.weight ?? 0), 0)
              return (
                <div key={g.key} className="rounded-2xl border border-slate-700 bg-slate-900 overflow-hidden">
                  <button onClick={() => setOpenGroups(prev => ({ ...prev, [g.key]: !open }))}
                    className="w-full flex items-center justify-between gap-3 px-4 py-3 text-left hover:bg-slate-800/50 transition-colors">
                    <div className="min-w-0">
                      <p className="text-white font-bold text-sm truncate">
                        <span className="text-amber-300">WO {g.wo}</span>
                        <span className="text-slate-500 font-normal"> · </span>
                        <span className="font-mono text-brand-300">{g.item}</span>
                      </p>
                      <p className="text-slate-400 text-xs truncate mt-0.5">{g.productName || g.customer || '—'}</p>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      {['short_meter', 'rework', 'ncr'].map(k => {
                        const rs = g.rows.filter((r: any) => heldKind(r).key === k)
                        if (!rs.length) return null
                        const info = heldKind(rs[0])
                        return (
                          <span key={k} className={`text-[11px] font-bold px-2 py-1 rounded-lg border ${info.tone}`}>
                            {info.label} {rs.length}
                          </span>
                        )
                      })}
                      <span className="text-slate-300 text-sm font-black w-24 text-right">{fmt(groupKg)} Kg</span>
                      <span className="text-slate-500 text-xs">{open ? '▲' : '▼'}</span>
                    </div>
                  </button>
                  {open && (
                    <div className="border-t border-slate-800 px-4 py-3 space-y-3">
                      {kinds.map(({ k, rows, kg, info }) => (
                        <div key={k}>
                          <p className={`text-xs font-bold mb-1.5 ${info?.tone.split(' ')[0]}`}>
                            {info?.label} · {rows.length} ม้วน · {fmt(kg)} Kg
                          </p>
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                            {rows.sort((a: any, b: any) => (a.roll_no ?? 0) - (b.roll_no ?? 0)).map((r: any) => (
                              <div key={r.id} className="rounded-lg border border-slate-800 bg-slate-950 px-3 py-2">
                                <div className="flex items-center justify-between gap-2">
                                  <span className="text-white font-bold text-sm">#{r.roll_no} <span className="text-slate-500 font-normal text-xs">· Lot {r.lot_no || '—'}</span></span>
                                  <span className="text-slate-300 font-black text-sm">{fmt(r.weight ?? 0)} Kg</span>
                                </div>
                                {r.remark && <p className="text-slate-600 text-[10px] mt-0.5 truncate">{r.remark}</p>}
                                {r.inbound_type === 'ncr' && r.review_status === 'pending_review' && (
                                  <p className="text-purple-300/80 text-[10px] mt-0.5">⏳ รอ ผจก. พิจารณา</p>
                                )}
                                <button onClick={() => openWithdraw(r)}
                                  className="mt-1.5 w-full text-[11px] font-bold text-cyan-300 bg-cyan-500/10 hover:bg-cyan-500/20 border border-cyan-500/30 rounded py-1.5">
                                  📤 เบิกไปแก้/ทำต่อ
                                </button>
                              </div>
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* ── Modal เบิกม้วน ─────────────────────────────────────── */}
      {withdrawRoll && (
        <div className="fixed inset-0 z-[60] bg-black/70 flex items-center justify-center p-4" onClick={() => setWithdrawRoll(null)}>
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="px-5 py-4 border-b border-slate-800 flex items-center justify-between">
              <p className="text-white font-black">📤 เบิกม้วนไปแก้/ทำต่อ</p>
              <button onClick={() => setWithdrawRoll(null)} className="text-slate-400 hover:text-white text-xl leading-none">×</button>
            </div>
            <div className="px-5 py-4 space-y-3">
              <div className="rounded-xl border border-slate-800 bg-slate-950 px-3 py-2">
                <p className="text-white font-bold text-sm">
                  {heldKind(withdrawRoll).label} #{withdrawRoll.roll_no} · {fmt(withdrawRoll.weight ?? 0)} Kg
                </p>
                <p className="text-slate-500 text-xs mt-0.5">
                  <span className="font-mono text-brand-300">{withdrawRoll.item_code}</span> · {withdrawRoll.product_name || withdrawRoll.customer || '—'}
                </p>
                <p className="text-slate-600 text-[11px]">WO เดิม {withdrawRoll.work_order || '—'} · Lot {withdrawRoll.lot_no || '—'}</p>
              </div>

              <div>
                <label className="block text-xs text-slate-400 mb-1 font-bold">ชื่อผู้เบิก *</label>
                <input value={withdrawBy} onChange={e => setWithdrawBy(e.target.value)} placeholder="ชื่อคนเบิก..."
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-cyan-500" />
              </div>

              <div>
                <label className="block text-xs text-slate-400 mb-1 font-bold">เบิกเข้างาน (ต้องเป็นงานที่กำลังชั่งสินค้าตัวนี้) *</label>
                {eligibleJobs.length === 0 ? (
                  <p className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[12px] font-bold text-amber-200">
                    ยังไม่มีงานที่ชั่งสินค้า <span className="font-mono">{withdrawRoll.item_code}</span> อยู่ —
                    ไปตั้งงาน + เปิดชั่งสินค้านี้ก่อน แล้วค่อยเบิก
                  </p>
                ) : (
                  <div className="space-y-1.5 max-h-52 overflow-y-auto">
                    {eligibleJobs.map(j => (
                      <button key={j.id} onClick={() => setTargetJobId(j.id)}
                        className={`w-full text-left rounded-lg border px-3 py-2 transition-colors ${
                          targetJobId === j.id ? 'border-cyan-400 bg-cyan-500/20 text-white' : 'border-slate-700 bg-slate-950 text-slate-300 hover:border-cyan-500/50'
                        }`}>
                        <p className="text-sm font-bold">🖨 {j.print_machine || '—'} / {j.slit_machine || '—'} · WO {j.work_order || '—'}</p>
                        <p className="text-[11px] text-slate-500">{j.product_name || j.customer || j.lot_no}</p>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
            <div className="px-5 py-3 border-t border-slate-800 flex gap-2">
              <button onClick={() => setWithdrawRoll(null)} className="px-4 py-2.5 rounded-xl text-sm font-bold bg-slate-800 text-slate-300 hover:bg-slate-700">ยกเลิก</button>
              <button onClick={confirmWithdraw} disabled={saving || eligibleJobs.length === 0}
                className="flex-1 py-2.5 rounded-xl text-sm font-black bg-cyan-600 hover:bg-cyan-500 disabled:opacity-40 text-white">
                {saving ? 'กำลังเบิก...' : '📤 ยืนยันเบิก'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
