import { useCallback, useEffect, useRef, useState } from "react";
import {
  Settings,
  CalendarDays,
  FolderOpen,
  Cpu,
  HelpCircle,
  LayoutDashboard,
  Menu,
  Mic,
  Monitor,
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  Smartphone,
} from "lucide-react";
import { useMediaQuery } from "@mantine/hooks";
import {
  Alert,
  Button,
  Empty,
  IconButton,
  Modal,
  Select,
  Tag,
  ThreeColumnLayout,
  Tooltip,
  clock,
} from "./components/ui";
import {
  CompanionPage,
  CompanionDialogs,
  useCompanion,
} from "./features/Companion";
import {
  Meetings,
  MeetingAgent,
  MeetingDialogs,
  useMeetings,
} from "./features/Meetings";
import demo from "./demo.json";
import { DirectorySettings, DirectoryDialog, useDirectory } from "./features/Settings";
import { DailyRecords, DailyAgent, useDailyRecords } from "./features/DailyRecords";
const pages = [
  { id: "overview", name: "概览", Icon: LayoutDashboard },
  { id: "models", name: "模型库", Icon: Cpu },
  { id: "meetings", name: "会议", Icon: Monitor },
  { id: "daily", name: "每日记录", Icon: CalendarDays },
  { id: "settings", name: "设置", Icon: Settings },
];
const routes = [...pages, { id: "privacy", name: "设置", Icon: Settings }];
export default function App() {
  const [page, setPage] = useState(() =>
    routes.some((p) => p.id === location.hash.slice(1))
      ? location.hash.slice(1)
      : "meetings",
  );
  const [notice, setNotice] = useState(""),
    [scenario, setScenario] = useState<string | null>("ready"),
    [menuOpened, setMenuOpened] = useState(true),
    [collapsed, setCollapsed] = useState(false),
    [agentOpened, setAgentOpened] = useState(true),
    [mobileMenu, setMobileMenu] = useState(false),
    [mobileAI, setMobileAI] = useState(false),
    [guide, setGuide] = useState(false),
    [menuPreview, setMenuPreview] = useState(false);
  const dailyCitation = useRef<string | null>(null);
  const narrow = useMediaQuery("(max-width: 760px)"),
    medium = useMediaQuery("(max-width: 1100px)");
  const notify = useCallback((text: string) => setNotice(text), []),
    c = useCompanion(notify),
    m = useMeetings(notify),
    directory = useDirectory(notify),
    daily = useDailyRecords(notify, c.state.network && c.state.devices.length > 0);
  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(""), 5000);
    return () => clearTimeout(timer);
  }, [notice]);
  useEffect(() => {
    const update = () => {
      const p = location.hash.slice(1);
      setPage(routes.some((x) => x.id === p) ? p : "meetings");
    };
    addEventListener("hashchange", update);
    return () => removeEventListener("hashchange", update);
  }, []);
  useEffect(() => {
    if (medium) setCollapsed(true);
  }, [medium]);
  const navigate = (id: string) => {
    setPage(id);
    location.hash = id;
    setMobileMenu(false);
    m.setPlaying(false);
  };
  const hasAgent = page === "meetings" || page === "daily";
  const ready = c.state.loaded !== null,
    model = ready ? demo.models[c.state.loaded!].name : "LLM 尚未加载";
  const menu = (small: boolean) => (
    <div className="flex min-h-0 flex-1 flex-col">
      <nav aria-label="主导航" className="mt-[16px] flex flex-col gap-[8px]">
        {pages.map((p) => (
          <div key={p.id}>
          <Tooltip
            label={p.name}
            disabled={!small}
            position="right"
            openDelay={400}
          >
            <Button
              variant={(page === p.id || (p.id === "settings" && page === "privacy")) ? "light" : "subtle"}
              w={small ? 40 : "100%"}
              h={40}
              px={small ? 0 : 12}
              justify={small ? "center" : "flex-start"}
              leftSection={small ? undefined : <p.Icon size={18} aria-hidden />}
              aria-label={p.name}
              aria-current={(page === p.id || (p.id === "settings" && page === "privacy")) ? "page" : undefined}
              onClick={() => navigate(p.id)}
              classNames={{
                root:
                  (page === p.id || (p.id === "settings" && page === "privacy"))
                    ? "!bg-[#ebebeb]"
                    : "!bg-transparent hover:!bg-[#ebebeb]",
              }}
            >
              {small ? <p.Icon size={18} aria-hidden /> : p.name}
            </Button>
          </Tooltip>
          {p.id === "settings" && !small && ["settings", "privacy"].includes(page) && (
            <div className="ml-[20px] mt-[8px] flex flex-col gap-[4px] border-0 border-l border-solid border-[#e6e6e6] pl-[8px]">
              {[{ id: "settings", name: "主目录设置", Icon: FolderOpen }, { id: "privacy", name: "隐私与说明", Icon: ShieldCheck }].map(child =>
                <Button key={child.id} variant={page === child.id ? "light" : "subtle"} justify="flex-start" size="sm" leftSection={<child.Icon size={16} />} aria-current={page === child.id ? "page" : undefined} onClick={() => navigate(child.id)}>{child.name}</Button>)}
            </div>
          )}
          </div>
        ))}
      </nav>
      {!small && (
        <div className="mt-auto px-[8px] pt-[32px]">
          <Tag
            size="sm"
            tone={c.state.service && c.state.network ? "success" : "neutral"}
          >
            {c.state.service && c.state.network
              ? "本地服务已开启"
              : "本地服务未就绪"}
          </Tag>
          <p className="mb-0 mt-[12px] text-[11px] leading-[1.8] text-[#8c8c8c]">
            macOS · Apple silicon
            <br />
            配置与连接均为演示
          </p>
        </div>
      )}
    </div>
  );
  // Menu icon is the button content; preserve its accessible label while labels collapse.
  const agent =
    page === "meetings" ? (
      <MeetingAgent m={m} ready={ready} model={model} />
    ) : page === "daily" ? (
      <DailyAgent d={daily} ready={ready} model={model} onCite={id => { if (narrow) { dailyCitation.current = id; setMobileAI(false); } else daily.cite(id); }} />
    ) : (
      <Empty
        title="与你的记录对话"
        description="进入会议或每日记录，使用对应资料进行提问。"
      />
    );
  const reset = () => {
    m.reset();
    directory.reset();
    daily.reset();
    c.scenario(scenario || "ready");
    notify("演示数据已重置");
  };
  return (
    <>
      <div className="mx-auto flex max-w-[1560px] flex-wrap items-center justify-between gap-[12px] px-[20px] py-[16px]">
        <div className="flex items-center gap-[12px]">
          <strong className="text-[14px] font-semibold">EurekaLife Mac</strong>
          <span className="text-[12px] text-[#8c8c8c]">
            产品原型 · 标准组件
          </span>
        </div>
        <div className="flex items-center gap-[8px]">
          <Select
            aria-label="全局演示状态"
            size="sm"
            w={146}
            value={scenario}
            onChange={(value) => {
              setScenario(value);
              c.scenario(value || "ready");
              if (value === "download" || value === "error") navigate("models");
              else if (value !== "ready") navigate("overview");
            }}
            data={[
              { value: "ready", label: "日常使用" },
              { value: "first", label: "首次打开" },
              { value: "download", label: "下载模型" },
              { value: "error", label: "下载失败" },
              { value: "network", label: "网络不可达" },
              { value: "pressure", label: "内存压力偏高" },
              { value: "keychain", label: "钥匙串授权" },
            ]}
          />
          <IconButton label="重置原型" onClick={reset}>
            <RotateCcw size={16} />
          </IconButton>
          <IconButton label="功能说明" onClick={() => setGuide(true)}>
            <HelpCircle size={18} />
          </IconButton>
        </div>
      </div>
      <div className="mx-auto max-w-[1560px] px-[20px] max-[760px]:px-0">
        <div className="overflow-hidden rounded-[12px] border border-solid border-[#e6e6e6] bg-white shadow-[0_12px_48px_#00000008] max-[760px]:rounded-none">
          <div className="flex h-[36px] items-center justify-between border-0 border-b border-solid border-[#f0f0f0] bg-[#fafafa] px-[16px]">
            <span className="flex w-[100px] gap-[8px]" aria-hidden>
              <i className="size-[10px] rounded-full bg-[#ff5f57]" />
              <i className="size-[10px] rounded-full bg-[#febc2e]" />
              <i className="size-[10px] rounded-full bg-[#28c840]" />
            </span>
            <span className="text-[11px] text-[#8c8c8c]">
              EurekaLife Companion
            </span>
            <Button
              variant="subtle"
              size="xs"
              onClick={() => setMenuPreview(true)}
            >
              菜单栏预览
            </Button>
          </div>
          <ThreeColumnLayout
            h={narrow ? "calc(100dvh - 156px)" : "calc(100dvh - 132px)"}
            mih={600}
            bdrs={0}
            bd={0}
            title={routes.find((p) => p.id === page)?.name}
            menuTitle={
              <a
                href="#overview"
                aria-label="EurekaLife 概览"
                className="flex min-w-0 items-center gap-[8px] no-underline"
              >
                <img
                  src="./assets/app-icon.png"
                  width={28}
                  height={28}
                  className="shrink-0 rounded-[7px]"
                  alt=""
                />
                <span className="text-[16px] font-semibold tracking-[-0.4px] text-[#262626]">
                  EurekaLife
                </span>
              </a>
            }
            agentTitle="Ask AI"
            showMenuCollapseButton={false}
            retainMenuRail={!narrow}
            withAgent={hasAgent}
            defaultMenuWidth={220}
            defaultAgentWidth={320}
            menuOpened={!narrow && menuOpened}
            onMenuOpenedChange={(v) =>
              narrow ? setMobileMenu(v) : setMenuOpened(v)
            }
            menuCollapsed={collapsed}
            onMenuCollapsedChange={setCollapsed}
            agentOpened={!narrow && agentOpened}
            onAgentOpenedChange={(v) =>
              narrow ? setMobileAI(v) : setAgentOpened(v)
            }
            menu={menu}
            agent={agent}
          >
            <main
              className="flex min-h-0 min-w-0 flex-1 flex-col gap-[16px]"
              data-page={page}
            >
              {["settings", "privacy"].includes(page) && <div role="group" aria-label="设置分类" className="mb-[8px] flex flex-wrap gap-[8px]">
                <Button variant={page === "settings" ? "light" : "subtle"} leftSection={<FolderOpen size={16} />} aria-pressed={page === "settings"} onClick={() => navigate("settings")}>主目录设置</Button>
                <Button variant={page === "privacy" ? "light" : "subtle"} leftSection={<ShieldCheck size={16} />} aria-pressed={page === "privacy"} onClick={() => navigate("privacy")}>隐私与说明</Button>
              </div>}
              {page === "models" && <div className="flex flex-wrap items-center gap-[8px] text-[12px] text-[#8c8c8c]"><span className="break-all">模型位置：{directory.path}/Models</span><Button size="xs" variant="subtle" onClick={() => navigate("settings")}>管理主目录</Button></div>}
              {page === "settings" ? <DirectorySettings directory={directory} blocked={!!m.active || m.records.some(r => r.status === "processing") || daily.busy || c.operation !== null || c.state.active || m.pending || !!daily.pendingDay} /> : page === "daily" ? <DailyRecords model={daily} root={directory.path} deviceName={c.state.devices[0]} network={c.state.network} openSettings={() => navigate("settings")} openDevices={() => navigate("overview")} /> : page === "meetings" ? (
                <Meetings m={m} notify={notify} root={directory.path} />
              ) : (
                <CompanionPage c={c} page={page} navigate={navigate} />
              )}
            </main>
          </ThreeColumnLayout>
        </div>
      </div>
      {m.active &&
        (page !== "meetings" || m.library || m.current?.id !== m.active.id) && (
          <div className="fixed bottom-[20px] left-1/2 z-20 flex max-w-[90vw] -translate-x-1/2 items-center gap-[8px] rounded-[12px] border border-solid border-[#e6e6e6] bg-white p-[12px] shadow-lg">
            <Button
              variant="subtle"
              leftSection={<Mic size={16} color="#f53f3f" />}
              onClick={() => {
                navigate("meetings");
                m.open(m.active!.id);
              }}
            >
              {m.active.paused ? "已暂停" : "录制中"} ·{" "}
              {clock(m.active.duration)}
            </Button>
            <IconButton
              label={m.active.paused ? "继续录制" : "暂停录制"}
              onClick={m.pause}
              disabled={m.fault === "device"}
            >
              {m.active.paused ? <Play size={16} /> : <Pause size={16} />}
            </IconButton>
          </div>
        )}
      {notice && (
        <div className="fixed bottom-[24px] left-1/2 z-[400] max-w-[90vw] -translate-x-1/2">
          <Alert
            role="status"
            status="success"
            title={notice}
            withCloseButton
            onClose={() => setNotice("")}
            classNames={{ message: "whitespace-normal" }}
          />
        </div>
      )}
      <DirectoryDialog directory={directory} />
      <MeetingDialogs m={m} notify={notify} />
      <CompanionDialogs c={c} />
      <Modal
        opened={mobileMenu}
        onClose={() => setMobileMenu(false)}
        title="导航"
        size={320}
      >
        {menu(false)}
      </Modal>
      <Modal
        opened={hasAgent && mobileAI}
        onClose={() => setMobileAI(false)}
        title="Ask AI"
        onExitTransitionEnd={() => { if (dailyCitation.current) { daily.cite(dailyCitation.current); dailyCitation.current = null; } }}
        size="100%"
      >
        <div className="flex h-[70dvh] min-h-0 flex-col gap-[16px]">
          {agent}
        </div>
      </Modal>
      <Modal
        opened={guide}
        onClose={() => setGuide(false)}
        title="EurekaLife Mac · 功能说明"
        size={640}
      >
        <div className="flex flex-col gap-[24px]">
          {[
            [
              "01 / 会议",
              "即时录音、录制会议或导入文件；选择音源、语言与画面。录制中可暂停、标记重点、查看逐段原文并向 Ask AI 提问。",
            ],
            [
              "02 / 回顾与行动",
              "结束后生成有引用的总结。行动项先审核负责人和时间，再加入示例待办。异常状态可从演示选择器体验。",
            ],
            [
              "03 / 每日记录 Ask AI",
              "围绕当前日期已备份的资料提问，查看示例回答并沿引用回到原文。各日期分别保留对话与草稿；未备份日期需先完成备份。",
            ],
            [
              "04 / 每日记录与设置",
              "每日记录按日期备份和浏览 EurekaLife App 数据，离线仍能查看历史备份。设置中的主目录统一容纳模型、会议和每日备份，隐私与说明归入设置。会议列表支持确认后删除；录制和整理中的会议不可删除。",
            ],
            [
              "05 / 本地 AI",
              "概览管理服务与配对；模型库区分下载、加载、卸载和删除。ASR 与 LLM 分别管理。",
            ],
            [
              "06 / 三栏工作台",
              "左侧收起后保留菜单图标。左右分隔条支持拖拽和方向键调宽；侧栏关闭保留草稿，顶部按钮可重新打开。",
            ],
            [
              "演示边界",
              "全部为前端交互，没有访问麦克风、屏幕、模型、SQLite 或 Keychain；文件导入只读取文件名。刷新或重置清空示例状态。",
            ],
          ].map(([title, text]) => (
            <section key={title}>
              <h3 className="mb-[8px] text-[15px] font-medium">{title}</h3>
              <p className="m-0 text-[14px] leading-[1.9] text-[#8c8c8c]">
                {text}
              </p>
            </section>
          ))}
        </div>
      </Modal>
      <Modal
        opened={menuPreview}
        onClose={() => setMenuPreview(false)}
        title="EurekaLife 菜单栏"
      >
        <div className="flex flex-col gap-[12px]">
          <Button variant="subtle" onClick={() => setMenuPreview(false)}>
            打开 EurekaLife
          </Button>
          <Button
            variant="subtle"
            onClick={() => c.patch({ service: !c.state.service })}
          >
            {c.state.service ? "暂停" : "开启"}本地 AI 服务
          </Button>
          <Button
            variant="subtle"
            onClick={() => {
              setMenuPreview(false);
              c.pair();
            }}
          >
            配对 iPhone…
          </Button>
          <Button
            variant="subtle"
            disabled={c.state.loaded === null}
            onClick={() => c.patch({ loaded: null })}
          >
            卸载模型
          </Button>
        </div>
      </Modal>
    </>
  );
}
