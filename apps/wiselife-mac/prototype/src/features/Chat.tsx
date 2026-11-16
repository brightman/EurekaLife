import { useEffect, useRef, useState } from "react";
import { ArrowDown, ArrowUp, Sparkles, Square } from "lucide-react";
import { Button, Input, Tag, Empty } from "../components/ui";
import type { Message } from "../types";
export function Chat({
  messages,
  draft,
  setDraft,
  send,
  pending,
  stop,
  ready,
  model,
  scope,
  prompts,
  onCite,
  reset,
  enabled = true,
  disabledMessage = "先选择一场会议，再开始提问。",
}: {
  messages: Message[];
  draft: string;
  setDraft: (v: string) => void;
  send: (q: string) => void;
  pending: boolean;
  stop: () => void;
  ready: boolean;
  model: string;
  scope: string;
  prompts: string[];
  onCite: (c: { id: string; time?: number }) => void;
  reset: () => void;
  enabled?: boolean;
  disabledMessage?: string;
}) {
  const box = useRef<HTMLDivElement>(null),
    follow = useRef(true);
  const [unseen, setUnseen] = useState(false);
  useEffect(() => {
    if (follow.current) {
      box.current?.scrollTo({ top: box.current.scrollHeight });
    } else setUnseen(true);
  }, [messages, pending]);
  return (
    <div
      className="flex min-h-0 flex-1 flex-col gap-[16px]"
      data-testid="chat-panel"
    >
      <div className="border-0 border-b border-solid border-[#f0f0f0] pb-[16px]">
        <div className="flex items-center justify-between gap-[8px]">
          <Tag tone={ready ? "success" : "warning"} size="sm">
            {ready ? "演示就绪" : "模型未加载"}
          </Tag>
          <Button variant="subtle" size="xs" onClick={reset}>
            新对话
          </Button>
        </div>
        <p className="mb-0 mt-[8px] text-[12px] leading-[1.7] text-[#8c8c8c]">
          {model}
          <br />
          {scope}
        </p>
      </div>
      <div
        ref={box}
        data-testid="chat-messages"
        className="min-h-[80px] flex-1 overflow-auto"
        onScroll={() => {
          const e = box.current!;
          follow.current = e.scrollHeight - e.scrollTop - e.clientHeight < 64;
          if (follow.current) setUnseen(false);
        }}
        aria-live="polite"
      >
        {messages.length ? (
          messages.map((m, i) => (
            <article
              key={i}
              className={
                m.role === "user"
                  ? "mb-[20px] rounded-[8px] bg-[#f5f5f5] p-[12px]"
                  : "mb-[24px] py-[4px]"
              }
            >
              <small className="text-[12px] text-[#8c8c8c]">
                {m.role === "user" ? "你" : "EurekaLife · 示例回答"}
              </small>
              <p className="mb-[8px] mt-[8px] whitespace-pre-wrap break-words text-[14px] leading-[1.85]">
                {m.text}
              </p>
              {m.citations?.map((c) => (
                <Button
                  key={c.id + String(c.time)}
                  variant="subtle"
                  size="xs"
                  color="blue"
                  onClick={() => onCite(c)}
                >
                  {c.label} ↗
                </Button>
              ))}
            </article>
          ))
        ) : (
          <div className="py-[40px] text-center">
            <Sparkles size={32} color="#165dff" aria-hidden />
            <h3 className="mb-[12px] mt-[24px] text-[16px] font-medium">
              让记录，带来新的理解。
            </h3>
            <p className="text-[14px] leading-[1.8] text-[#8c8c8c]">
              {enabled
                ? "从一个问题开始，回到原文确认。"
                : disabledMessage}
            </p>
          </div>
        )}
        {pending && (
          <p role="status" className="text-[13px] text-[#8c8c8c]">
            正在整理示例内容…
          </p>
        )}
      </div>
      {unseen && (
        <Button
          variant="light"
          leftSection={<ArrowDown size={14} />}
          onClick={() => {
            follow.current = true;
            setUnseen(false);
            box.current?.scrollTo({ top: box.current.scrollHeight });
          }}
        >
          回到最新
        </Button>
      )}
      <div className="flex flex-col gap-[8px]">
        {prompts.map((q) => (
          <Button
            key={q}
            variant="light"
            fullWidth
            disabled={!ready || !enabled || pending}
            onClick={() => send(q)}
            classNames={{
              inner: "justify-between",
              label: "text-left whitespace-normal",
            }}
            rightSection={<span aria-hidden>↗</span>}
          >
            {q}
          </Button>
        ))}
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          send(draft);
        }}
        className="rounded-[8px] border border-solid border-[#e6e6e6] bg-white p-[12px]"
      >
        <Input
          component="textarea"
          data-autofocus
          aria-label="向 Ask AI 提问"
          placeholder={enabled ? "问问你的记录…" : disabledMessage}
          w="100%"
          size="md"
          value={draft}
          onChange={(e) => setDraft(e.currentTarget.value)}
          maxLength={600}
          disabled={!enabled}
          classNames={{
            input:
              "!h-auto min-h-[80px] resize-none py-[8px] bg-white shadow-none focus:shadow-none",
          }}
        />
        <div className="mt-[8px] flex items-center justify-between gap-[8px]">
          <small className="text-[11px] text-[#8c8c8c]">
            示例回复 · 不调用模型
          </small>
          {pending ? (
            <Button
              size="sm"
              aria-label="停止生成"
              onClick={stop}
              leftSection={<Square size={12} />}
            >
              停止
            </Button>
          ) : (
            <Button
              type="submit"
              size="sm"
              w={32}
              px={0}
              aria-label="发送问题"
              disabled={!ready || !enabled || !draft.trim()}
            >
              <ArrowUp size={16} />
            </Button>
          )}
        </div>
      </form>
      {!ready && (
        <p className="mb-0 text-[12px] text-[#8c8c8c]">
          请先在模型库加载 LLM；录制不受影响。
        </p>
      )}
    </div>
  );
}
