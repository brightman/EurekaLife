import { useEffect, useRef, useState } from "react";
import { Archive, CalendarDays, ChevronLeft, ChevronRight, FileText, Image, Mic, Smartphone, Sparkles } from "lucide-react";
import { Alert, Button, Empty, Heading, Panel, Select, Tag } from "../components/ui";
import { Chat } from "./Chat";
import type { Message } from "../types";
const days = ["2026-11-13", "2026-11-12", "2026-11-11"];
const entries = [
  { time: "08:42", type: "闪念", title: "让想法有一个可以回来的地方", text: "把今天随手记下的想法，留到周末一起整理。不急着得到结论，先保留当时的思考。", Icon: Sparkles },
  { time: "10:20", type: "录音", title: "上午的产品讨论", text: "讨论每日记录的整理方式，以及在 Mac 上备份、浏览和查找资料的体验。包含原始录音、转写和已生成的总结。", Icon: Mic },
  { time: "14:35", type: "照片", title: "白板上的方案草图", text: "保留照片及拍摄时间、地点等附带信息。此处为示例说明，没有加载真实照片。", Icon: Image },
  { time: "21:10", type: "每日回顾", title: "把今天留在这里", text: "今天留下了一个想法、一场讨论和一张白板照片。明天继续完善备份与回看的流程。", Icon: FileText },
];
function recordsForDay(day: string) {
  return entries.map((entry, index) => {
    if (day === "2026-11-12") return entry;
    const titles = day === "2026-11-13" ? ["让每日备份更简单", "今天的项目沟通", "午后的一张随手拍", "今天值得记住的事"] : ["周末的阅读计划", "与同事讨论下一步", "路上的一个角落", "留给明天的线索"];
    return { ...entry, title: titles[index], text: index === 0 ? (day === "2026-11-13" ? "希望连接 iPhone 后，能方便地把今天的记录留在 Mac。备份完成后，也能按日期回看。" : "周末选一本一直想读的书，留一点不被打扰的时间，记下最有启发的一句话。") : entry.text };
  });
}
export function useDailyRecords(notify: (text: string) => void, connected: boolean) {
  const [backed, setBacked] = useState([days[1], days[2]]);
  const [selected, updateSelected] = useState(days[1]);
  const [device, setDevice] = useState<string | null>("online");
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [messages, setMessages] = useState<Record<string, Message[]>>({});
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [pendingDay, setPendingDay] = useState<string | null>(null);
  const aiTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  function stop() { clearTimeout(aiTimer.current); setPendingDay(null); }
  function setSelected(day: string) { stop(); updateSelected(day); setExpanded(null); }
  function ask(question: string, ready: boolean) {
    const q = question.trim();
    if (!ready || !backed.includes(selected) || pendingDay || !q) return;
    const date = selected, records = recordsForDay(date);
    setMessages(all => ({ ...all, [date]: [...(all[date] || []), { role: "user", text: q }] }));
    setDrafts(all => ({ ...all, [date]: "" }));
    setPendingDay(date);
    aiTimer.current = setTimeout(() => {
      setMessages(all => ({ ...all, [date]: [...(all[date] || []), {
        role: "assistant", text: `${date} 的备份包含以下记录：\n\n${records.map(r => `${r.time} · ${r.title}\n${r.text}`).join("\n\n")}\n\n这是当前日期资料的示例整理，没有调用真实模型。可点击引用查看原始记录。`,
        citations: records.map(r => ({ id: date + "|" + r.time, label: r.title })),
      }] }));
      setPendingDay(null);
    }, 800);
  }
  function cite(id: string) {
    const [date, time] = id.split("|");
    if (!backed.includes(date) || !recordsForDay(date).some(r => r.time === time)) return;
    setSelected(date); setExpanded(time);
    requestAnimationFrame(() => {
      const element = document.getElementById(`daily-${date}-${time}`);
      element?.focus({ preventScroll: true }); element?.scrollIntoView({ block: "center", behavior: "smooth" });
    });
  }
  function resetChat() { stop(); setMessages(all => ({ ...all, [selected]: [] })); }
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => { clearTimeout(timer.current); clearTimeout(aiTimer.current); }, []);
  useEffect(() => {
    if (!connected && busy) { clearTimeout(timer.current); setBusy(false); notify("设备连接中断，已有备份已保留，请连接后重试（演示）"); }
  }, [connected, busy, notify]);
  function backup(available: boolean) {
    if (!available || busy || device !== "online" || backed.includes(days[0])) return;
    setBusy(true);
    timer.current = setTimeout(() => { setBacked([...days]); setBusy(false); setSelected(days[0]); notify("今日数据已备份（演示）；iPhone 上的原始资料保持不变"); }, 1200);
  }
  function reset() { stop(); setMessages({}); setDrafts({}); clearTimeout(timer.current); setBacked([days[1], days[2]]); setSelected(days[1]); setDevice("online"); setBusy(false); setExpanded(null); }
  return { messages, drafts, pendingDay, stop, ask, cite, resetChat, setDraft: (value: string) => setDrafts(all => ({ ...all, [selected]: value })), backed, selected, setSelected, device, setDevice, busy, expanded, setExpanded, backup, reset };
}
export function DailyRecords({ model: d, root, deviceName, network, openSettings, openDevices }: { model: ReturnType<typeof useDailyRecords>; root: string; deviceName?: string; network: boolean; openSettings: () => void; openDevices: () => void }) {
  const online = !!deviceName && network && d.device === "online";
  const available = d.backed.includes(d.selected);
  const dayEntries = recordsForDay(d.selected);
  return <>
    <Heading title="每日记录" description="把 iPhone 上的每一天，妥善留在 Mac。" action={<Button leftSection={<Archive size={16} />} disabled={!online || d.busy || d.backed.includes(days[0])} onClick={() => d.backup(online)}>{d.busy ? "正在备份…" : d.backed.includes(days[0]) ? "备份已是最新" : "备份最新数据"}</Button>} />
    <Panel><div className="flex flex-wrap items-start justify-between gap-[20px]">
      <div className="flex gap-[16px]"><Smartphone size={24} className="shrink-0 text-[#595959]" /><div><h2 className="mb-[8px] text-[16px] font-medium">{deviceName || "尚未配对 iPhone"}</h2><Tag tone={online ? "success" : "neutral"}>{online ? "已连接 · 演示设备" : "等待连接"}</Tag><p className="mb-0 mt-[12px] text-[13px] text-[#8c8c8c]">已备份 {d.backed.length} 天 · {d.backed.length * entries.length} 条记录</p></div></div>
      <Select label="演示设备状态" w={180} value={d.device} disabled={d.busy} onChange={d.setDevice} data={[{ value: "online", label: "已连接" }, { value: "offline", label: "离线" }]} />
    </div><div className="mt-[20px] border-0 border-t border-solid border-[#f0f0f0] pt-[16px]"><p className="mb-[6px] text-[12px] text-[#8c8c8c]">备份位置</p><p data-testid="backup-path" className="m-0 break-all text-[13px] leading-[1.8]">{root}/DailyRecords/iPhone</p><Button variant="subtle" size="xs" mt={8} onClick={openSettings}>管理主目录</Button></div></Panel>
    {!online && <Alert status="warning" title={deviceName ? "连接 iPhone 后可继续备份；已备份的每日记录仍可查看。" : "配对 iPhone 后可备份每日数据；历史备份仍保留。"} classNames={{ message: "whitespace-normal" }}><Button variant="subtle" size="xs" onClick={openDevices}>管理配对设备</Button></Alert>}
    {d.busy && <Alert status="loading" title="正在接收今日记录、保存附件并校验完整性（演示）…" classNames={{ message: "whitespace-normal" }} />}
    <div className="mt-[8px] flex flex-wrap items-center justify-between gap-[12px]"><h2 className="m-0 text-[18px] font-medium">按日回看</h2><span className="text-[12px] text-[#8c8c8c]">本地备份 · 只读浏览</span></div>
    <div className="flex flex-wrap gap-[8px]" role="group" aria-label="备份日期">{days.map(day => <Button key={day} variant={d.selected === day ? "light" : "subtle"} leftSection={<CalendarDays size={16} />} aria-pressed={d.selected === day} onClick={() => { d.setSelected(day); d.setExpanded(null); }}>{day.slice(5).replace("-", "月")}日 · {d.backed.includes(day) ? "已备份" : "待备份"}</Button>)}</div>
    <div className="flex items-center justify-between gap-[12px]"><h3 className="m-0 text-[15px] font-medium">{d.selected}</h3><Tag tone={available ? "success" : "neutral"}>{available ? "备份完整" : "尚未备份"}</Tag></div>
    {!available ? <Empty title="这一天，还没有备份到 Mac" description={online ? "点击上方“备份最新数据”，保存今日资料。" : "连接 iPhone 后即可备份。历史资料不受影响。"} /> : <div className="flex flex-col gap-[12px]">{dayEntries.map(item => <section key={item.time} id={`daily-${d.selected}-${item.time}`} tabIndex={-1} aria-label={item.title} className="rounded-[8px] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[#165dff]"><Panel><div className="flex gap-[16px]"><item.Icon size={20} className="shrink-0 text-[#8c8c8c]" /><div className="min-w-0 flex-1"><p className="mb-[8px] text-[12px] text-[#8c8c8c]">{item.time} · {item.type}</p><h3 className="mb-[8px] text-[15px] font-medium">{item.title}</h3><p className="mb-[8px] text-[14px] leading-[1.9] text-[#595959]">{d.expanded === item.time ? item.text : item.text.split("。")[0] + "。"}</p><Button variant="subtle" size="xs" rightSection={d.expanded === item.time ? <ChevronLeft size={14} /> : <ChevronRight size={14} />} aria-expanded={d.expanded === item.time} onClick={() => d.setExpanded(d.expanded === item.time ? null : item.time)}>{d.expanded === item.time ? "收起内容" : "查看内容"}</Button></div></div></Panel></section>)}</div>}
    <p className="mt-auto pt-[16px] text-[12px] leading-[1.8] text-[#8c8c8c]">备份范围包含录音、闪念、照片、记事本、人物与地点、每日回顾，保留原始附件和已有整理结果。不会删除 iPhone 上的资料。当前设备、日期、内容与备份操作均为示例。</p>
  </>;
}

export function DailyAgent({ d, ready, model, onCite }: { d: ReturnType<typeof useDailyRecords>; ready: boolean; model: string; onCite: (id: string) => void }) {
  return <Chat key={d.selected} messages={d.messages[d.selected] || []} draft={d.drafts[d.selected] || ""} setDraft={d.setDraft}
    send={q => d.ask(q, ready)} pending={d.pendingDay === d.selected} stop={d.stop} ready={ready} model={model}
    scope={`仅使用 ${d.selected} 已备份的每日记录`} prompts={["总结这一天的记录", "这一天有哪些想法值得回顾？"]}
    onCite={citation => onCite(citation.id)} reset={d.resetChat} enabled={d.backed.includes(d.selected)}
    disabledMessage="这一天尚未备份，请先备份或选择已备份日期。" />;
}
