import { forwardRef, useId, useRef, type ReactNode } from "react";
import { ActionIcon, Button, Flex, type FlexProps } from "@mantine/core";
import { PanelLeft, PanelLeftClose, Sparkles, X } from "lucide-react";
import cx from "clsx";
import { useResizablePanel } from "./use-resizable-panel.js";

export interface ThreeColumnLayoutProps
  extends Omit<FlexProps, "children" | "title" | "direction" | "gap" | "wrap"> {
  children?: ReactNode;
  menu?: ReactNode | ((collapsed: boolean) => ReactNode);
  agent?: ReactNode;
  title?: ReactNode;
  menuTitle?: ReactNode;
  agentTitle?: string;
  menuOpened?: boolean;
  defaultMenuOpened?: boolean;
  onMenuOpenedChange?: (opened: boolean) => void;
  agentOpened?: boolean;
  defaultAgentOpened?: boolean;
  onAgentOpenedChange?: (opened: boolean) => void;
  menuCollapsed?: boolean;
  defaultMenuCollapsed?: boolean;
  onMenuCollapsedChange?: (collapsed: boolean) => void;
  menuWidth?: number;
  defaultMenuWidth?: number;
  onMenuWidthChange?: (width: number) => void;
  agentWidth?: number;
  defaultAgentWidth?: number;
  onAgentWidthChange?: (width: number) => void;
  resizable?: boolean;
  /** EurekaLife host option: keep only the close action in the expanded menu. */
  showMenuCollapseButton?: boolean;
  /** Keep desktop navigation available as an icon rail when collapsed. */
  retainMenuRail?: boolean;
  /** EurekaLife host option: omit all assistant UI on unsupported pages. */
  withAgent?: boolean;
}

function ThreeColumnLayoutRoot(
  {
    children,
    menu,
    agent,
    title = "内容区域",
    menuTitle = "工作空间",
    agentTitle = "AskAgent",
    menuOpened,
    defaultMenuOpened = true,
    onMenuOpenedChange,
    agentOpened,
    defaultAgentOpened = true,
    onAgentOpenedChange,
    menuCollapsed,
    defaultMenuCollapsed = false,
    onMenuCollapsedChange,
    menuWidth,
    defaultMenuWidth = 260,
    onMenuWidthChange,
    agentWidth,
    defaultAgentWidth = 300,
    onAgentWidthChange,
    resizable = true,
    showMenuCollapseButton = true,
    retainMenuRail = false,
    withAgent = true,
    h = 640,
    w = "100%",
    bg = "white",
    c = "#262626",
    bdrs = 8,
    bd = "1px solid #e6e6e6",
    classNames,
    ...props
  }: ThreeColumnLayoutProps,
  ref: React.ForwardedRef<HTMLDivElement>,
) {
  const menuState = useResizablePanel({
    side: "left",
    width: menuWidth,
    defaultWidth: defaultMenuWidth,
    onWidthChange: onMenuWidthChange,
    opened: menuOpened,
    defaultOpened: defaultMenuOpened,
    onOpenedChange: onMenuOpenedChange,
    collapsed: menuCollapsed,
    defaultCollapsed: defaultMenuCollapsed,
    onCollapsedChange: onMenuCollapsedChange,
    min: 220,
    max: 400,
  });
  const agentState = useResizablePanel({
    side: "right",
    width: agentWidth,
    defaultWidth: defaultAgentWidth,
    onWidthChange: onAgentWidthChange,
    opened: withAgent ? agentOpened : false,
    defaultOpened: defaultAgentOpened,
    onOpenedChange: onAgentOpenedChange,
    min: 280,
    max: 480,
  });
  const instanceId = useId();
  const menuId = `${instanceId}-menu`;
  const agentId = `${instanceId}-agent`;
  const menuToggleRef = useRef<HTMLButtonElement>(null);
  const menuRailToggleRef = useRef<HTMLButtonElement>(null);
  const agentToggleRef = useRef<HTMLButtonElement>(null);
  const focusMenuToggle = () => {
    if (retainMenuRail) requestAnimationFrame(() => menuRailToggleRef.current?.focus());
    else menuToggleRef.current?.focus();
  };
  const closeMenu = () => {
    if (retainMenuRail) menuState.setCollapsed(true);
    else menuState.setOpened(false);
    focusMenuToggle();
  };
  const closeAgent = () => {
    agentState.setOpened(false);
    agentToggleRef.current?.focus();
  };
  const toggleCollapsed = () => {
    menuState.setCollapsed(!menuState.collapsed);
    focusMenuToggle();
  };
  const toolClasses = {
    root: "shrink-0 text-[#595959] hover:bg-[#ebebeb] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#165dff]",
  };
  return (
    <Flex
      {...props}
      ref={ref}
      h={h}
      w={w}
      bg={bg}
      c={c}
      bdrs={bdrs}
      bd={bd}
      direction="column"
      classNames={(theme, values, context) => ({
        root: cx(
          "min-h-0 min-w-0 overflow-x-auto",
          (typeof classNames === "function"
            ? classNames(theme, values, context)
            : classNames
          )?.root,
        ),
      })}
    >
      <Flex
        h="100%"
        miw={menuState.width + agentState.width + 320}
        wrap="nowrap"
        classNames={{ root: "min-h-0 flex-1" }}
      >
        <Flex
          component="aside"
          id={menuId}
          aria-label="左侧菜单"
          aria-hidden={!menuState.opened}
          display={menuState.opened ? "flex" : "none"}
          w={menuState.width}
          pos="relative"
          direction="column"
          bg="#fafafa"
          classNames={{
            root: "min-h-0 shrink-0 border-0 border-r border-solid border-[#f0f0f0]",
          }}
        >
          <Flex
            h={56}
            px={12}
            gap={4}
            align="center"
            classNames={{ root: "shrink-0" }}
          >
            {!menuState.collapsed && (
              <Flex
                flex={1}
                fz={14}
                fw={600}
                classNames={{ root: "min-w-0 truncate" }}
              >
                {menuTitle}
              </Flex>
            )}
            {(showMenuCollapseButton || menuState.collapsed) && (
              <ActionIcon
                ref={retainMenuRail && menuState.collapsed ? menuRailToggleRef : undefined}
                variant="subtle"
                size={32}
                radius={6}
                aria-label={menuState.collapsed ? "展开菜单" : "折叠菜单"}
                aria-expanded={!menuState.collapsed}
                aria-controls={menuId}
                onClick={toggleCollapsed}
                classNames={toolClasses}
              >
                <PanelLeftClose size={18} aria-hidden />
              </ActionIcon>
            )}
            {!menuState.collapsed && (
              <ActionIcon
                ref={retainMenuRail ? menuRailToggleRef : undefined}
                variant="subtle"
                size={32}
                radius={6}
                aria-label={retainMenuRail ? "折叠菜单" : "关闭菜单"}
                onClick={closeMenu}
                classNames={toolClasses}
              >
                <X size={16} aria-hidden />
              </ActionIcon>
            )}
          </Flex>
          <Flex
            direction="column"
            px={8}
            pb={12}
            classNames={{ root: "min-h-0 flex-1 overflow-auto" }}
          >
            {typeof menu === "function"
              ? menu(menuState.collapsed)
              : (menu ?? "菜单区域")}
          </Flex>
          {resizable && !menuState.collapsed && menuState.opened && (
            <div
              ref={menuState.resizeHandleRef}
              role="separator"
              aria-label="调整菜单宽度"
              aria-controls={menuId}
              aria-orientation="vertical"
              aria-valuemin={220}
              aria-valuemax={400}
              aria-valuenow={menuState.width}
              tabIndex={0}
              onPointerDown={menuState.onPointerDown}
              onPointerMove={menuState.onPointerMove}
              onPointerUp={menuState.onPointerEnd}
              onPointerCancel={menuState.onPointerEnd}
              onLostPointerCapture={menuState.onPointerEnd}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  toggleCollapsed();
                } else menuState.onKeyDown(event);
              }}
              className="absolute inset-y-0 right-0 z-10 w-[6px] touch-none cursor-col-resize hover:bg-[#adc6ff] focus-visible:bg-[#adc6ff] focus-visible:outline-none"
            />
          )}
        </Flex>
        <Flex
          direction="column"
          flex={1}
          miw={320}
          classNames={{ root: "min-h-0 min-w-0" }}
        >
          <Flex
            component="header"
            h={56}
            px={16}
            gap={12}
            align="center"
            classNames={{
              root: "shrink-0 border-0 border-b border-solid border-[#f0f0f0]",
            }}
          >
            {!retainMenuRail && <ActionIcon
              ref={menuToggleRef}
              size={32}
              radius={6}
              variant="subtle"
              aria-label={menuState.opened ? "隐藏菜单" : "显示菜单"}
              aria-expanded={menuState.opened && !menuState.collapsed}
              aria-controls={menuId}
              onClick={() => menuState.setOpened(!menuState.opened)}
              classNames={toolClasses}
            >
              <PanelLeft size={18} aria-hidden />
            </ActionIcon>}
            <Flex
              flex={1}
              fz={14}
              fw={600}
              classNames={{ root: "min-w-0 truncate" }}
            >
              {title}
            </Flex>
            {withAgent && (
              <Button
                ref={agentToggleRef}
                size="compact-sm"
                h={32}
                px={10}
                radius={6}
                variant="light"
                color="#165dff"
                aria-expanded={agentState.opened}
                aria-controls={agentId}
                onClick={() => agentState.setOpened(!agentState.opened)}
                leftSection={<Sparkles size={15} aria-hidden />}
                classNames={{
                  root: "shrink-0 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#165dff]",
                  label: "font-medium",
                }}
              >
                {agentTitle}
              </Button>
            )}
          </Flex>
          <Flex
            direction="column"
            pt={24}
            px={32}
            pb={32}
            gap={16}
            classNames={{ root: "min-h-0 flex-1 overflow-auto" }}
          >
            {children ?? "内容区域"}
          </Flex>
        </Flex>
        {withAgent && (
          <Flex
            component="aside"
            id={agentId}
            aria-label={agentTitle}
            aria-hidden={!agentState.opened}
            display={agentState.opened ? "flex" : "none"}
            w={agentState.width}
            pos="relative"
            direction="column"
            classNames={{
              root: "min-h-0 shrink-0 border-0 border-l border-solid border-[#f0f0f0] bg-white",
            }}
          >
            <Flex
              h={56}
              px={16}
              gap={8}
              align="center"
              classNames={{
                root: "shrink-0 border-0 border-b border-solid border-[#f0f0f0]",
              }}
            >
              <Sparkles size={18} color="#165dff" aria-hidden />
              <Flex
                flex={1}
                fz={14}
                fw={600}
                classNames={{ root: "min-w-0 truncate" }}
              >
                {agentTitle}
              </Flex>
              <ActionIcon
                size={32}
                radius={6}
                variant="subtle"
                aria-label={`关闭 ${agentTitle}`}
                onClick={closeAgent}
                classNames={toolClasses}
              >
                <X size={16} aria-hidden />
              </ActionIcon>
            </Flex>
            <Flex
              direction="column"
              p={16}
              gap={16}
              classNames={{ root: "min-h-0 flex-1 overflow-auto" }}
            >
              {agent ?? "AskAgent 内容区域"}
            </Flex>
            {resizable && agentState.opened && (
              <div
                ref={agentState.resizeHandleRef}
                role="separator"
                aria-label="调整 AskAgent 宽度"
                aria-controls={agentId}
                aria-orientation="vertical"
                aria-valuemin={280}
                aria-valuemax={480}
                aria-valuenow={agentState.width}
                tabIndex={0}
                onPointerDown={agentState.onPointerDown}
                onPointerMove={agentState.onPointerMove}
                onPointerUp={agentState.onPointerEnd}
                onPointerCancel={agentState.onPointerEnd}
                onLostPointerCapture={agentState.onPointerEnd}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    closeAgent();
                  } else agentState.onKeyDown(event);
                }}
                className="absolute inset-y-0 left-0 z-10 w-[6px] touch-none cursor-col-resize hover:bg-[#adc6ff] focus-visible:bg-[#adc6ff] focus-visible:outline-none"
              />
            )}
          </Flex>
        )}
      </Flex>
    </Flex>
  );
}

export const ThreeColumnLayout = forwardRef(ThreeColumnLayoutRoot);
ThreeColumnLayout.displayName = "SWorks/ThreeColumnLayout";
