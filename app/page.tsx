'use client'

import { useState } from 'react'
import { ArrowUpLeft, Check, Copy, Download, Heart, Inbox, LockKeyhole, MessageCircle, ShieldCheck, Sparkles, Star, UserRound } from 'lucide-react'

const sampleMessages = [
  { id: 1, text: 'أحب طريقتك في تشجيع كل من حولك. وجودك يفرق فعلًا.', type: 'رسالة خاصة', time: 'منذ ٨ دقائق' },
  { id: 2, text: 'كيف تحافظ على هدوئك وقت الضغط؟ عندك نصيحة؟', type: 'سؤال مجهول', time: 'منذ ٤٥ دقيقة' },
  { id: 3, text: 'ممتنّ لكل مرة كنت فيها موجودًا بدون ما أطلب.', type: 'رسالة خاصة', time: 'أمس' },
]

export default function Home() {
  const [tab, setTab] = useState('الكل')
  const [copied, setCopied] = useState(false)
  const [starred, setStarred] = useState<number[]>([1])
  const [query, setQuery] = useState('')
  const visible = sampleMessages.filter((message) => (tab === 'الكل' || tab === 'المفضلة' && starred.includes(message.id) || tab === 'الأسئلة' && message.type === 'سؤال مجهول') && message.text.includes(query))

  return (
    <main className="min-h-screen bg-[#f7f6fa] pb-12 text-[#242a3a]">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-5 py-5 sm:px-8">
        <a className="flex items-center gap-3" href="#inbox" aria-label="صراحة — البداية">
          <span className="grid size-11 place-items-center rounded-2xl bg-[#7357c8] text-white"><LockKeyhole size={20} /></span>
          <span><strong className="block text-lg font-extrabold">صراحة</strong><small className="text-xs text-[#7d8292]">مساحتك الخاصة</small></span>
        </a>
        <span className="hidden items-center gap-2 rounded-full border border-[#eae8f0] bg-white px-4 py-2 text-xs font-semibold text-[#596074] sm:flex"><ShieldCheck size={15} className="text-[#2f8f76]" /> معاينة تصميم Flutter</span>
        <a className="flex items-center gap-2 rounded-xl bg-[#7357c8] px-4 py-2.5 text-sm font-bold text-white" href="#inbox">المعاينة <ArrowUpLeft size={16} /></a>
      </header>
      <section aria-labelledby="download-title" className="mx-auto mb-2 flex w-full max-w-6xl flex-col items-center justify-between gap-3 px-5 sm:flex-row sm:px-8">
        <div className="text-center sm:text-right">
          <h2 id="download-title" className="text-sm font-extrabold">حمّل مشروع Sarehny لـ Android</h2>
          <p className="mt-1 text-xs text-[#73788a]">ملفات Flutter وPHP API وAndroid كاملة بصيغة ZIP</p>
        </div>
        <a href="/downloads/saraha-android-project.zip" download className="inline-flex min-h-11 w-full shrink-0 items-center justify-center gap-2 rounded-2xl bg-[#7357c8] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[#6145b8] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7357c8] sm:w-auto">
          <Download size={17} aria-hidden="true" />
          تنزيل المشروع ZIP
        </a>
      </section>
      <section className="mx-auto grid max-w-6xl items-center gap-10 px-5 pb-10 pt-8 sm:px-8 lg:grid-cols-[.9fr_1.1fr] lg:gap-16 lg:pb-16 lg:pt-14">
        <div className="max-w-xl">
          <span className="inline-flex items-center gap-2 rounded-full bg-[#f0ecfb] px-3 py-1.5 text-xs font-bold text-[#7357c8]"><Sparkles size={14} /> تطبيق Android مستقل لموقعك</span>
          <h1 className="mt-5 text-4xl leading-[1.25] font-black tracking-tight sm:text-5xl">مساحتك الخاصة،<br /><span className="text-[#7357c8]">بصراحة أكثر.</span></h1>
          <p className="mt-5 max-w-lg text-base leading-8 text-[#73788a]">تجربة عربية أصلية لصندوق رسائلك المجهولة. الحسابات والرسائل تبقى على موقع صراحة — بلا قاعدة بيانات ثانية، وبلا إضافات اجتماعية.</p>
          <div className="mt-7 flex flex-wrap gap-3"><a href="#inbox" className="inline-flex items-center gap-2 rounded-2xl bg-[#7357c8] px-5 py-3 text-sm font-bold text-white shadow-lg shadow-[#7357c8]/15"><Inbox size={17} /> استكشف المعاينة</a><span className="inline-flex items-center gap-2 rounded-2xl border border-[#eae8f0] bg-white px-5 py-3 text-sm font-semibold text-[#596074]"><ShieldCheck size={17} className="text-[#2f8f76]" /> API PHP جلساتي</span></div>
          <div className="mt-8 flex flex-wrap items-center gap-x-5 gap-y-2 text-xs text-[#7d8292]"><span className="flex items-center gap-2"><LockKeyhole size={14} /> لا WebView</span><span className="flex items-center gap-2"><Heart size={14} /> خصوصية أولًا</span><span className="flex items-center gap-2"><UserRound size={14} /> RTL بالكامل</span></div>
        </div>
        <section id="inbox" aria-label="معاينة صندوق الرسائل" className="mx-auto w-full max-w-[540px] rounded-[30px] border border-[#e9e6f1] bg-white p-4 shadow-[0_25px_80px_-40px_rgba(45,34,82,.35)] sm:p-6">
          <div className="flex items-center justify-between border-b border-[#f0eef4] pb-4"><div><small className="text-xs text-[#8b90a0]">مساحتك الخاصة</small><h2 className="mt-1 text-xl font-extrabold">صندوق رسائلك</h2></div><span className="grid size-11 place-items-center rounded-2xl bg-[#f0ecfb] text-[#7357c8]"><Inbox size={19} /></span></div>
          <div className="mt-4 grid grid-cols-3 gap-2">{[['كل الرسائل','٢٤'],['اليوم','٣'],['أسئلة معلّقة','٢']].map(([label,value]) => <div key={label} className="rounded-2xl bg-[#faf9fc] p-3"><strong className="block text-lg">{value}</strong><small className="mt-1 block truncate text-[10px] text-[#7d8292]">{label}</small></div>)}</div>
          <div className="mt-5 flex gap-2 overflow-x-auto pb-1" aria-label="فلاتر المعاينة">{['الكل','الأسئلة','المفضلة'].map((name) => <button key={name} onClick={() => setTab(name)} className={`shrink-0 rounded-full px-4 py-2 text-xs font-bold ${tab === name ? 'bg-[#7357c8] text-white' : 'bg-[#f5f4f8] text-[#777c8c]'}`}>{name}</button>)}</div>
          <label className="mt-4 flex items-center gap-2 rounded-xl bg-[#faf9fc] px-3 py-2.5 text-sm text-[#8b90a0]"><MessageCircle size={16} /><span className="sr-only">ابحث في رسائلك</span><input className="w-full bg-transparent outline-none placeholder:text-[#a1a5b2]" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ابحث في رسائلك..." /></label>
          <div className="mt-3 space-y-3">{visible.map((message) => <article key={message.id} className="rounded-2xl border border-[#eeecf2] p-4"><div className="flex items-center gap-2 text-xs"><span className="grid size-8 place-items-center rounded-xl bg-[#f0ecfb] text-[#7357c8]"><LockKeyhole size={15} /></span><strong>{message.type}</strong><span className="mr-auto text-[#8b90a0]">{message.time}</span></div><p className="mt-3 text-sm leading-7 text-[#414659]">{message.text}</p><div className="mt-2 flex justify-end"><button aria-label={starred.includes(message.id) ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'} onClick={() => setStarred((current) => current.includes(message.id) ? current.filter((id) => id !== message.id) : [...current, message.id])} className="rounded-full p-2 text-[#c39538] hover:bg-[#faf5e9]"><Star size={17} fill={starred.includes(message.id) ? 'currentColor' : 'none'} /></button></div></article>)}{visible.length === 0 && <p className="rounded-2xl bg-[#faf9fc] p-6 text-center text-sm text-[#7d8292]">لا توجد رسائل تطابق البحث.</p>}</div>
          <div className="mt-4 flex items-center justify-between rounded-2xl bg-[#f8f6fc] p-3"><div className="min-w-0"><small className="text-[10px] text-[#8b90a0]">رابطك الشخصي</small><p className="truncate text-xs font-semibold text-[#514b64]" dir="ltr">sarehny.com/yourname</p></div><button onClick={async () => { try { await navigator.clipboard.writeText('https://sarehny.com/yourname'); setCopied(true); window.setTimeout(() => setCopied(false), 1800) } catch { setCopied(false) } }} className="mr-3 flex shrink-0 items-center gap-1 rounded-xl bg-white px-3 py-2 text-xs font-bold text-[#7357c8] shadow-sm">{copied ? <Check size={14} /> : <Copy size={14} />}{copied ? 'تم النسخ' : 'نسخ الرابط'}</button></div>
          <div className="mt-5 flex items-center justify-between rounded-2xl border border-dashed border-[#ddd7eb] px-4 py-3"><span><strong className="block text-sm">نسخة Android</strong><small className="text-xs text-[#8b90a0]">مصدر Flutter، وليس WebView</small></span><span className="size-2 rounded-full bg-[#2f8f76]" aria-label="تصميم RTL" /></div>
        </section>
      </section>
      <footer className="mx-auto max-w-6xl px-5 pb-9 text-center text-xs leading-6 text-[#989cac] sm:px-8">هذه معاينة تفاعلية للتصميم ببيانات تجريبية فقط. تسجيل الدخول والبيانات الحقيقية تعمل من تطبيق Flutter بعد نشر API على الاستضافة.</footer>
    </main>
  )
}
