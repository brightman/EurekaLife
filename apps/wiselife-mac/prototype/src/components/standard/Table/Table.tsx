import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Table as MantineTable,
  type TableProps as MantineTableProps,
} from '@mantine/core';

export interface TableProps extends MantineTableProps {
  /** Primary data table, meeting list, or compact drawer table. */
  appearance?: 'primary' | 'meeting' | 'drawer';
}

export const tableClassNames = {
  table:
    '[font-family:PingFang_SC,sans-serif] tracking-[0px] not-italic border-separate border-spacing-0 text-[#262626]',
  th: 'text-left font-medium',
  td: 'font-normal',
};
export const tableAppearanceClassNames = {
  primary: {
    table:
      'table-fixed overflow-hidden rounded-[16px] bg-white [outline:1px_solid_rgba(0,0,0,0.08)] outline-offset-[-1px]',
    th: 'h-[56px] overflow-hidden border-0 border-b border-r border-solid border-black/[0.08] bg-[#f3f7ff] px-[16px] py-0 text-[14px] leading-[24px] text-[#262626] last:border-r-0',
    td: 'h-[66px] overflow-hidden text-ellipsis whitespace-nowrap border-0 border-r border-solid border-black/[0.08] px-[16px] py-0 text-[14px] leading-[24px] text-[#262626] first:text-center last:border-r-0',
    tr: '[&:nth-child(odd)>td]:bg-white [&:nth-child(even)>td]:bg-[#f2f3f5]',
  },
  meeting: {
    table: 'table-fixed',
    th: 'h-[45px] border-0 border-b border-solid border-[#f0f0f0] px-[5px] py-[12px] text-[13px] leading-[20px] text-[#8c8c8c] first:pl-[16px] last:pr-[16px]',
    td: 'h-[78px] border-0 shadow-[inset_0_-1px_0_#f5f5f5] px-[5px] py-[16px] text-[12px] leading-[18px] text-[#8c8c8c] first:pl-[16px] last:pr-[16px]',
    tr: '[&>td:first-child]:rounded-l-[12px] [&>td:last-child]:rounded-r-[12px] data-[hoverable]:hover:[&>td]:bg-[#f3f7ff] data-[hoverable]:has-[:focus-visible]:[&>td]:bg-[#f3f7ff] data-[hoverable]:data-[menu-open]:[&>td]:bg-[#f3f7ff]',
  },
  drawer: {
    table:
      'table-fixed overflow-hidden rounded-[8px] border border-solid border-[#f0f0f0]',
    th: 'h-[40px] border-0 bg-[rgba(0,0,0,0.03)] px-[12px] py-0 text-[12px] leading-[18px]',
    td: 'h-[42px] border-0 border-b border-solid border-[#f0f0f0] px-[12px] py-0 text-[12px] leading-[18px]',
    tr: 'last:[&>td]:border-b-0',
  },
};
export function resolveTableClassNames(
  appearance: 'primary' | 'meeting' | 'drawer',
  overrides: Partial<Record<'table' | 'th' | 'td' | 'tr', string>> = {},
) {
  const visual = tableAppearanceClassNames[appearance];
  return {
    table: cx(tableClassNames.table, visual.table, overrides.table),
    th: cx(tableClassNames.th, visual.th, overrides.th),
    td: cx(tableClassNames.td, visual.td, overrides.td),
    tr: cx(visual.tr, overrides.tr),
  };
}
const TableRoot = forwardRef<HTMLTableElement, TableProps>(
  ({ appearance = 'meeting', classNames, ...props }, ref) => (
    <MantineTable
      {...props}
      ref={ref}
      classNames={(theme, values, ctx) => {
        const overrides =
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames;
        return {
          ...overrides,
          ...resolveTableClassNames(appearance, overrides),
        };
      }}
    />
  ),
);
TableRoot.displayName = 'SWorks/Table';
export const Table: typeof TableRoot &
  Pick<
    typeof MantineTable,
    | 'Thead'
    | 'Tbody'
    | 'Tfoot'
    | 'Tr'
    | 'Th'
    | 'Td'
    | 'Caption'
    | 'ScrollContainer'
    | 'DataRenderer'
  > = Object.assign(TableRoot, {
  Thead: MantineTable.Thead,
  Tbody: MantineTable.Tbody,
  Tfoot: MantineTable.Tfoot,
  Tr: MantineTable.Tr,
  Th: MantineTable.Th,
  Td: MantineTable.Td,
  Caption: MantineTable.Caption,
  ScrollContainer: MantineTable.ScrollContainer,
  DataRenderer: MantineTable.DataRenderer,
});
