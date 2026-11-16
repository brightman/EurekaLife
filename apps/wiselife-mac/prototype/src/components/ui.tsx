import { forwardRef, type ReactNode } from "react";
import { createPolymorphicComponent } from "@mantine/core";
import { Tag as StandardTag, type TagProps } from "./standard/Tag/Tag";
import { Button } from "./standard/Button/Button";
import { Tooltip } from "./standard/Tooltip/Tooltip";
export { Button, Tooltip };
export { InputBase as Input } from "./standard/InputBase/InputBase";
export { Select } from "./standard/Select/Select";
export { Switch } from "./standard/Switch/Switch";
export { Radio } from "./standard/Radio/Radio";
export { Checkbox } from "./standard/Checkbox/Checkbox";
export { Tabs } from "./standard/Tabs/Tabs";
export { Table } from "./standard/Table/Table";
// One quiet status treatment across all pages, using the standard public API.
const statusColors = {
  neutral: { bg: "#f2f3f5", c: "#595959" },
  primary: { bg: "#edf3fc", c: "#335f83" },
  success: { bg: "#edf4ef", c: "#38664c" },
  warning: { bg: "#faf3e8", c: "#8a6329" },
  error: { bg: "#fbefee", c: "#a4423d" },
};
const StatusTag = forwardRef<HTMLSpanElement, TagProps>(
  ({ tone = "neutral", ...props }, ref) => (
    <StandardTag
      ref={ref}
      tone={tone}
      data-status-tone={tone}
      variant="light"
      shape="rounded"
      {...statusColors[tone]}
      {...props}
    />
  ),
);
StatusTag.displayName = "EurekaLife/Tag";
export const Tag = createPolymorphicComponent<"span", TagProps>(StatusTag);
export { Modal } from "./standard/Modal/Modal";
export { Alert } from "./standard/Alert/Alert";
export { Loader } from "./standard/Loader/Loader";
export { ThreeColumnLayout } from "./standard/ThreeColumnLayout/ThreeColumnLayout";
export { DateInput } from "./standard/DateInput/DateInput";
export function IconButton({
  label,
  children,
  onClick,
  disabled,
  pressed,
}: {
  label: string;
  children: ReactNode;
  onClick: () => void;
  disabled?: boolean;
  pressed?: boolean;
}) {
  return (
    <Tooltip label={label} position="bottom" openDelay={400}>
      <Button
        variant="subtle"
        w={32}
        h={32}
        px={0}
        aria-label={label}
        aria-pressed={pressed}
        onClick={onClick}
        disabled={disabled}
      >
        {children}
      </Button>
    </Tooltip>
  );
}
export function Panel({ children }: { children: ReactNode }) {
  return (
    <section className="rounded-[12px] border border-solid border-[#f0f0f0] bg-white p-[24px]">
      {children}
    </section>
  );
}
export function Heading({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <header className="mb-[8px] flex flex-wrap items-start justify-between gap-[16px]">
      <div className="min-w-0">
        {eyebrow && (
          <p className="mb-[8px] text-[12px] text-[#8c8c8c]">{eyebrow}</p>
        )}
        <h1 className="m-0 text-[24px] font-semibold leading-[1.4] tracking-[-0.5px] text-[#262626]">
          {title}
        </h1>
        {description && (
          <p className="mb-0 mt-[12px] text-[14px] leading-[1.7] text-[#8c8c8c]">
            {description}
          </p>
        )}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </header>
  );
}
export function Empty({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="px-[16px] py-[48px] text-center">
      <h3 className="text-[16px] font-medium">{title}</h3>
      <p className="text-[14px] leading-[1.8] text-[#8c8c8c]">{description}</p>
    </div>
  );
}
export const clock = (n: number) =>
  [Math.floor(n / 3600), Math.floor(n / 60) % 60, n % 60]
    .map((v) => String(v).padStart(2, "0"))
    .join(":");
export const stamp = (n: number) => clock(n).slice(n >= 3600 ? 0 : 3);
