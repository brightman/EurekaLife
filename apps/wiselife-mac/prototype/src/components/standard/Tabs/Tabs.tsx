import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Tabs as MantineTabs,
  type TabsProps as MantineTabsProps,
  type TabsStylesNames,
} from '@mantine/core';

export type TabsVariant = 'default' | 'pills';
export interface TabsProps extends Omit<MantineTabsProps, 'variant'> {
  variant?: TabsVariant;
}

export function resolveTabsClassNames(
  { variant = 'default' }: Pick<TabsProps, 'variant'> = {},
  overrides: Partial<Record<TabsStylesNames, string>> = {},
) {
  return {
    ...overrides,
    root: cx('min-w-0 max-w-full [font-family:PingFang_SC,sans-serif] tracking-[0px]', overrides.root),
    list: cx('max-w-full flex-nowrap overflow-x-auto before:hidden', variant === 'pills' ? 'gap-[12px]' : 'gap-[16px]', overrides.list),
    tab: cx(
      'relative h-[32px] shrink-0 justify-center border-0 py-0 text-[14px] font-normal focus-visible:outline-offset-[-2px]',
      variant === 'pills'
        ? 'rounded-[6px] bg-white px-[12px] leading-[22px] text-[#262626] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08)] hover:bg-[#f2f3f5] data-[active]:bg-[#262626] data-[active]:text-white data-[active]:shadow-none data-[active]:hover:bg-[#262626]'
        : 'min-w-[56px] items-start rounded-none bg-transparent px-[4px] pb-[8px] leading-[24px] text-[#8c8c8c] hover:bg-transparent hover:text-[#262626] data-[active]:font-semibold data-[active]:text-[#262626] after:absolute after:bottom-[1px] after:left-[calc(50%-12px)] after:h-[3px] after:w-[24px] after:rounded-[4px] after:bg-[#262626] after:content-[\'\'] after:opacity-0 data-[active]:after:opacity-100',
      overrides.tab,
    ),
    tabLabel: cx('leading-[inherit]', overrides.tabLabel),
    tabSection: cx('data-[position=left]:me-[8px] data-[position=right]:ms-[8px]', overrides.tabSection),
    panel: cx('min-w-0', overrides.panel),
  };
}

const TabsRoot = forwardRef<HTMLDivElement, TabsProps>(
  ({ variant = 'default', classNames, ...props }, ref) => (
    <MantineTabs
      ref={ref}
      {...props}
      variant={variant}
      classNames={(theme, values, context) => resolveTabsClassNames(
        { variant },
        typeof classNames === 'function' ? classNames(theme, values, context) : classNames,
      )}
    />
  ),
);
TabsRoot.displayName = 'SWorks/Tabs';
export const Tabs = Object.assign(TabsRoot, {
  List: MantineTabs.List,
  Tab: MantineTabs.Tab,
  Panel: MantineTabs.Panel,
});
