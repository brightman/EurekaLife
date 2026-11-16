import { useEffect, useRef, useState } from "react";
import {
  Cpu,
  HardDrive,
  Mic,
  Monitor,
  QrCode,
  ShieldCheck,
  Smartphone,
  Wifi,
} from "lucide-react";
import { Progress } from "@mantine/core";
import {
  Alert,
  Button,
  Empty,
  Heading,
  Modal,
  Panel,
  Select,
  Switch,
  Tabs,
  Tag,
} from "../components/ui";
import demo from "../demo.json";
const fresh = () => ({
  installed: [0],
  loaded: 0 as number | null,
  service: true,
  network: true,
  pressure: false,
  keychain: false,
  devices: ["我的 iPhone 16 Pro"],
  error: "",
  asrInstalled: false,
  asrLoaded: false,
  active: false,
  asrResult: false,
  metric: false,
});
export function useCompanion(notify: (s: string) => void) {
  const [state, setState] = useState(fresh),
    [category, setCategory] = useState<string | null>("llm"),
    [operation, setOperation] = useState<{
      id: number;
      asr: boolean;
      phase: string;
      progress: number;
    } | null>(null),
    [dialog, setDialog] = useState(""),
    [deleteId, setDeleteId] = useState(0),
    [expires, setExpires] = useState(120);
  const timer = useRef<ReturnType<typeof setInterval> | undefined>(undefined),
    requestTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const patch = (values: Partial<typeof state>) =>
    setState((s) => ({ ...s, ...values }));
  function cancel() {
    clearInterval(timer.current);
    setOperation(null);
  }
  useEffect(() => {
    if (dialog !== "pair") return;
    const id = setInterval(() => setExpires((n) => Math.max(0, n - 1)), 1000);
    return () => clearInterval(id);
  }, [dialog]);
  useEffect(
    () => () => {
      clearInterval(timer.current);
      clearTimeout(requestTimer.current);
    },
    [],
  );
  function run(id: number, asr = false, load = false) {
    if (operation) return;
    let n = 0;
    setOperation({
      id,
      asr,
      phase: load ? "正在校验并加载" : "正在下载模型",
      progress: 0,
    });
    timer.current = setInterval(() => {
      n += 10;
      if (n >= 100) {
        clearInterval(timer.current);
        setOperation(null);
        if (asr) patch(load ? { asrLoaded: true } : { asrInstalled: true });
        else
          setState((s) =>
            load
              ? { ...s, loaded: id }
              : { ...s, installed: Array.from(new Set([...s.installed, id])) },
          );
        notify(load ? "模型已就绪 · 演示" : "下载并校验完成 · 未下载真实权重");
      } else
        setOperation({
          id,
          asr,
          phase: load
            ? "正在校验并加载"
            : n >= 80
              ? "正在校验文件"
              : "正在下载模型",
          progress: n,
        });
    }, 250);
  }
  function request(asr = false) {
    if (state.active) {
      clearTimeout(requestTimer.current);
      patch({ active: false });
      return;
    }
    patch({ active: true });
    requestTimer.current = setTimeout(() => {
      patch({ active: false, metric: true, asrResult: asr });
      notify(asr ? "示例转写已返回 iPhone" : "示例请求已完成");
    }, 1200);
  }
  function pair() {
    setExpires(120);
    setDialog("pair");
  }
  function scenario(v: string) {
    cancel();
    clearTimeout(requestTimer.current);
    setDialog("");
    const s = fresh();
    if (["first", "download", "error"].includes(v)) {
      s.installed = [];
      s.loaded = null;
      s.service = false;
      s.devices = [];
    }
    if (v === "error") s.error = "下载失败：示例网络连接中断。可重新下载。";
    if (v === "network") s.network = false;
    if (v === "pressure") s.pressure = true;
    if (v === "keychain") {
      s.keychain = true;
      s.devices = [];
    }
    setState(s);
    if (v === "download") setTimeout(() => run(0), 0);
  }
  return {
    state,
    patch,
    category,
    setCategory,
    operation,
    run,
    cancel,
    request,
    pair,
    dialog,
    setDialog,
    deleteId,
    setDeleteId,
    expires,
    setExpires,
    scenario,
  };
}
export type Companion = ReturnType<typeof useCompanion>;
export function CompanionPage({
  c,
  page,
  navigate,
}: {
  c: Companion;
  page: string;
  navigate: (p: string) => void;
}) {
  const s = c.state,
    op = c.operation,
    model = s.loaded === null ? "尚未加载模型" : demo.models[s.loaded].name;
  if (page === "models")
    return (
      <>
        <Heading
          title="为这台 Mac，选择合适的模型。"
          description="下载文件与加载到内存，是两个独立步骤。"
        />
        <Panel>
          <div className="flex items-center gap-[16px]">
            <Cpu size={24} />
            <div>
              <h3 className="mb-[8px] text-[16px] font-medium">
                Apple M3 · 16 GB 统一内存
              </h3>
              <p className="m-0 text-[13px] text-[#8c8c8c]">
                示例配置 · 为你推荐 Qwen3-4B，兼顾中文能力与内存。
              </p>
            </div>
          </div>
        </Panel>
        <Tabs variant="pills" value={c.category} onChange={c.setCategory}>
          <Tabs.List>
            <Tabs.Tab value="llm">LLM 语言模型</Tabs.Tab>
            <Tabs.Tab value="asr">ASR 语音转写</Tabs.Tab>
          </Tabs.List>
        </Tabs>
        {s.error && (
          <Alert
            status="error"
            title="下载未完成"
            classNames={{ message: "whitespace-normal" }}
          >
            {s.error}
            <Button variant="subtle" onClick={() => c.patch({ error: "" })}>
              关闭提示
            </Button>
          </Alert>
        )}
        {(c.category === "llm"
          ? demo.models
          : [
              {
                name: "Whisper Small",
                ram: 0,
                bytes: 0,
                license: "候选模型 · 待工程验证",
                source: "https://github.com/openai/whisper",
                revision: "版本与文件体积待验证",
              },
            ]
        ).map((m, id) => {
          const asr = c.category === "asr",
            installed = asr ? s.asrInstalled : s.installed.includes(id),
            loaded = asr ? s.asrLoaded : s.loaded === id,
            busy = op?.id === id && op.asr === asr;
          return (
            <Panel key={m.name}>
              <div className="flex items-start justify-between gap-[16px]">
                <div>
                  <h2 className="mb-[8px] text-[20px] font-medium">{m.name}</h2>
                  <p className="text-[14px] text-[#8c8c8c]">
                    {asr
                      ? "语音转文字 · 接口为产品设计"
                      : "本地中文总结、标题与问答"}
                  </p>
                </div>
                <Tag tone={loaded ? "success" : "neutral"}>
                  {loaded ? "已加载" : installed ? "已下载" : "未下载"}
                </Tag>
              </div>
              <div className="mb-[24px] flex flex-wrap gap-[16px] text-[12px] text-[#8c8c8c]">
                {m.bytes > 0 && (
                  <span>
                    {(m.bytes / 1e9).toFixed(2)} GB · 建议 {m.ram} GB+
                  </span>
                )}
                <span>{m.license}</span>
              </div>
              {busy ? (
                <div className="flex flex-col gap-[12px]">
                  <div className="flex justify-between">
                    <span className="text-[13px]">
                      {op.phase} · {op.progress}%
                    </span>
                    <Button variant="subtle" size="xs" onClick={c.cancel}>
                      取消
                    </Button>
                  </div>
                  <Progress value={op.progress} color="#165dff" size={4} />
                </div>
              ) : (
                <div className="flex flex-wrap items-center gap-[12px]">
                  <Button
                    disabled={!!op || s.active}
                    onClick={() => {
                      if (loaded)
                        c.patch(asr ? { asrLoaded: false } : { loaded: null });
                      else c.run(id, asr, installed);
                    }}
                  >
                    {loaded ? "卸载模型" : installed ? "加载模型" : "下载模型"}
                  </Button>
                  {installed && (
                    <Button
                      variant="subtle"
                      disabled={!!op || s.active}
                      onClick={() => {
                        c.setDeleteId(id);
                        c.setDialog(asr ? "delete-asr" : "delete");
                      }}
                    >
                      删除
                    </Button>
                  )}
                  <a
                    className="ml-auto text-[12px] text-[#165dff]"
                    href={m.source}
                    target="_blank"
                    rel="noreferrer"
                  >
                    查看模型来源 ↗
                  </a>
                </div>
              )}
              <details className="mt-[16px] text-[12px] leading-[1.8] text-[#8c8c8c]">
                <summary className="cursor-pointer">版本与来源</summary>
                <p className="mt-[8px] break-all">{m.revision}</p>
              </details>
              {asr && (
                <div className="mt-[20px] border-0 border-t border-solid border-[#f0f0f0] pt-[16px]">
                  <Button
                    variant="light"
                    disabled={
                      !s.asrLoaded ||
                      !s.service ||
                      !s.network ||
                      !s.devices.length
                    }
                    onClick={() => c.request(true)}
                  >
                    {s.active ? "取消请求" : "模拟 iPhone 转写请求"}
                  </Button>
                  {s.asrResult && (
                    <p className="mt-[12px] text-[13px]">
                      示例转写已返回；此页面没有处理真实音频。
                    </p>
                  )}
                </div>
              )}
            </Panel>
          );
        })}
      </>
    );
  if (page === "privacy")
    return (
      <>
        <Heading
          title="数据边界，看得见，也由你掌握。"
          description="连接、模型与资料使用，分别由你控制。"
        />
        {[
          [
            "本地 AI 服务",
            "只有已配对设备能请求已加载模型；配对不等于在线。服务关闭后停止接收新请求。",
          ],
          [
            "文件与模型",
            "卸载释放内存，保留文件；删除模型文件需要确认。原型不会下载真实权重。",
          ],
          [
            "会议与每日记录",
            "录音、转写、说话人、同步与 AI 回复都是固定示例。上传只读取文件名，不读取或发送文件内容。",
          ],
          [
            "存储与重置",
            "原型数据只在当前页面内存。刷新或重置会清空，不访问 SQLite、Keychain、录音或系统提醒。",
          ],
        ].map(([title, text]) => (
          <Panel key={title}>
            <div className="flex gap-[16px]">
              <ShieldCheck size={22} color="#595959" />
              <div>
                <h3 className="mb-[12px] text-[16px] font-medium">{title}</h3>
                <p className="m-0 text-[14px] leading-[1.9] text-[#8c8c8c]">
                  {text}
                </p>
              </div>
            </div>
          </Panel>
        ))}
      </>
    );
  return (
    <>
      <Heading
        title="在你的 Mac 上，运行本地 AI。"
        description="为 iPhone 提供本地转写与语言模型服务。"
      />
      {!s.network && (
        <Alert
          status="warning"
          title="网络不可达"
          classNames={{ message: "whitespace-normal" }}
        >
          请检查局域网连接。
          <Button variant="subtle" onClick={() => c.patch({ network: true })}>
            重试
          </Button>
        </Alert>
      )}
      <Panel>
        <div className="flex items-center justify-between gap-[16px]">
          <div className="flex items-center gap-[16px]">
            <Monitor size={28} />
            <div>
              <p className="mb-[4px] text-[12px] text-[#8c8c8c]">
                这台 Mac · 示例配置
              </p>
              <h2 className="m-0 text-[20px] font-medium">
                MacBook Air · Apple M3
              </h2>
            </div>
          </div>
          <Tag
            tone={
              s.pressure
                ? "warning"
                : s.service && s.loaded !== null
                  ? "success"
                  : "neutral"
            }
          >
            {s.pressure
              ? "内存压力偏高"
              : !s.network
                ? "网络不可达"
                : s.active
                  ? "正在推理"
                  : s.service && s.loaded !== null
                    ? "模型已就绪"
                    : "服务未就绪"}
          </Tag>
        </div>
        <div className="my-[24px] grid grid-cols-3 gap-[16px]">
          {[
            ["统一内存", "16 GB"],
            ["硬盘容量", "512 GB"],
            ["可用空间", "128 GB"],
          ].map(([name, value]) => (
            <div key={name}>
              <p className="mb-[8px] text-[12px] text-[#8c8c8c]">{name}</p>
              <strong className="text-[24px] font-medium">{value}</strong>
            </div>
          ))}
        </div>
        <div className="grid grid-cols-3 gap-[16px] border-0 border-t border-solid border-[#f0f0f0] pt-[20px]">
          {[
            ["推理队列", s.active ? "处理中" : "空闲"],
            ["首次响应", s.metric ? "0.82 s" : "—"],
            ["峰值内存", s.loaded === null ? "—" : "3.6 GB"],
          ].map(([name, value]) => (
            <div key={name}>
              <p className="mb-[8px] text-[12px] text-[#8c8c8c]">{name}</p>
              <strong className="text-[18px] font-medium">{value}</strong>
            </div>
          ))}
        </div>
        <p className="mb-0 mt-[16px] text-[11px] text-[#8c8c8c]">
          配置与性能均为示例值，非实测。
        </p>
      </Panel>
      <div className="grid grid-cols-1 gap-[16px] min-[1100px]:grid-cols-2">
        <Panel>
          <Cpu size={22} />
          <h3 className="mb-[12px] mt-[16px] text-[16px] font-medium">
            {model}
          </h3>
          <p className="text-[13px] text-[#8c8c8c]">
            适合中文总结、标题与问答。
          </p>
          <div className="flex flex-wrap gap-[12px]">
            <Button onClick={() => navigate("models")}>管理模型</Button>
            <Button
              variant="light"
              disabled={
                !s.service ||
                !s.network ||
                s.loaded === null ||
                !s.devices.length
              }
              onClick={() => c.request()}
            >
              {s.active ? "取消生成" : "模拟请求"}
            </Button>
          </div>
        </Panel>
        <Panel>
          <Wifi size={22} />
          <h3 className="mb-[12px] mt-[16px] text-[16px] font-medium">
            为配对的 iPhone 提供本地 AI
          </h3>
          <p className="text-[13px] text-[#8c8c8c]">
            服务开启后，附近设备可发现这台 Mac。
          </p>
          <Switch
            label="开启本地 AI 服务"
            checked={s.service}
            onChange={(e) => {
              c.patch({ service: e.currentTarget.checked });
              if (!e.currentTarget.checked && s.active) c.request();
            }}
          />
        </Panel>
      </div>
      <Panel>
        <div className="flex items-center justify-between">
          <h2 className="m-0 text-[18px] font-medium">已配对设备</h2>
          <Button
            leftSection={<QrCode size={16} />}
            onClick={c.pair}
            disabled={!s.network}
          >
            配对 iPhone
          </Button>
        </div>
        {s.keychain ? (
          <div className="mt-[20px]">
            <p className="text-[14px]">需要钥匙串授权读取配对信息 · 演示</p>
            <Button onClick={() => c.patch({ keychain: false })}>
              模拟授权
            </Button>
          </div>
        ) : s.devices.length ? (
          s.devices.map((name, id) => (
            <div key={id} className="mt-[20px] flex items-center gap-[12px]">
              <Smartphone size={20} />
              <div className="flex-1">
                <strong className="text-[14px] font-medium">{name}</strong>
                <p className="m-0 text-[12px] text-[#8c8c8c]">
                  已配对 · 在线状态未知
                </p>
              </div>
              <Button
                variant="subtle"
                onClick={() => {
                  c.setDeleteId(id);
                  c.setDialog("revoke");
                }}
              >
                撤销
              </Button>
            </div>
          ))
        ) : (
          <Empty
            title="从一次扫码开始"
            description="同一局域网内，扫码建立安全连接。"
          />
        )}
      </Panel>
    </>
  );
}
export function CompanionDialogs({ c }: { c: Companion }) {
  const s = c.state;
  return (
    <Modal
      opened={!!c.dialog}
      onClose={() => c.setDialog("")}
      title={
        c.dialog === "pair"
          ? "配对 iPhone"
          : c.dialog === "revoke"
            ? "撤销设备配对？"
            : "删除模型文件？"
      }
      footer={
        c.dialog === "pair" ? (
          <div className="flex flex-wrap justify-end gap-[12px]">
            <Button variant="outline" onClick={() => c.setExpires(120)}>
              重新生成
            </Button>
            <Button
              disabled={!c.expires}
              onClick={() => {
                c.patch({
                  devices: [
                    ...s.devices,
                    s.devices.length ? "另一台 iPhone" : "我的 iPhone",
                  ],
                });
                c.setDialog("");
              }}
            >
              模拟扫码成功
            </Button>
          </div>
        ) : (
          <div className="flex justify-end gap-[12px]">
            <Button
              variant="outline"
              onClick={() => c.setDialog("")}
              data-autofocus
            >
              取消
            </Button>
            <Button
              color="red"
              onClick={() => {
                if (c.dialog === "revoke")
                  c.patch({
                    devices: s.devices.filter((_, id) => id !== c.deleteId),
                  });
                else if (c.dialog === "delete-asr")
                  c.patch({ asrInstalled: false, asrLoaded: false });
                else
                  c.patch({
                    installed: s.installed.filter((id) => id !== c.deleteId),
                    loaded: s.loaded === c.deleteId ? null : s.loaded,
                  });
                c.setDialog("");
              }}
            >
              确认{c.dialog === "revoke" ? "撤销" : "删除"}
            </Button>
          </div>
        )
      }
    >
      {c.dialog === "pair" ? (
        <div className="text-center">
          <p className="text-[14px] leading-[1.8] text-[#8c8c8c]">
            在 iPhone 设置中打开「附近的 Mac」。
          </p>
          <div className="my-[24px] rounded-[12px] border border-dashed border-[#bfbfbf] py-[32px]">
            <QrCode size={64} color="#8c8c8c" />
            <p className="mb-0 mt-[12px] text-[12px] text-[#8c8c8c]">
              配对码示意 · 不可扫码
            </p>
          </div>
          <p className="text-[14px]">
            {c.expires ? `${c.expires} 秒后失效` : "配对码已失效"}
          </p>
          <Button variant="subtle" size="xs" onClick={() => c.setExpires(0)}>
            模拟失效
          </Button>
        </div>
      ) : (
        <p className="text-[14px] leading-[1.9] text-[#595959]">
          {c.dialog === "revoke"
            ? "撤销后需要重新配对；原型不会修改真实设备。"
            : "删除后需重新下载；本操作只修改演示状态。"}
        </p>
      )}
    </Modal>
  );
}
