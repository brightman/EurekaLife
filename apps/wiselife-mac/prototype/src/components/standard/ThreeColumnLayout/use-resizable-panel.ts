import {
  useCallback,
  useRef,
  type KeyboardEvent,
  type PointerEvent,
} from "react";
import { useUncontrolled } from "@mantine/hooks";

interface PanelOptions {
  side: "left" | "right";
  width?: number;
  defaultWidth: number;
  onWidthChange?: (width: number) => void;
  opened?: boolean;
  defaultOpened: boolean;
  onOpenedChange?: (opened: boolean) => void;
  collapsed?: boolean;
  defaultCollapsed?: boolean;
  onCollapsedChange?: (collapsed: boolean) => void;
  min: number;
  max: number;
}

// Widths are Mantine units; pointer deltas are CSS pixels at the current scale.
export function useResizablePanel(options: PanelOptions) {
  const [opened, setOpened] = useUncontrolled({
    value: options.opened,
    defaultValue: options.defaultOpened,
    finalValue: true,
    onChange: options.onOpenedChange,
  });
  const [collapsed, setCollapsed] = useUncontrolled({
    value: options.collapsed,
    defaultValue: options.defaultCollapsed,
    finalValue: false,
    onChange: options.onCollapsedChange,
  });
  const [expandedWidth, setWidth] = useUncontrolled({
    value: options.width,
    defaultValue: options.defaultWidth,
    finalValue: options.defaultWidth,
    onChange: options.onWidthChange,
  });
  const clamp = (value: number) =>
    Math.min(
      options.max,
      Math.max(
        options.min,
        Math.round(Number.isFinite(value) ? value : options.defaultWidth),
      ),
    );
  const width = opened ? (collapsed ? 56 : clamp(expandedWidth)) : 0;
  const drag = useRef<{
    pointerId: number;
    startX: number;
    width: number;
    unitsPerPixel: number;
  } | null>(null);
  const resizeHandleRef = useCallback((node: HTMLDivElement | null) => {
    if (!node) drag.current = null;
  }, []);
  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (
      !event.isPrimary ||
      event.button !== 0 ||
      !opened ||
      collapsed ||
      drag.current
    )
      return;
    const renderedWidth =
      event.currentTarget.parentElement?.getBoundingClientRect().width ?? width;
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      width,
      unitsPerPixel: renderedWidth > 0 ? width / renderedWidth : 1,
    };
    event.preventDefault();
  };
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const active = drag.current;
    if (!active || active.pointerId !== event.pointerId || !opened || collapsed)
      return;
    const direction = options.side === "left" ? 1 : -1;
    setWidth(
      clamp(
        active.width +
          direction * (event.clientX - active.startX) * active.unitsPerPixel,
      ),
    );
  };
  const onPointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.current?.pointerId !== event.pointerId) return;
    drag.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId))
      event.currentTarget.releasePointerCapture(event.pointerId);
  };
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (
      !opened ||
      collapsed ||
      !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)
    )
      return;
    event.preventDefault();
    const direction = options.side === "left" ? 1 : -1;
    setWidth(
      event.key === "Home"
        ? options.min
        : event.key === "End"
          ? options.max
          : clamp(width + direction * (event.key === "ArrowRight" ? 8 : -8)),
    );
  };
  const changeOpened = (value: boolean) => {
    drag.current = null;
    setOpened(value);
  };
  const changeCollapsed = (value: boolean) => {
    drag.current = null;
    setCollapsed(value);
  };
  return {
    opened,
    collapsed,
    width,
    setOpened: changeOpened,
    setCollapsed: changeCollapsed,
    resizeHandleRef,
    onPointerDown,
    onPointerMove,
    onPointerEnd,
    onKeyDown,
  };
}
