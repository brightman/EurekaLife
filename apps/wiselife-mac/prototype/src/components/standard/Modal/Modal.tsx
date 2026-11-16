import { forwardRef, type ReactNode } from "react";
import {
  Modal as MantineModal,
  ScrollArea,
  type ModalProps as MantineModalProps,
  type ModalStylesNames,
} from "@mantine/core";
import cx from "clsx";
import { ModalCloseIcon, ModalStatusIcon } from "./icons.js";
export interface ModalProps extends MantineModalProps {
  layout?: "compact" | "standard" | "form" | "editor" | "share";
  headerIcon?: ReactNode;
  status?: "error" | "success" | "warning" | "edit";
  footer?: ReactNode;
  bodyHeight?: number;
}
export function resolveModalClassNames(
  { layout = "standard" }: Pick<ModalProps, "layout"> = {},
  overrides: Partial<Record<ModalStylesNames, string>> = {},
) {
  return {
    ...overrides,
    content: cx(
      "bg-white text-[#262626] [font-family:PingFang_SC,sans-serif] tracking-[0px] shadow-[0_8px_16px_rgba(0,0,0,0.1)]",
      layout === "share" ? "p-[16px]" : layout !== "form" && "p-[24px]",
      overrides.content,
    ),
    header: cx(
      "min-h-0 bg-white",
      layout === "form"
        ? "h-[64px] px-[16px] py-[12px] shadow-[inset_0_-1px_0_rgba(0,0,0,0.05)]"
        : undefined,
      overrides.header,
    ),
    title: cx(
      "min-w-0 flex-1 text-[16px] font-medium text-black",
      layout === "form" ? "leading-[24px]" : "leading-[28px]",
      overrides.title,
    ),
    close: cx(
      "m-0 shrink-0 rounded-[6px] text-[#262626]",
      layout === "form" ? "h-[32px] w-[32px]" : "h-[24px] w-[24px]",
      overrides.close,
    ),
    body: cx("text-[14px] font-normal leading-[24px]", overrides.body),
  };
}
const ModalComponent = forwardRef<HTMLDivElement, ModalProps>(
  (
    {
      layout = "standard",
      headerIcon,
      status,
      footer,
      bodyHeight,
      title,
      children,
      classNames,
      closeButtonProps,
      ...props
    },
    ref,
  ) => (
    <MantineModal
      ref={ref}
      centered
      size={layout === "compact" ? 320 : layout === "form" ? 640 : 400}
      radius={16}
      padding={0}
      withCloseButton={layout !== "compact"}
      {...props}
      title={
        title && (
          <span className="flex min-w-0 items-center gap-[8px]">
            {headerIcon ??
              (status && (
                <ModalStatusIcon
                  status={status}
                  className={
                    status === "edit"
                      ? "mx-[4px] h-[16px] w-[16px] shrink-0"
                      : "h-[24px] w-[24px] shrink-0"
                  }
                />
              ))}
            <span
              className={layout === "compact" ? "min-w-0" : "min-w-0 truncate"}
            >
              {title}
            </span>
          </span>
        )
      }
      closeButtonProps={{
        "aria-label": "关闭弹窗",
        icon: <ModalCloseIcon className="h-[16px] w-[16px]" />,
        ...closeButtonProps,
      }}
      classNames={resolveModalClassNames({ layout }, classNames)}
    >
      <ScrollArea h={bodyHeight} type="auto">
        <div
          className={
            layout === "form"
              ? "max-h-[464px] overflow-y-auto px-[24px] py-[16px]"
              : layout === "share"
                ? "pt-[8px]"
                : layout === "editor"
                  ? "pt-[12px]"
                  : title
                    ? "py-[12px]"
                    : ""
          }
        >
          {children}
        </div>
      </ScrollArea>
      {footer && (
        <div
          className={
            layout === "form"
              ? "flex min-h-[72px] items-center justify-between gap-[12px] px-[24px] pb-[24px] pt-[16px]"
              : title
                ? "mt-[8px]"
                : "mt-[24px]"
          }
        >
          {footer}
        </div>
      )}
    </MantineModal>
  ),
);
ModalComponent.displayName = "SWorks/Modal";
export const Modal: typeof ModalComponent &
  Pick<
    typeof MantineModal,
    | "Root"
    | "Overlay"
    | "Content"
    | "Header"
    | "Title"
    | "Body"
    | "CloseButton"
    | "Stack"
  > = Object.assign(ModalComponent, {
  Root: MantineModal.Root,
  Overlay: MantineModal.Overlay,
  Content: MantineModal.Content,
  Header: MantineModal.Header,
  Title: MantineModal.Title,
  Body: MantineModal.Body,
  CloseButton: MantineModal.CloseButton,
  Stack: MantineModal.Stack,
});
