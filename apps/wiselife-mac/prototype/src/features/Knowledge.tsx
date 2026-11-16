import { useEffect, useRef, useState } from "react";
import { CalendarDays, Mic, Search, Square } from "lucide-react";
import {
  Button,
  DateInput,
  Empty,
  Heading,
  Input,
  Panel,
  Tabs,
  Tag,
  clock,
} from "../components/ui";
import { Chat } from "./Chat";
import demo from "../demo.json";
import type { KnowledgeRecord, Message } from "../types";
export function useKnowledge() {
  const [records, setRecords] = useState<KnowledgeRecord[]>(demo.knowledge),
    [day, setDay] = useState<string | null>("2026-10-31"),
    [kind, setKind] = useState<string | null>("全部"),
    [query, setQuery] = useState(""),
    [selected, setSelected] = useState<string | null>(null),
    [scope, setScope] = useState<string | null>(null),
    [draft, setDraft] = useState(""),
    [messages, setMessages] = useState<Message[]>([]),
    [pending, setPending] = useState(false),
    [recording, setRecording] = useState(false),
    [seconds, setSeconds] = useState(0);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => {
    if (!recording) return;
    const id = setInterval(() => setSeconds((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [recording]);
  useEffect(() => () => clearTimeout(timer.current), []);
  function start() {
    setSeconds(0);
    setRecording(true);
  }
  function stop() {
    const id = "mac-" + Date.now();
    setRecords((prev) => [
      {
        id,
        day: "2026-10-31",
        time: new Date().toLocaleTimeString("zh-CN", {
          hour: "2-digit",
          minute: "2-digit",
        }),
        kind: "录音",
        title: "长录音 · Mac 录音示例",
        summary: "录音交互已结束，未生成音频或转写。",
        text: "这是一条原型演示记录。本次没有使用麦克风、生成音频或调用转写与 AI 模型。",
        device: "这台 Mac",
        duration: clock(seconds),
      },
      ...prev,
    ]);
    setRecording(false);
    setDay("2026-10-31");
    setKind("全部");
    setQuery("");
    setSelected(id);
  }
  function cancel() {
    clearTimeout(timer.current);
    setPending(false);
  }
  function ask(q: string, ready: boolean) {
    if (!ready || pending || !q.trim()) return;
    setDraft("");
    setMessages((prev) => [...prev, { role: "user", text: q }]);
    setPending(true);
    const candidates = scope
      ? records.filter((r) => r.id === scope)
      : q.includes("运动")
        ? records.filter((r) => r.id === "walk")
        : records.filter((r) => ["meeting", "idea", "review"].includes(r.id));
    timer.current = setTimeout(() => {
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          text:
            "示例回答\n" +
            candidates.map((r) => r.summary).join("\n\n") +
            "\n\n以上为回顾建议，尚未创建待办。",
          citations: candidates.map((r) => ({ id: r.id, label: r.title })),
        },
      ]);
      setPending(false);
    }, 800);
  }
  function cite(id: string) {
    const r = records.find((r) => r.id === id);
    if (!r) return;
    setDay(r.day);
    setKind("全部");
    setQuery("");
    setSelected(id);
    requestAnimationFrame(() => {
      const target = document.getElementById("knowledge-" + id);
      target?.focus({ preventScroll: true });
      target?.scrollIntoView({ block: "center", behavior: "smooth" });
    });
  }
  function reset() {
    cancel();
    setRecords(demo.knowledge);
    setDay("2026-10-31");
    setKind("全部");
    setQuery("");
    setSelected(null);
    setScope(null);
    setDraft("");
    setMessages([]);
    setRecording(false);
    setSeconds(0);
  }
  return {
    records,
    day,
    setDay,
    kind,
    setKind,
    query,
    setQuery,
    selected,
    setSelected,
    scope,
    setScope,
    draft,
    setDraft,
    messages,
    setMessages,
    pending,
    recording,
    seconds,
    start,
    stop,
    cancel,
    ask,
    cite,
    reset,
  };
}
type Model = ReturnType<typeof useKnowledge>;
export function KnowledgeAgent({
  k,
  ready,
  model,
}: {
  k: Model;
  ready: boolean;
  model: string;
}) {
  return (
    <>
      <Chat
        messages={k.messages}
        draft={k.draft}
        setDraft={k.setDraft}
        send={(q) => k.ask(q, ready)}
        pending={k.pending}
        stop={k.cancel}
        ready={ready}
        model={model}
        scope={
          k.scope
            ? "围绕：" + k.records.find((r) => r.id === k.scope)?.title
            : "按问题查找记录 · 无需先选日期"
        }
        prompts={[
          "今天有哪些事情值得跟进？",
          "最近关于产品有哪些想法？",
          "今天有运动吗？",
        ]}
        onCite={(c) => k.cite(c.id)}
        reset={() => {
          k.cancel();
          k.setMessages([]);
          k.setDraft("");
        }}
      />
      {k.scope && (
        <Button variant="subtle" onClick={() => k.setScope(null)}>
          取消指定记录
        </Button>
      )}
    </>
  );
}
export function Knowledge({
  k,
  showAgent,
}: {
  k: Model;
  showAgent: () => void;
}) {
  const filtered = k.records.filter(
    (r) =>
      r.day === k.day &&
      (k.kind === "全部" || r.kind === k.kind) &&
      (!k.query || (r.title + r.text).includes(k.query)),
  );
  return (
    <>
      <Heading
        eyebrow="iPhone 与这台 Mac 的记录"
        title="每天的记录，都在这里。"
        description="回到当时，也看见新的联系。"
      />
      <div className="flex flex-wrap items-center justify-between gap-[16px]">
        <Tag tone="success">iPhone 示例已同步</Tag>
        {k.recording ? (
          <div className="flex items-center gap-[12px]">
            <Tag tone="warning">录音中 · {clock(k.seconds)}</Tag>
            <Button leftSection={<Square size={14} />} onClick={k.stop}>
              停止并保存
            </Button>
          </div>
        ) : (
          <Button leftSection={<Mic size={16} />} onClick={k.start}>
            开始录音
          </Button>
        )}
      </div>
      <div className="flex flex-wrap items-center gap-[12px]">
        <DateInput
          label="记录日期"
          value={k.day}
          onChange={k.setDay}
          maxDate="2026-10-31"
          valueFormat="YYYY-MM-DD"
          clearable={false}
        />
        <Button variant="subtle" onClick={() => k.setDay("2026-10-31")}>
          示例今天
        </Button>
        <span className="ml-auto text-[12px] text-[#8c8c8c]">
          {filtered.length} 条记录
        </span>
      </div>
      <Input
        aria-label="搜索当天记录"
        placeholder="搜索当天的记录…"
        w="100%"
        leftSection={<Search size={16} />}
        value={k.query}
        onChange={(e) => k.setQuery(e.currentTarget.value)}
      />
      <Tabs variant="pills" value={k.kind} onChange={k.setKind}>
        <Tabs.List aria-label="记录类型">
          {["全部", "录音", "闪念", "健康"].map((kind) => (
            <Tabs.Tab key={kind} value={kind}>
              {kind}
            </Tabs.Tab>
          ))}
        </Tabs.List>
      </Tabs>
      <div className="flex flex-col gap-[12px]">
        {filtered.map((r) => (
          <article
            id={"knowledge-" + r.id}
            tabIndex={-1}
            key={r.id}
            className={
              k.selected === r.id
                ? "rounded-[12px] border border-solid border-[#d0dfff] bg-[#f3f7ff] p-[24px]"
                : "rounded-[12px] border border-solid border-[#f0f0f0] bg-white p-[24px]"
            }
          >
            <div className="flex items-start gap-[12px]">
              <time className="mt-[6px] text-[12px] tabular-nums text-[#8c8c8c]">
                {r.time}
              </time>
              <div className="min-w-0 flex-1">
                <Button
                  variant="subtle"
                  h="auto"
                  px={0}
                  py={4}
                  onClick={() =>
                    k.setSelected(k.selected === r.id ? null : r.id)
                  }
                  aria-expanded={k.selected === r.id}
                  classNames={{
                    label: "whitespace-normal text-left font-medium",
                  }}
                >
                  {r.title}
                </Button>
                <p className="mb-[16px] mt-[12px] text-[14px] leading-[1.9] text-[#595959]">
                  {k.selected === r.id ? r.text : r.summary}
                </p>
                <div className="flex flex-wrap items-center gap-[12px]">
                  <Tag size="sm">{r.kind}</Tag>
                  <small className="text-[#8c8c8c]">
                    {r.device} · {r.duration}
                  </small>
                  <Button
                    size="xs"
                    variant="subtle"
                    color="blue"
                    onClick={() => {
                      k.setScope(r.id);
                      showAgent();
                    }}
                  >
                    围绕这条提问 ↗
                  </Button>
                </div>
              </div>
            </div>
          </article>
        ))}
      </div>
      {!filtered.length && (
        <Empty
          title="这里还没有记录"
          description="换个日期，或调整搜索条件。"
        />
      )}
      <p className="mt-auto pt-[16px] text-[12px] text-[#8c8c8c]">
        示例资料仅保存在本页内存；不读取手机或实际录音。
      </p>
    </>
  );
}
