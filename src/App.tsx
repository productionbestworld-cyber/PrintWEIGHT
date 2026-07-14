import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Boxes, BriefcaseBusiness, ClipboardList, Home, Package, Printer, Scale, Settings, Wifi, WifiOff } from 'lucide-react'
import { supabase } from './lib/supabase'
import JobsPage from './pages/Jobs'
import WeighStation from './pages/WeighStation'
import Transfer from './pages/Transfer'
import HeldRolls from './pages/HeldRolls'
import WeighLog from './pages/WeighLog'
import ProductionSettings from './pages/ProductionSettings'
import RollDetail from './pages/RollDetail'
import { PinGate as AdminPinGate, fetchSetting, isAdminUnlocked } from './pages/Admin'
import { APP_BUILD_DATE, APP_VERSION, CHANGELOG } from './version'

type Page = 'home' | 'jobs' | 'weighprint' | 'weigh' | 'transfer' | 'held' | 'log' | 'settings'
type Dept = 'print'
type ConnStatus = 'online' | 'offline' | 'checking' | 'slow'

const DEPT: Dept = 'print'

const NAV = [
  { key: 'home', label: 'หน้าแรก', icon: Home },
  { key: 'jobs', label: 'ตั้งงาน', icon: BriefcaseBusiness },
  { key: 'weighprint', label: 'ชั่งพิมพ์', icon: Printer },
  { key: 'weigh', label: 'ชั่งสลิท', icon: Scale },
  { key: 'transfer', label: 'โอน', icon: Package },
  { key: 'held', label: 'ม้วนพักไว้', icon: Boxes },
  { key: 'log', label: 'Log ชั่ง', icon: ClipboardList },
  { key: 'settings', label: 'ตั้งค่า', icon: Settings },
] as const

function AnnouncementBar() {
  const [text, setText] = useState('')

  useEffect(() => {
    let alive = true
    const load = () => {
      fetchSetting('announcement')
        .then(value => { if (alive) setText((value ?? '').trim()) })
        .catch(() => {})
    }
    load()
    const interval = setInterval(load, 60_000)
    window.addEventListener('focus', load)
    return () => {
      alive = false
      clearInterval(interval)
      window.removeEventListener('focus', load)
    }
  }, [])

  if (!text) return null

  const duration = Math.max(12, Math.round(text.length * 0.45))
  return (
    <div className="shrink-0 bg-amber-500/15 border-b border-amber-500/40 overflow-hidden">
      <div className="flex items-center">
        <span className="shrink-0 px-3 py-1.5 bg-amber-500 text-slate-900 font-extrabold text-xs">
          ประกาศ
        </span>
        <div className="relative flex-1 overflow-hidden py-1.5">
          <div className="bwp-marquee-track text-amber-200 font-semibold text-sm" style={{ animationDuration: `${duration}s` }}>
            <span className="px-8">{text}</span>
            <span className="px-8" aria-hidden="true">{text}</span>
          </div>
        </div>
      </div>
    </div>
  )
}

type PendingJob = {
  id: string
  work_order: string
  sale_order: string
  lot_no: string
  customer: string
  product_name: string
  print_machine: string
  slit_machine: string
  created_at: string
}

function ActiveJobsPanel({ onGo }: { onGo: (page: Page, jobId?: string) => void }) {
  const [jobs, setJobs] = useState<PendingJob[] | null>(null)

  useEffect(() => {
    let alive = true
    async function load() {
      const { data } = await supabase
        .from('production_jobs')
        .select('id, work_order, sale_order, lot_no, customer, product_name, print_machine, slit_machine, created_at')
        .neq('status', 'closed')
        .order('created_at', { ascending: false })
        .limit(20)
      if (alive) setJobs((data ?? []) as PendingJob[])
    }
    load()
    const interval = setInterval(load, 30_000)
    return () => { alive = false; clearInterval(interval) }
  }, [])

  if (jobs === null) return null

  return (
    <div className="rounded-3xl border border-blue-500/30 bg-blue-500/5 p-5">
      <p className="text-blue-300 text-sm font-bold mb-3">⚖ งานที่ชั่งค้างไว้ ({jobs.length})</p>
      {jobs.length === 0 ? (
        <p className="text-slate-500 text-sm">ยังไม่มีงานค้าง — ไปที่ "ตั้งงาน" เพื่อสร้างงานใหม่</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
          {jobs.map(j => (
            <button key={j.id} onClick={() => onGo('weigh', j.id)}
              className="text-left rounded-2xl border border-slate-700 bg-slate-900 px-4 py-3 hover:border-blue-400 transition-colors">
              <p className="text-white font-bold text-sm">
                🖨 {j.print_machine || '—'} / {j.slit_machine || '—'}
                {j.work_order ? <span className="text-slate-400 font-normal"> · WO {j.work_order}</span> : null}
              </p>
              <p className="text-slate-400 text-xs mt-0.5 truncate">
                {j.product_name || j.customer || j.lot_no}
              </p>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

function HomeGuide({ onGo }: { onGo: (page: Page, jobId?: string) => void }) {
  const [showHowTo, setShowHowTo] = useState(false)
  const weighSteps = [
    'ตั้งงาน: ใส่ SO / WO เลือกลูกค้า สินค้า เครื่องพิมพ์ และเครื่องสลิท',
    'ชั่งม้วนก่อนพิมพ์: รับม้วนวัตถุดิบเข้าระบบก่อนนำไปพิมพ์',
    'ชั่งฝั่งพิมพ์: บันทึกเศษวัตถุดิบ เศษสี/เศษกาว แล้วชั่งม้วนพิมพ์แล้ว',
    'ชั่งฝั่งสลิท: เลือกม้วนพิมพ์แล้วไปสลิท บันทึกเศษข้าง/เศษกระบวนการ',
    'ชั่งผลลัพธ์: ม้วนสำเร็จส่งลูกค้า / ม้วนเมตรไม่ถึงพักไว้ / ม้วนแก้ไข / NCR รอตัดสินใจ',
    'โอน: ใช้หลังงานเสร็จ เพื่อส่งม้วนสำเร็จรูปออกตามใบงาน',
  ]

  return (
    <div className="min-h-[calc(100vh-48px)] bg-[#0a0f1e] p-5">
      <div className="max-w-5xl mx-auto space-y-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-white text-2xl md:text-3xl font-black">หน้าหลัก</h1>
          </div>
          <button onClick={() => setShowHowTo(true)}
            className="rounded-xl border border-slate-700 bg-slate-900 px-4 py-2 text-sm font-bold text-slate-300 hover:border-brand-500 hover:text-white transition-colors">
            วิธีใช้งาน
          </button>
        </div>

        <ActiveJobsPanel onGo={onGo} />

        {showHowTo && (
          <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4" onClick={() => setShowHowTo(false)}>
            <div className="w-full max-w-3xl rounded-3xl border border-slate-700 bg-slate-900 shadow-2xl" onClick={event => event.stopPropagation()}>
              <div className="flex items-center justify-between px-5 py-4 border-b border-slate-800">
                <div>
                  <p className="text-white text-xl font-black">วิธีใช้งานแบบเข้าใจง่าย</p>
                  <p className="text-slate-400 text-sm mt-0.5">ดูเส้นทางม้วน 1 งาน: ก่อนพิมพ์ → พิมพ์แล้ว → สลิท → ส่งลูกค้า/พักไว้</p>
                </div>
                <button onClick={() => setShowHowTo(false)} className="text-slate-400 hover:text-white text-2xl leading-none">×</button>
              </div>
              <div className="p-5 space-y-2">
                {weighSteps.map((label, index) => (
                  <div key={label} className="flex items-start gap-3 rounded-2xl border border-slate-700 bg-slate-800/70 px-4 py-3">
                    <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-brand-600 text-white font-black">{index + 1}</span>
                    <span className="text-white font-bold leading-relaxed">{label}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default function App() {
  if (new URLSearchParams(window.location.search).get('roll')) return <RollDetail />

  const [page, setPage] = useState<Page>('home')
  const [weighKey, setWeighKey] = useState(0)
  const [pendingJobId, setPendingJobId] = useState<string | undefined>(undefined)
  const [showSettingsGate, setShowSettingsGate] = useState(false)
  const [showAbout, setShowAbout] = useState(false)
  const [updateReady, setUpdateReady] = useState(false)
  const [connStatus, setConnStatus] = useState<ConnStatus>('checking')
  const [latency, setLatency] = useState<number | null>(null)

  useEffect(() => {
    let alive = true
    async function checkVersion() {
      try {
        const response = await fetch(`/version.json?t=${Date.now()}`, { cache: 'no-store' })
        if (!response.ok) return
        const version = await response.json()
        if (alive && version.version && version.version !== APP_VERSION) setUpdateReady(true)
      } catch {}
    }
    checkVersion()
    const interval = setInterval(checkVersion, 120_000)
    window.addEventListener('focus', checkVersion)
    return () => {
      alive = false
      clearInterval(interval)
      window.removeEventListener('focus', checkVersion)
    }
  }, [])

  const checkConn = useCallback(async () => {
    if (!navigator.onLine) {
      setConnStatus('offline')
      setLatency(null)
      return
    }
    setConnStatus('checking')
    const startedAt = Date.now()
    try {
      await supabase.from('machine_profiles').select('machine_no').limit(1)
      const ms = Date.now() - startedAt
      setLatency(ms)
      setConnStatus(ms > 2000 ? 'slow' : 'online')
    } catch {
      setConnStatus('offline')
      setLatency(null)
    }
  }, [])

  useEffect(() => {
    checkConn()
    const interval = setInterval(checkConn, 90_000)
    window.addEventListener('online', checkConn)
    window.addEventListener('offline', checkConn)
    return () => {
      clearInterval(interval)
      window.removeEventListener('online', checkConn)
      window.removeEventListener('offline', checkConn)
    }
  }, [checkConn])

  return (
    <div className="min-h-screen flex flex-col bg-[#0a0f1e]">
      <nav className="flex items-center gap-1 px-4 py-2 bg-slate-900 border-b border-slate-800 shrink-0">
        <button
          onClick={() => {
            setPage('home')
          }}
          className="flex items-center gap-2 mr-3 hover:opacity-80 transition-opacity"
        >
          <img src="/logo.png" alt="BWP" className="w-7 h-7 rounded-full object-cover" />
          <span className="text-white font-bold text-sm hidden sm:block">ระบบชั่งม้วนงานพิมพ์</span>
        </button>

        <div className="mr-3 hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-lg border text-sm font-bold bg-purple-500/20 text-purple-300 border-purple-500/40">
          <span>🖨</span>
          <span>แผนกพิมพ์</span>
        </div>

        <div className="w-px h-5 bg-slate-700 mr-2" />

        {NAV.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => {
              if (key === 'settings' && !isAdminUnlocked()) {
                setShowSettingsGate(true)
                return
              }
              // กดเมนู "ชั่ง"/"ชั่งพิมพ์" ตรงๆ = เปิดหน้าเลือกงานปกติ (ไม่เจาะเข้างานที่ค้างจากหน้าหลัก)
              if (key === 'weigh' || key === 'weighprint') { setPendingJobId(undefined); setWeighKey(k => k + 1) }
              setPage(key)
            }}
            className={`relative flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
              page === key ? 'bg-brand-600 text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <Icon size={14} />
            <span className="hidden md:block">{label}</span>
          </button>
        ))}

        <div className="ml-auto flex-shrink-0 flex items-center gap-2">
          <button
            onClick={() => setShowAbout(true)}
            title="ดูรายละเอียดเวอร์ชัน"
            className="hidden md:block text-[10px] text-slate-500 hover:text-brand-300 transition-colors"
          >
            v{APP_VERSION}
          </button>
          <button
            onClick={checkConn}
            title={latency ? `${latency}ms` : undefined}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all ${
              connStatus === 'online' ? 'bg-green-500/10 border-green-500/30 text-green-400'
              : connStatus === 'slow' ? 'bg-amber-500/10 border-amber-500/30 text-amber-400'
              : connStatus === 'offline' ? 'bg-red-500/10 border-red-500/30 text-red-400'
              : 'bg-slate-800 border-slate-700 text-slate-500'
            }`}
          >
            {connStatus === 'online' && <><Wifi size={12} /><span className="hidden sm:block">ออนไลน์</span>{latency && <span className="opacity-60">{latency}ms</span>}</>}
            {connStatus === 'slow' && <><AlertTriangle size={12} /><span className="hidden sm:block">สัญญาณช้า</span>{latency && <span className="opacity-60">{latency}ms</span>}</>}
            {connStatus === 'offline' && <><WifiOff size={12} /><span className="hidden sm:block">ออฟไลน์</span></>}
            {connStatus === 'checking' && <><span className="w-2.5 h-2.5 rounded-full bg-slate-500 animate-pulse inline-block" /><span className="hidden sm:block ml-1">กำลังตรวจ...</span></>}
          </button>
        </div>
      </nav>

      <AnnouncementBar />

      <main className="flex-1 overflow-auto">
        {page === 'home' && <HomeGuide onGo={(nextPage, jobId) => {
          setPage(nextPage)
          if (nextPage === 'weigh') { setPendingJobId(jobId); setWeighKey(key => key + 1) }
        }} />}
        {page === 'jobs' && <JobsPage />}
        {page === 'weighprint' && <WeighStation key={`print-${weighKey}`} dept={DEPT} printOnly />}
        {page === 'weigh' && <WeighStation key={weighKey} dept={DEPT} initialJobId={pendingJobId} />}
        {page === 'transfer' && <Transfer dept={DEPT} />}
        {page === 'held' && <HeldRolls dept={DEPT} />}
        {page === 'log' && <WeighLog />}
        {page === 'settings' && <ProductionSettings />}
      </main>

      {showSettingsGate && (
        <AdminPinGate
          onUnlock={() => {
            setShowSettingsGate(false)
            setPage('settings')
          }}
          onClose={() => setShowSettingsGate(false)}
        />
      )}

      {updateReady && (
        <div className="fixed top-0 left-0 right-0 z-[70] bg-brand-600 text-white px-4 py-2 flex items-center justify-center gap-3 shadow-lg">
          <span className="text-sm font-bold">มีเวอร์ชันใหม่พร้อมใช้งาน</span>
          <button onClick={() => location.reload()} className="bg-white text-brand-700 font-bold text-sm px-4 py-1 rounded-lg hover:bg-slate-100">
            อัปเดตตอนนี้
          </button>
          <button onClick={() => setUpdateReady(false)} className="text-white/70 hover:text-white text-sm">ไว้ทีหลัง</button>
        </div>
      )}

      {showAbout && (
        <div className="fixed inset-0 bg-black/70 z-[60] flex items-center justify-center p-4" onClick={() => setShowAbout(false)}>
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-lg max-h-[85vh] flex flex-col shadow-2xl" onClick={event => event.stopPropagation()}>
            <div className="px-5 py-4 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <img src="/logo.png" alt="BWP" className="w-9 h-9 rounded-full object-cover" />
                <div>
                  <p className="text-white font-bold">ระบบชั่งม้วนงานพิมพ์ BWP</p>
                  <p className="text-slate-400 text-xs">เวอร์ชัน {APP_VERSION} · {APP_BUILD_DATE}</p>
                </div>
              </div>
              <button onClick={() => setShowAbout(false)} className="text-slate-400 hover:text-white text-xl leading-none">×</button>
            </div>
            <div className="px-5 py-4 overflow-y-auto space-y-4">
              <p className="text-slate-300 text-sm font-semibold">ประวัติการอัปเดต</p>
              {CHANGELOG.map(change => (
                <div key={change.version} className="border-l-2 border-brand-500/50 pl-3">
                  <p className="text-brand-300 font-bold text-sm">v{change.version} <span className="text-slate-500 font-normal text-xs">· {change.date}</span></p>
                  <ul className="mt-1 space-y-1">
                    {change.items.map((item, index) => (
                      <li key={index} className="text-slate-400 text-xs leading-snug flex gap-1.5">
                        <span className="text-brand-400">•</span>
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
            <div className="px-5 py-3 border-t border-slate-800">
              <button onClick={() => setShowAbout(false)} className="w-full bg-slate-800 hover:bg-slate-700 text-slate-300 py-2 rounded-lg text-sm">ปิด</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
