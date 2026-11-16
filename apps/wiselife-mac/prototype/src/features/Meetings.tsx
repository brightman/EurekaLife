import { useEffect, useRef, useState } from "react";
import {
  Bookmark,
  Trash2,
  Check,
  ChevronLeft,
  FileAudio,
  FileUp,
  Mic,
  Monitor,
  Pause,
  Play,
  Search,
  ShieldCheck,
  Square,
  Star,
  Upload,
  Volume2,
} from "lucide-react";
import {
  Alert,
  Button,
  Empty,
  Heading,
  IconButton,
  Input,
  Loader,
  Modal,
  Panel,
  Radio,
  Select,
  Switch,
  Table,
  Tabs,
  Tag,
  clock,
  stamp,
} from "../components/ui";
import { Chat } from "./Chat";
import { CapturePicker } from "./CapturePicker";
import demo from "../demo.json";
import type { Meeting, Message } from "../types";
const lines = demo.meetings.lines;
const initial = () => structuredClone(demo.meetings.records) as Meeting[];
const defaultSetup = () => ({
  title: "",
  mode: "audio",
  mic: true,
  system: true,
  device: "MacBook Air 麦克风",
  language: "中文",
  translation: false,
  target: "英语",
  screen: "",
  permission: true,
});
export function useMeetings(notify: (s: string) => void) {
  const [records, setRecords] = useState(initial),
    [selected, setSelected] = useState<string | null>(null),
    [library, setLibrary] = useState(true),
    [deleteId, setDeleteId] = useState<string | null>(null),
    [tab, setTab] = useState<string | null>("transcript");
  const [activeId, setActiveId] = useState<string | null>(null),
    [fault, setFault] = useState(""),
    [modal, setModal] = useState(""),
    [setup, setSetup] = useState(defaultSetup);
  const [query, setQuery] = useState(""),
    [filter, setFilter] = useState<string | null>("all"),
    [translated, setTranslated] = useState(false),
    [drafts, setDrafts] = useState<Record<string, string>>({});
  const [pending, setPending] = useState(false),
    [upload, setUpload] = useState(""),
    [uploadError, setUploadError] = useState(""),
    [uploadLanguage, setUploadLanguage] = useState("中文");
  const [task, setTask] = useState({ time: 0, task: "", owner: "", due: "" }),
    [taskKey, setTaskKey] = useState(""),
    [taskDrafts, setTaskDrafts] = useState<Record<string, typeof task>>({}),
    [playing, setPlaying] = useState(false),
    [playhead, setPlayhead] = useState(0);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]),
    aiTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined),
    seq = useRef(0);
  const active = records.find((r) => r.id === activeId),
    current = records.find((r) => r.id === selected);
  const change = (id: string, patch: Partial<Meeting>) =>
    setRecords((prev) =>
      prev.map((r) => (r.id === id ? { ...r, ...patch } : r)),
    );
  useEffect(() => {
    if (!activeId || active?.paused) return;
    const timer = setInterval(
      () =>
        setRecords((prev) =>
          prev.map((r) =>
            r.id !== activeId
              ? r
              : {
                  ...r,
                  duration: r.duration + 1,
                  count:
                    fault === "lag"
                      ? r.count
                      : Math.min(6, 1 + Math.floor((r.duration + 1) / 6)),
                },
          ),
        ),
      1000,
    );
    return () => clearInterval(timer);
  }, [activeId, active?.paused, fault]);
  useEffect(() => {
    if (!playing || !current) return;
    const timer = setInterval(
      () => setPlayhead((v) => Math.min(current.duration, v + 1)),
      1000,
    );
    return () => clearInterval(timer);
  }, [playing, current?.id, current?.duration]);
  useEffect(() => {
    if (current && playhead >= current.duration) setPlaying(false);
  }, [playhead, current]);
  useEffect(
    () => () => {
      timers.current.forEach(clearTimeout);
      clearTimeout(aiTimer.current);
    },
    [],
  );
  function open(id: string) {
    if (id !== selected) {
      clearTimeout(aiTimer.current);
      setPending(false);
      setTab("transcript");
      setPlayhead(0);
      setTranslated(false);
    }
    setPlaying(false);
    setSelected(id);
    setLibrary(false);
  }
  function openSetup(quick = false) {
    if (active) {
      open(active.id);
      return;
    }
    setSetup((prev) => ({
      ...prev,
      system: !quick,
      ...(quick ? { mode: "audio" } : {}),
    }));
    setModal("setup");
  }
  function openCapture() {
    if (!setup.permission || (!setup.mic && !setup.system)) return;
    setModal("capture");
  }
  function confirmCapture(title: string) {
    const recordingSetup = { ...setup, mode: "screen", screen: title };
    setSetup(recordingSetup);
    start(recordingSetup);
  }
  function cancelCapture() {
    setModal("setup");
  }
  function start(recordingSetup = setup) {
    if (
      active ||
      !recordingSetup.permission ||
      (!recordingSetup.mic && !recordingSetup.system) ||
      (recordingSetup.mode === "screen" && !recordingSetup.screen)
    )
      return;
    const now = new Date();
    const r: Meeting = {
      id: "record-" + ++seq.current,
      title: recordingSetup.title.trim() || "未命名会议",
      date: now.toLocaleDateString("sv-SE"),
      time: now.toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
      duration: 0,
      mode: recordingSetup.mode,
      language: recordingSetup.language,
      mic: recordingSetup.mic,
      system: recordingSetup.system,
      screen: recordingSetup.screen,
      status: "recording",
      star: false,
      count: 1,
      category: "会议纪要",
      marks: [],
      tasks: [],
      messages: [],
    };
    setRecords((prev) => [r, ...prev]);
    setActiveId(r.id);
    setFault("");
    setModal("");
    open(r.id);
    setTranslated(recordingSetup.translation);
  }
  function finish() {
    if (!active) return;
    const id = active.id,
      failed = fault === "summary";
    change(id, {
      status: "processing",
      paused: false,
      count: Math.min(6, 1 + Math.floor(active.duration / 6)),
    });
    setActiveId(null);
    setModal("");
    open(id);
    setTab("summary");
    timers.current.push(
      setTimeout(
        () => change(id, { status: failed ? "failed" : "ready" }),
        1300,
      ),
    );
  }
  function retry() {
    if (!current) return;
    const id = current.id;
    change(id, { status: "processing" });
    timers.current.push(
      setTimeout(() => change(id, { status: "ready" }), 1000),
    );
  }
  function pause() {
    if (active && fault !== "device")
      change(active.id, { paused: !active.paused });
  }
  function simulate(value: string) {
    setFault(value);
    if (active && value === "device") change(active.id, { paused: true });
    else if (active && fault === "device") change(active.id, { paused: false });
  }
  function recover() {
    setFault("");
    if (active)
      change(active.id, {
        paused: false,
        count: Math.min(6, 1 + Math.floor(active.duration / 6)),
      });
  }
  function cite(time: number) {
    setLibrary(false);
    setTab("transcript");
    setPlayhead(time);
    requestAnimationFrame(() => {
      const target = document.getElementById("meeting-line-" + time);
      target?.focus({ preventScroll: true });
      target?.scrollIntoView({ block: "center", behavior: "smooth" });
    });
  }
  function ask(q: string, ready: boolean) {
    if (!current || !ready || pending || !q.trim()) return;
    const id = current.id,
      available = lines.slice(0, current.count);
    setDrafts((v) => ({ ...v, [id]: "" }));
    change(id, { messages: [...current.messages, { role: "user", text: q }] });
    setPending(true);
    aiTimer.current = setTimeout(() => {
      let refs = available,
        text =
          "这是交互原型，没有调用真实模型。可选择下方问题体验基于原文的示例回答。";
      if (q.includes("行动")) {
        refs = available.filter((l) => l.kind === "action");
        text = refs.length
          ? refs.map((l) => `${l.owner}：${l.task}，${l.due}。`).join("\n") +
            "\n\n尚未创建待办，请先审核。"
          : "目前还没有明确的行动承诺。";
      } else if (q.includes("决定")) {
        refs = available.filter((l) => l.kind === "decision");
        text = refs.length
          ? refs.map((l) => l.text).join("\n")
          : "目前还没有明确决定。";
      } else if (q.includes("总结")) {
        text = available
          .slice(0, 3)
          .map((l) => "• " + l.text)
          .join("\n");
        refs = available.slice(0, 3);
      } else refs = [];
      setRecords((prev) =>
        prev.map((r) =>
          r.id === id
            ? {
                ...r,
                messages: [
                  ...r.messages,
                  {
                    role: "assistant",
                    text,
                    citations: refs.map((l) => ({
                      id,
                      time: l.time,
                      label: stamp(l.time),
                    })),
                  },
                ],
              }
            : r,
        ),
      );
      setPending(false);
    }, 800);
  }
  function cancelAI() {
    clearTimeout(aiTimer.current);
    setPending(false);
  }
  function importFile() {
    if (!upload) return;
    const r: Meeting = {
      ...initial()[0],
      id: "import-" + ++seq.current,
      title: upload.replace(/\.[^.]+$/, ""),
      date: new Date().toLocaleDateString("sv-SE"),
      time: "示例",
      duration: 30,
      mode: /\.(mp4|mov)$/i.test(upload) ? "screen" : "audio",
      screen: "导入画面示意",
      language: uploadLanguage,
      category: "文件导入 · 固定样例",
      star: false,
      marks: [],
      tasks: [],
      messages: [],
      status: "processing",
    };
    setRecords((prev) => [r, ...prev]);
    setModal("");
    open(r.id);
    setTab("summary");
    timers.current.push(
      setTimeout(() => change(r.id, { status: "ready" }), 1200),
    );
    notify("模拟导入中；未读取或上传文件内容");
  }
  function removeMeeting() {
    const item = records.find(r => r.id === deleteId);
    if (!item || item.id === activeId || item.status === "processing") return;
    if (selected === item.id) { cancelAI(); setPlaying(false); setSelected(null); setLibrary(true); }
    setRecords(prev => prev.filter(r => r.id !== item.id));
    setDrafts(prev => Object.fromEntries(Object.entries(prev).filter(([id]) => id !== item.id)));
    setTaskDrafts(prev => Object.fromEntries(Object.entries(prev).filter(([key]) => !key.startsWith(item.id + ":"))));
    setDeleteId(null); notify("会议已从示例列表删除；没有操作真实文件");
    requestAnimationFrame(() => document.querySelector<HTMLInputElement>('input[aria-label="搜索会议"]')?.focus());
  }
  function reset() {
    timers.current.forEach(clearTimeout);
    cancelAI();
    setRecords(initial());
    setActiveId(null);
    setSelected(null);
    setDeleteId(null);
    setLibrary(true);
    setModal("");
    setFault("");
    setPlaying(false);
    setDrafts({});
    setQuery("");
    setFilter("all");
    setSetup(defaultSetup());
    setTaskKey("");
    setTaskDrafts({});
    setUpload("");
  }
  return {
    deleteId,
    setDeleteId,
    removeMeeting,
    records,
    current,
    active,
    library,
    setLibrary,
    tab,
    setTab,
    modal,
    setModal,
    setup,
    setSetup,
    query,
    setQuery,
    filter,
    setFilter,
    translated,
    setTranslated,
    drafts,
    setDrafts,
    pending,
    upload,
    setUpload,
    uploadError,
    setUploadError,
    uploadLanguage,
    setUploadLanguage,
    task,
    setTask,
    taskKey,
    setTaskKey,
    taskDrafts,
    setTaskDrafts,
    playing,
    setPlaying,
    playhead,
    setPlayhead,
    fault,
    change,
    open,
    openSetup,
    openCapture,
    confirmCapture,
    cancelCapture,
    start,
    finish,
    retry,
    pause,
    simulate,
    recover,
    cite,
    ask,
    cancelAI,
    importFile,
    reset,
  };
}
type Model = ReturnType<typeof useMeetings>;
export function MeetingAgent({
  m,
  ready,
  model,
}: {
  m: Model;
  ready: boolean;
  model: string;
}) {
  const r = m.current;
  return (
    <Chat
      messages={r?.messages || []}
      draft={m.drafts[r?.id || ""] || ""}
      setDraft={(value) =>
        r && m.setDrafts((prev) => ({ ...prev, [r.id]: value }))
      }
      send={(q) => m.ask(q, ready)}
      pending={m.pending}
      stop={m.cancelAI}
      ready={ready}
      model={model}
      scope={r ? "当前会议：" + r.title : "先选择一场会议"}
      enabled={!!r}
      prompts={["总结目前的讨论", "有哪些已确认的决定？", "提取行动项"]}
      onCite={(c) => m.cite(c.time || 0)}
      reset={() => {
        m.cancelAI();
        if (r) {
          m.change(r.id, { messages: [] });
          m.setDrafts((prev) => ({ ...prev, [r.id]: "" }));
        }
      }}
    />
  );
}
export function Meetings({
  m,
  notify,
  root,
}: {
  m: Model;
  notify: (s: string) => void;
  root: string;
}) {
  const r = m.current,
    live = r?.id === m.active?.id;
  if (m.library || !r) {
    const filtered = m.records.filter(
      (r) =>
        (m.filter !== "star" || r.star) &&
        r.title.toLowerCase().includes(m.query.toLowerCase()),
    );
    return (
      <>
        <Heading
          eyebrow="你的会议工作空间"
          title="专注讨论，留住每个好想法。"
          description="从一句话到一个决定，让会议有迹可循。"
        />
        <p className="m-0 break-all text-[12px] leading-[1.8] text-[#8c8c8c]">会议文件位置：{root}/Meetings</p>
        <div
          className="grid grid-cols-1 gap-[16px] min-[1100px]:grid-cols-3"
          data-testid="meeting-entries"
        >
          {[
            {
              label: "即时录音",
              desc: "录下自己的声音与现场对话",
              Icon: Mic,
              fn: () => m.openSetup(true),
            },
            {
              label: "录制会议",
              desc: "系统声音与麦克风，可选画面",
              Icon: Monitor,
              fn: () => m.openSetup(),
            },
            {
              label: "上传文件",
              desc: "导入已有的音频或视频",
              Icon: Upload,
              fn: () => m.setModal("upload"),
            },
          ].map(({ label, desc, Icon, fn }) => (
            <Button
              key={label}
              variant="outline"
              h="auto"
              px={24}
              py={24}
              fullWidth
              onClick={fn}
              classNames={{
                root: "!ring-[#e6e6e6] hover:!bg-[#fafafa]",
                inner: "justify-start",
                label: "block whitespace-normal text-left",
              }}
            >
              <Icon size={24} color="#595959" aria-hidden />
              <h2 className="mb-[8px] mt-[20px] text-[16px] font-medium">
                {label}
              </h2>
              <p className="m-0 text-[12px] font-normal leading-[1.7] text-[#8c8c8c]">
                {desc}
              </p>
            </Button>
          ))}
        </div>
        {m.active && (
          <Button
            variant="light"
            color="blue"
            justify="space-between"
            onClick={() => m.open(m.active!.id)}
          >
            {m.active.paused ? "已暂停" : "录制中"} · {m.active.title} ·{" "}
            {clock(m.active.duration)} →
          </Button>
        )}
        <div className="mt-[16px] flex flex-wrap items-center justify-between gap-[16px]">
          <h2 className="m-0 text-[18px] font-medium">我的会议</h2>
          <Input
            aria-label="搜索会议"
            placeholder="搜索会议"
            leftSection={<Search size={16} />}
            value={m.query}
            onChange={(e) => m.setQuery(e.currentTarget.value)}
          />
        </div>
        <Tabs variant="pills" value={m.filter} onChange={m.setFilter}>
          <Tabs.List aria-label="筛选会议">
            <Tabs.Tab value="all">全部会议</Tabs.Tab>
            <Tabs.Tab value="star" leftSection={<Star size={14} />}>
              已收藏
            </Tabs.Tab>
          </Tabs.List>
        </Tabs>
        <Table appearance="meeting" highlightOnHover>
          <Table.Thead>
            <Table.Tr>
              <Table.Th w="55%">会议名称</Table.Th>
              <Table.Th>时长 / 日期</Table.Th>
              <Table.Th w={92}>状态</Table.Th>
              <Table.Th w={80}>
                <span className="sr-only">操作</span>
              </Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {filtered.map((item) => (
              <Table.Tr key={item.id}>
                <Table.Td>
                  <Button
                    variant="subtle"
                    h="auto"
                    py={8}
                    fullWidth
                    justify="flex-start"
                    onClick={() => m.open(item.id)}
                    leftSection={
                      item.mode === "screen" ? (
                        <Monitor size={20} />
                      ) : (
                        <FileAudio size={20} />
                      )
                    }
                    classNames={{ label: "block whitespace-normal text-left" }}
                  >
                    {item.title}
                    <span className="mt-[4px] block text-[12px] font-normal text-[#8c8c8c]">
                      {item.language} · {item.category}
                    </span>
                  </Button>
                </Table.Td>
                <Table.Td>
                  {stamp(item.duration)}
                  <br />
                  {item.date.slice(5)}
                </Table.Td>
                <Table.Td>
                  <Tag
                    size="sm"
                    tone={
                      item.status === "ready"
                        ? "success"
                        : item.status === "failed"
                          ? "warning"
                          : "neutral"
                    }
                  >
                    {item.id === m.active?.id
                      ? item.paused
                        ? "已暂停"
                        : "录制中"
                      : item.status === "ready"
                        ? "已整理"
                        : item.status === "processing"
                          ? "整理中"
                          : "待重试"}
                  </Tag>
                </Table.Td>
                <Table.Td>
                  <div className="flex gap-[4px]">
                  <IconButton
                    label={(item.star ? "取消收藏" : "收藏") + " " + item.title}
                    pressed={item.star}
                    onClick={() => m.change(item.id, { star: !item.star })}
                  >
                    <Star
                      size={16}
                      fill={item.star ? "#fa8c16" : "none"}
                      color={item.star ? "#fa8c16" : "#8c8c8c"}
                    />
                  </IconButton>
                  <IconButton label={"删除会议 " + item.title} disabled={item.id === m.active?.id || item.status === "processing"} onClick={() => m.setDeleteId(item.id)}><Trash2 size={16} color="#8c8c8c" /></IconButton>
                  </div>
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
        {!filtered.length && (
          <Empty
            title="没有找到会议"
            description="调整搜索条件，或切换到全部会议。"
          />
        )}
        <p className="mt-auto pt-[24px] text-[12px] text-[#8c8c8c]">
          全部为示例数据。录制、文件导入和 AI 均为交互演示。
        </p>
      </>
    );
  }
  const captured = lines.slice(0, r.count),
    tasks = captured.filter((l) => l.kind === "action");
  return (
    <>
      <div className="flex items-center justify-between">
        <Button
          variant="subtle"
          leftSection={<ChevronLeft size={16} />}
          onClick={() => {
            m.setPlaying(false);
            m.setLibrary(true);
          }}
        >
          我的会议
        </Button>
        <IconButton
          label={r.star ? "取消收藏会议" : "收藏会议"}
          pressed={r.star}
          onClick={() => m.change(r.id, { star: !r.star })}
        >
          <Star size={17} fill={r.star ? "#fa8c16" : "none"} />
        </IconButton>
      </div>
      <Heading
        title={r.title}
        description={`${r.date} · ${r.time} · ${r.language} · ${r.mode === "screen" ? "屏幕与音频" : "仅录音"}`}
      />
      {(!live || r.mode === "screen") && <section aria-label="会议音视频" className="flex flex-col gap-[12px]">
          {r.mode === "screen" && (
            <Panel>
              <div className="py-[24px] text-center">
                <Monitor size={28} color="#8c8c8c" />
                <h3 className="mt-[16px] text-[20px] font-medium">
                  把讨论，变成下一步。
                </h3>
                <p className="mb-0 text-[12px] text-[#8c8c8c]">
                  {r.screen} · 静态画面示意
                </p>
              </div>
            </Panel>
          )}
        {!live && (
          <div className="flex w-full flex-col gap-[8px]">
            <div className="flex items-center gap-[12px]">
              <IconButton
                label={m.playing ? "暂停回放" : "演示回放"}
                onClick={() => m.setPlaying(!m.playing)}
              >
                {m.playing ? <Pause size={16} /> : <Play size={16} />}
              </IconButton>
              <small>{stamp(m.playhead)}</small>
              <input
                className="min-w-0 flex-1 accent-[#262626]"
                type="range"
                aria-label="演示播放位置"
                min={0}
                max={r.duration}
                value={m.playhead}
                onChange={(e) => m.setPlayhead(Number(e.target.value))}
              />
              <small>{stamp(r.duration)}</small>
            </div>
            <small className="text-center text-[#8c8c8c]">
              回放交互示意 · 无真实音视频
            </small>
          </div>
        )}
      </section>}
      <div className="flex flex-wrap items-center justify-between gap-[16px]">
        <Tag tone={live ? "warning" : "success"}>
          {live
            ? r.paused
              ? "已暂停"
              : "录制中"
            : r.status === "ready"
              ? "已整理"
              : r.status === "failed"
                ? "总结失败"
                : "整理中"}
        </Tag>
        {live && (
          <Select
            aria-label="演示状态"
            w={200}
            size="sm"
            value={m.fault}
            onChange={(v) => m.simulate(v || "")}
            data={[
              { value: "", label: "正常录制" },
              { value: "device", label: "麦克风断开" },
              { value: "lag", label: "转写延迟" },
              { value: "summary", label: "结束后总结失败" },
            ]}
          />
        )}
      </div>
      {live && ["device", "lag"].includes(m.fault) && (
        <Alert
          status="warning"
          title={
            m.fault === "device"
              ? "麦克风连接中断，已暂停"
              : "转写暂时落后，录制仍在继续"
          }
          h="auto"
          classNames={{ message: "whitespace-normal" }}
        >
          <Button variant="subtle" onClick={m.recover}>
            {m.fault === "device" ? "切回内置麦克风并继续" : "恢复转写"}
          </Button>
        </Alert>
      )}
      <Tabs value={m.tab} onChange={m.setTab} keepMounted={false}>
        <Tabs.List aria-label="会议内容">
          <Tabs.Tab value="transcript">原文</Tabs.Tab>
          <Tabs.Tab value="summary">总结</Tabs.Tab>
          <Tabs.Tab value="tasks">行动项</Tabs.Tab>
        </Tabs.List>
        <Tabs.Panel value="transcript" pt={16}>
          <div className="mb-[16px] flex items-center justify-between gap-[12px]">
            <span className="text-[12px] text-[#8c8c8c]">
              {captured.length} 段原文 · 说话人标签为示例
            </span>
            <Button
              variant="subtle"
              size="xs"
              onClick={() => m.setTranslated(!m.translated)}
            >
              {m.translated ? "隐藏译文" : "显示译文"}
            </Button>
          </div>
          {captured.map((l) => (
            <article
              id={"meeting-line-" + l.time}
              key={l.time}
              className="flex gap-[16px] rounded-[8px] py-[20px] focus:bg-[#f3f7ff]"
              tabIndex={-1}
            >
              <span className="flex size-[32px] shrink-0 items-center justify-center rounded-[8px] bg-[#f5f5f5] text-[12px] text-[#595959]">
                {l.initials}
              </span>
              <div>
                <div className="mb-[8px] flex items-center gap-[8px]">
                  <strong className="text-[13px] font-medium">
                    {l.speaker}
                  </strong>
                  <Button
                    variant="subtle"
                    size="xs"
                    color="blue"
                    onClick={() => m.cite(l.time)}
                  >
                    {stamp(l.time)} ↗
                  </Button>
                  {r.marks.includes(l.time) && (
                    <Tag tone="warning" size="sm">
                      重点
                    </Tag>
                  )}
                </div>
                <p className="mb-0 text-[14px] leading-[1.9]">{l.text}</p>
                {m.translated && (
                  <p className="mt-[12px] border-0 border-l-2 border-solid border-[#e6e6e6] pl-[12px] text-[13px] leading-[1.8] text-[#8c8c8c]">
                    {l.en}
                  </p>
                )}
              </div>
            </article>
          ))}
          {live && (
            <p className="text-[12px] text-[#8c8c8c]">
              {r.paused
                ? "录制已暂停"
                : r.count === 6
                  ? "示例片段已显示，可结束录制查看总结"
                  : "正在聆听 · 示例原文逐段出现"}
            </p>
          )}
        </Tabs.Panel>
        <Tabs.Panel value="summary" pt={24}>
          {r.status === "processing" ? (
            <Empty
              title="正在整理这场会议…"
              description="原文已保留，正在模拟生成总结与行动项。"
            />
          ) : r.status === "failed" ? (
            <Panel>
              <Empty
                title="总结暂未完成"
                description="演示模型不可用，原文仍可查看。"
              />
              <Button onClick={m.retry}>重新整理</Button>
            </Panel>
          ) : (
            <div className="flex flex-col gap-[24px]">
              <Heading
                title="让每场会议，都有下一步。"
                description="以下内容仅依据已经显示的示例原文。"
              />
              <section>
                <h3 className="text-[16px] font-medium">讨论要点</h3>
                {captured
                  .filter((l) => ["context", "suggestion"].includes(l.kind))
                  .map((l) => (
                    <p key={l.time} className="text-[14px] leading-[1.9]">
                      {l.text}{" "}
                      <Button
                        variant="subtle"
                        size="xs"
                        color="blue"
                        onClick={() => m.cite(l.time)}
                      >
                        {stamp(l.time)} ↗
                      </Button>
                    </p>
                  ))}
              </section>
              <section>
                <h3 className="text-[16px] font-medium">已确认的决定</h3>
                {captured.some((l) => l.kind === "decision") ? (
                  captured
                    .filter((l) => l.kind === "decision")
                    .map((l) => (
                      <Panel key={l.time}>
                        <p className="m-0 text-[14px] leading-[1.9]">
                          {l.text}{" "}
                          <Button
                            variant="subtle"
                            size="xs"
                            color="blue"
                            onClick={() => m.cite(l.time)}
                          >
                            {stamp(l.time)} ↗
                          </Button>
                        </p>
                      </Panel>
                    ))
                ) : (
                  <p className="text-[14px] text-[#8c8c8c]">
                    当前原文中还没有明确决定。
                  </p>
                )}
              </section>
              <p className="text-[14px] text-[#8c8c8c]">
                识别到 {tasks.length} 项行动承诺，可在「行动项」中审核。
              </p>
            </div>
          )}
        </Tabs.Panel>
        <Tabs.Panel value="tasks" pt={24}>
          <Heading
            title="把承诺变成下一步。"
            description="先审核负责人和时间，再加入待办。"
          />
          {tasks.length ? (
            tasks.map((l) => (
              <div
                key={l.time}
                className="flex flex-wrap items-center gap-[16px] border-0 border-b border-solid border-[#f0f0f0] py-[24px]"
              >
                <Check size={18} color="#0dc15b" />
                <div className="min-w-[150px] flex-1">
                  <h3 className="mb-[8px] text-[14px] font-medium">
                    {r.taskEdits?.[l.time]?.task || l.task}
                  </h3>
                  <p className="m-0 text-[12px] text-[#8c8c8c]">
                    {r.taskEdits?.[l.time]?.owner || l.owner} ·{" "}
                    {r.taskEdits?.[l.time]?.due || l.due}{" "}
                    <Button
                      size="xs"
                      variant="subtle"
                      color="blue"
                      onClick={() => m.cite(l.time)}
                    >
                      {stamp(l.time)} ↗
                    </Button>
                  </p>
                </div>
                <Button
                  variant="outline"
                  disabled={r.tasks.includes(l.time)}
                  onClick={() => {
                    const key = r.id + ":" + l.time;
                    m.setTaskKey(key);
                    m.setTask(
                      m.taskDrafts[key] || {
                        time: l.time,
                        task: l.task || "",
                        owner: l.owner || "",
                        due: l.due || "",
                      },
                    );
                    m.setModal("task");
                  }}
                >
                  {r.tasks.includes(l.time) ? "已加入 · 演示" : "加入待办"}
                </Button>
              </div>
            ))
          ) : (
            <Empty
              title="尚无明确行动项"
              description="明确的负责人和行动承诺，会在这里等待确认。"
            />
          )}
        </Tabs.Panel>
      </Tabs>
      {live && <footer className="sticky bottom-[-32px] z-10 mt-auto flex flex-wrap items-center justify-between gap-[12px] border-0 border-t border-solid border-[#f0f0f0] bg-white py-[16px]">
            <div className="flex items-center gap-[8px]">
              <span className="size-[6px] rounded-full bg-[#f53f3f]" />
              <span
                className="text-[14px] tabular-nums"
                data-testid="recording-clock"
              >
                {clock(r.duration)}
              </span>
            </div>
            <div className="flex items-center gap-[8px]">
              <IconButton
                label="标记重点"
                onClick={() => {
                  const t = captured.at(-1)?.time || 0;
                  m.change(r.id, {
                    marks: Array.from(new Set([...r.marks, t])),
                  });
                  notify("已标记最近一段原文");
                }}
              >
                <Bookmark size={16} />
              </IconButton>
              <IconButton
                label={r.paused ? "继续录制" : "暂停录制"}
                disabled={m.fault === "device"}
                onClick={m.pause}
              >
                {r.paused ? <Play size={16} /> : <Pause size={16} />}
              </IconButton>
              <Button
                variant="light"
                color="red"
                leftSection={<Square size={13} />}
                onClick={() => m.setModal("stop")}
              >
                结束录制
              </Button>
            </div>
      </footer>}
    </>
  );
}
export function MeetingDialogs({
  m,
  notify,
}: {
  m: Model;
  notify: (s: string) => void;
}) {
  const s = m.setup;
  const set = <K extends keyof typeof s>(key: K, value: (typeof s)[K]) =>
    m.setSetup((prev) => ({ ...prev, [key]: value }));
  const close = () => m.setModal("");
  return (
    <>
      <Modal opened={m.deleteId !== null} onClose={() => m.setDeleteId(null)} title="删除会议？" size={460}>
        <div className="flex flex-col gap-[20px]">
          <p className="m-0 break-words text-[16px] font-medium">{m.records.find(r => r.id === m.deleteId)?.title}</p>
          <p className="m-0 text-[14px] leading-[1.8] text-[#595959]">将删除这场会议的录音或视频、原文、总结及对话记录。此操作无法撤销。</p>
          <p className="m-0 text-[12px] text-[#8c8c8c]">当前仅删除原型中的示例，不影响真实文件或 iPhone 备份。</p>
          <div className="flex justify-end gap-[12px]"><Button variant="subtle" onClick={() => m.setDeleteId(null)}>取消</Button><Button color="red" onClick={m.removeMeeting}>删除会议</Button></div>
        </div>
      </Modal>
      {m.modal === "capture" && (
        <CapturePicker
          selectedTitle={s.screen}
          onCancel={m.cancelCapture}
          onConfirm={m.confirmCapture}
        />
      )}
      <Modal
        opened={m.modal === "setup"}
        onClose={close}
        title="录制一场会议"
        layout="form"
        footer={
          <>
            <span className="text-[12px] text-[#8c8c8c]">
              演示设置 · 关闭后保留草稿
            </span>
            <Button
              disabled={!s.permission || (!s.mic && !s.system)}
              onClick={() =>
                s.mode === "screen" ? m.openCapture() : m.start()
              }
              leftSection={<Mic size={16} />}
            >
              {s.mode === "screen" ? "下一步：选择画面" : "开始录制"}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-[24px]">
          <p className="mb-0 text-[14px] text-[#8c8c8c]">
            {s.mode === "screen"
              ? "第 1 步 / 录制设置 · 下一步选择画面"
              : "仅录音：完成设置后直接开始，无需选择屏幕。"}
          </p>
          <Input
            w="100%"
            label="会议名称"
            placeholder="例如：产品评审会议"
            value={s.title}
            onChange={(e) => set("title", e.currentTarget.value)}
            maxLength={80}
          />
          <Radio.Group
            value={s.mode}
            onChange={(v) => set("mode", v)}
            label="录制方式"
          >
            <div className="mt-[12px] grid grid-cols-2 gap-[16px]">
              <Radio value="audio" label="仅录音" />
              <Radio value="screen" label="屏幕与音频" />
            </div>
          </Radio.Group>
          {s.mode === "screen" && (
            <p className="m-0 text-[13px] leading-[1.7] text-[#8c8c8c]">
              下一步选择整个屏幕或应用窗口，确认后开始录制。
            </p>
          )}
          <Switch
            label="系统声音"
            checked={s.system}
            onChange={(e) => set("system", e.currentTarget.checked)}
            description="包含会议应用、浏览器及其他应用声音"
          />
          <Switch
            label="我的麦克风"
            checked={s.mic}
            onChange={(e) => set("mic", e.currentTarget.checked)}
          />
          {s.mic && (
            <Select
              label="麦克风设备"
              value={s.device}
              onChange={(v) => set("device", v || s.device)}
              data={["MacBook Air 麦克风", "AirPods Pro 麦克风"]}
            />
          )}
          <Select
            label="转写语言"
            value={s.language}
            onChange={(v) => set("language", v || "中文")}
            data={["中文", "English", "日本語", "中英双语"]}
          />
          <Switch
            label="实时翻译"
            checked={s.translation}
            onChange={(e) => set("translation", e.currentTarget.checked)}
          />
          {s.translation && (
            <Select
              label="目标语言"
              value={s.target}
              onChange={(v) => set("target", v || "英语")}
              data={["英语", "中文", "日本語"]}
              description="翻译能力仅演示；原文与译文为固定中英样例。"
            />
          )}
          <div className="flex items-center justify-between gap-[12px]">
            <Tag tone={s.permission ? "success" : "warning"}>
              {s.permission ? "权限已就绪 · 演示" : "需要麦克风与系统录制权限"}
            </Tag>
            <Button
              variant="subtle"
              size="xs"
              onClick={() => set("permission", !s.permission)}
            >
              {s.permission ? "模拟未授权" : "模拟授权"}
            </Button>
          </div>
          {!s.mic && !s.system && (
            <p className="m-0 text-[13px] text-[#f53f3f]">至少开启一个音源。</p>
          )}
          <p className="mb-0 text-[12px] leading-[1.8] text-[#8c8c8c]">
            录制前请告知参会人。文件拟保存在这台 Mac，AI
            沿用你的模型设置。原型不采集音视频。
          </p>
        </div>
      </Modal>
      <Modal
        opened={m.modal === "upload"}
        onClose={close}
        title="上传文件"
        layout="form"
        footer={
          <>
            <Button variant="outline" onClick={close}>
              取消
            </Button>
            <Button disabled={!m.upload} onClick={m.importFile}>
              模拟导入并整理
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-[24px]">
          <label className="flex flex-col items-center gap-[16px] rounded-[12px] border border-dashed border-[#bfbfbf] bg-[#fafafa] px-[24px] py-[32px]">
            <FileUp size={28} />
            <strong className="break-all text-[14px] font-medium">
              {m.upload || "选择音频或视频文件"}
            </strong>
            <span className="text-[12px] text-[#8c8c8c]">
              MP3、M4A、WAV、MP4、MOV
            </span>
            <input
              aria-label="选择音视频文件"
              className="max-w-full text-[12px]"
              type="file"
              accept=".mp3,.m4a,.wav,.mp4,.mov"
              onChange={(e) => {
                const f = e.currentTarget.files?.[0];
                if (!f) return;
                const valid = /\.(mp3|m4a|wav|mp4|mov)$/i.test(f.name);
                m.setUpload(valid ? f.name : "");
                m.setUploadError(valid ? "" : "请选择支持的音视频格式。");
              }}
            />
          </label>
          {m.uploadError && (
            <p role="alert" className="text-[13px] text-[#f53f3f]">
              {m.uploadError}
            </p>
          )}
          <Button
            variant="subtle"
            onClick={() => {
              m.setUpload("产品讨论示例.m4a");
              m.setUploadError("");
            }}
          >
            使用示例文件体验
          </Button>
          <Select
            label="转写语言"
            value={m.uploadLanguage}
            onChange={(v) => m.setUploadLanguage(v || "中文")}
            data={["中文", "English", "日本語", "中英双语"]}
          />
          <p className="m-0 text-[12px] leading-[1.8] text-[#8c8c8c]">
            只使用文件名演示流程，不读取或上传文件内容。转写与总结均来自固定样例。
          </p>
        </div>
      </Modal>
      <Modal
        opened={m.modal === "stop"}
        onClose={close}
        title="结束这场会议？"
        footer={
          <div className="flex justify-end gap-[12px]">
            <Button variant="outline" onClick={close} data-autofocus>
              继续会议
            </Button>
            <Button onClick={m.finish}>结束并整理</Button>
          </div>
        }
      >
        <p>{m.active?.title}</p>
        <p className="text-[14px] text-[#8c8c8c]">
          结束后保留原文，并整理总结与行动项。
        </p>
      </Modal>
      <Modal
        opened={m.modal === "task"}
        onClose={close}
        title="确认行动项"
        layout="form"
        footer={
          <>
            <small className="text-[#8c8c8c]">不创建系统提醒</small>
            <Button type="submit" form="task-form">
              确认加入
            </Button>
          </>
        }
      >
        <form
          id="task-form"
          onSubmit={(e) => {
            e.preventDefault();
            const r = m.current;
            if (!r) return;
            m.change(r.id, {
              tasks: Array.from(new Set([...r.tasks, m.task.time])),
              taskEdits: { ...r.taskEdits, [m.task.time]: m.task },
            });
            close();
            notify("已加入此原型的待办");
          }}
          className="flex flex-col gap-[16px]"
        >
          {[
            ["task", "待办事项"],
            ["owner", "负责人"],
            ["due", "计划时间"],
          ].map(([key, label]) => (
            <Input
              key={key}
              label={label}
              required
              w="100%"
              value={m.task[key as "task" | "owner" | "due"]}
              onChange={(e) => {
                const value = e.currentTarget.value;
                const next = { ...m.task, [key]: value };
                m.setTask(next);
                m.setTaskDrafts((prev) => ({ ...prev, [m.taskKey]: next }));
              }}
            />
          ))}
        </form>
      </Modal>
    </>
  );
}
