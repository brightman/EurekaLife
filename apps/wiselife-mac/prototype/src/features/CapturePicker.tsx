import { useState } from "react";
import { AppWindow, Check, Monitor } from "lucide-react";
import { Button, Modal, Tabs } from "../components/ui";

export const captureSources = [
  {
    id: "display",
    kind: "screen",
    title: "整个屏幕 · 内置显示屏",
    scene: "desktop",
  },
  {
    id: "external",
    kind: "screen",
    title: "整个屏幕 · 外接显示器",
    scene: "slides",
  },
  {
    id: "eurekalife",
    kind: "window",
    title: "EurekaLife · 会议",
    scene: "workspace",
  },
  {
    id: "meeting",
    kind: "window",
    title: "会议应用 · 示例窗口",
    scene: "meeting",
  },
  {
    id: "slides",
    kind: "window",
    title: "产品设计 · 示例窗口",
    scene: "slides",
  },
  {
    id: "document",
    kind: "window",
    title: "项目计划 · 文档",
    scene: "document",
  },
  { id: "notes", kind: "window", title: "研究笔记 · 笔记", scene: "notes" },
  {
    id: "browser",
    kind: "window",
    title: "产品资料 · 浏览器",
    scene: "browser",
  },
] as const;

// Synthetic illustrations, never screenshots or live previews of the user's windows.
function SourcePreview({ scene }: { scene: string }) {
  return (
    <svg
      viewBox="0 0 320 190"
      aria-hidden="true"
      className="block aspect-[32/19] w-full bg-[#f4f5f7]"
    >
      <rect
        width="320"
        height="190"
        fill={scene === "desktop" ? "#dce7ee" : "#f5f6f8"}
      />
      {scene === "desktop" && (
        <>
          <circle cx="290" cy="150" r="120" fill="#b7ced7" />
          <rect x="34" y="22" width="252" height="143" rx="7" fill="white" />
          <rect
            x="91"
            y="174"
            width="138"
            height="10"
            rx="5"
            fill="#ffffffbb"
          />
        </>
      )}
      <rect
        x="12"
        y="12"
        width="296"
        height="166"
        rx="6"
        fill="white"
        stroke="#e6e8eb"
      />
      <path d="M18 12H302Q308 12 308 18V30H12V18Q12 12 18 12" fill="#eef0f3" />
      {[22, 32, 42].map((x, i) => (
        <circle
          key={x}
          cx={x}
          cy="21"
          r="2.5"
          fill={["#e1a4a0", "#dfc28d", "#9cbea6"][i]}
        />
      ))}
      <rect x="116" y="18" width="88" height="5" rx="2.5" fill="#d7dce1" />
      {scene === "meeting" ? (
        <>
          {[0, 1, 2, 3].map((i) => (
            <g
              key={i}
              transform={`translate(${23 + (i % 2) * 142} ${40 + Math.floor(i / 2) * 60})`}
            >
              <rect
                width="132"
                height="51"
                rx="4"
                fill={["#e6ecf1", "#e8eae3", "#efe7e2", "#e8e4ed"][i]}
              />
              <circle cx="66" cy="20" r="9" fill="#a7b0bc" />
              <path d="M49 43Q49 29 66 29Q83 29 83 43" fill="#a7b0bc" />
            </g>
          ))}
          <rect x="116" y="164" width="88" height="6" rx="3" fill="#d8dee5" />
        </>
      ) : scene === "slides" ? (
        <>
          <rect x="13" y="31" width="45" height="146" fill="#f2f3f5" />
          {[43, 80, 117].map((y) => (
            <rect
              key={y}
              x="20"
              y={y}
              width="31"
              height="24"
              rx="2"
              fill="white"
              stroke="#dde2e8"
            />
          ))}
          <rect x="76" y="48" width="215" height="110" rx="3" fill="#eff4f7" />
          <text
            x="91"
            y="78"
            fill="#426078"
            fontFamily="sans-serif"
            fontSize="12"
            fontWeight="600"
          >
            PRODUCT REVIEW
          </text>
          <rect x="92" y="90" width="92" height="5" rx="2" fill="#bacad5" />
          {[32, 47, 62, 78].map((h, i) => (
            <rect
              key={h}
              x={209 + i * 17}
              y={142 - h}
              width="11"
              height={h}
              rx="2"
              fill={["#cfdae3", "#b5c8d6", "#8faabe", "#64879f"][i]}
            />
          ))}
        </>
      ) : (
        <>
          <rect x="13" y="31" width="56" height="146" fill="#f4f5f7" />
          {[45, 61, 77, 93, 109].map((y) => (
            <rect
              key={y}
              x="23"
              y={y}
              width="34"
              height="5"
              rx="2"
              fill="#dce1e7"
            />
          ))}
          <rect x="83" y="44" width="104" height="8" rx="3" fill="#8093a3" />
          <rect x="83" y="59" width="146" height="4" rx="2" fill="#dce2e8" />
          {scene === "workspace" ||
          scene === "desktop" ||
          scene === "browser" ? (
            <>
              {[83, 155, 227].map((x) => (
                <g key={x}>
                  <rect
                    x={x}
                    y="78"
                    width="63"
                    height="40"
                    rx="4"
                    fill="#f7f9fb"
                    stroke="#e3e8ed"
                  />
                  <rect
                    x={x + 10}
                    y="88"
                    width="12"
                    height="10"
                    rx="2"
                    fill="#c5d3df"
                  />
                  <rect
                    x={x + 10}
                    y="104"
                    width="40"
                    height="3"
                    rx="1.5"
                    fill="#dce2e8"
                  />
                </g>
              ))}
              {[134, 150, 166].map((y) => (
                <rect
                  key={y}
                  x="84"
                  y={y}
                  width="204"
                  height="4"
                  rx="2"
                  fill="#e7ebef"
                />
              ))}
            </>
          ) : (
            [79, 94, 109, 124, 139, 154].map((y, i) => (
              <g key={y}>
                {scene === "notes" && (
                  <rect
                    x="84"
                    y={y}
                    width="5"
                    height="5"
                    rx="1"
                    fill="#c5d3df"
                  />
                )}
                <rect
                  x={scene === "notes" ? 95 : 83}
                  y={y}
                  width={i % 3 === 2 ? 128 : 196}
                  height="4"
                  rx="2"
                  fill="#e1e6eb"
                />
              </g>
            ))
          )}
        </>
      )}
    </svg>
  );
}

export function CapturePicker({
  selectedTitle,
  onCancel,
  onConfirm,
}: {
  selectedTitle: string;
  onCancel: () => void;
  onConfirm: (title: string) => void;
}) {
  const initial = captureSources.find(
    (source) => source.title === selectedTitle,
  );
  const [tab, setTab] = useState<string | null>(initial?.kind || "window");
  const [selected, setSelected] = useState<string | null>(initial?.id || null);
  const choice = captureSources.find(
    (source) => source.id === selected && source.kind === tab,
  );
  return (
    <Modal
      opened
      onClose={onCancel}
      title="选择录制画面"
      size={1000}
      footer={
        <div className="flex flex-wrap items-center justify-between gap-[16px] border-0 border-t border-solid border-[#f0f0f0] pt-[20px]">
          <p className="m-0 max-w-[500px] text-[12px] leading-[1.7] text-[#8c8c8c]">
            {tab === "screen"
              ? "整个屏幕会包含其他窗口与通知，请留意私人内容。"
              : "只录制所选窗口的画面。系统声音沿用上一步的设置。"}
          </p>
          <div className="ml-auto flex gap-[12px]">
            <Button variant="outline" onClick={onCancel}>
              返回设置
            </Button>
            <Button
              disabled={!choice}
              onClick={() => choice && onConfirm(choice.title)}
            >
              开始录制
            </Button>
          </div>
        </div>
      }
    >
      <p className="mb-[20px] text-[13px] leading-[1.7] text-[#8c8c8c]">
        第 2 步 / 选择画面 · 确认后开始录制
      </p>
      <Tabs
        value={tab}
        onChange={(value) => {
          setTab(value);
          setSelected(null);
        }}
      >
        <Tabs.List aria-label="录制画面范围">
          <Tabs.Tab value="screen" leftSection={<Monitor size={16} />}>
            Entire Screen
          </Tabs.Tab>
          <Tabs.Tab value="window" leftSection={<AppWindow size={16} />}>
            Application Window
          </Tabs.Tab>
        </Tabs.List>
        <div
          className="max-h-[48dvh] overflow-y-auto px-[4px] py-[24px]"
          role="group"
          aria-label={tab === "screen" ? "选择整个屏幕" : "选择应用窗口"}
        >
          <div className="grid grid-cols-1 gap-[16px] min-[540px]:grid-cols-2 min-[900px]:grid-cols-3">
            {captureSources
              .filter((source) => source.kind === tab)
              .map((source) => (
                <Button
                  key={source.id}
                  variant="outline"
                  fullWidth
                  h="auto"
                  p={0}
                  radius={10}
                  aria-label={source.title}
                  aria-pressed={selected === source.id}
                  onClick={() => setSelected(source.id)}
                  classNames={{
                    root:
                      selected === source.id
                        ? "!ring-2 !ring-[#165dff] !bg-[#f3f7ff]"
                        : "!ring-[#e6e6e6] hover:!ring-[#bfbfbf]",
                    inner: "block w-full",
                    label: "block w-full whitespace-normal text-left",
                  }}
                >
                  <SourcePreview scene={source.scene} />
                  <span className="flex items-center gap-[8px] px-[12px] py-[14px]">
                    {source.kind === "screen" ? (
                      <Monitor size={17} className="shrink-0 text-[#595959]" />
                    ) : (
                      <AppWindow
                        size={17}
                        className="shrink-0 text-[#595959]"
                      />
                    )}
                    <span className="min-w-0 flex-1 truncate text-[13px]">
                      {source.title}
                    </span>
                    <span
                      className={
                        selected === source.id
                          ? "flex size-[18px] shrink-0 items-center justify-center rounded-full bg-[#165dff] text-white"
                          : "size-[18px] shrink-0"
                      }
                    >
                      {selected === source.id && <Check size={12} />}
                    </span>
                  </span>
                </Button>
              ))}
          </div>
        </div>
      </Tabs>
      <p className="mb-0 text-[12px] text-[#8c8c8c]">
        以上是示例画面，不会读取或录制这台 Mac 的实际窗口。
      </p>
    </Modal>
  );
}
