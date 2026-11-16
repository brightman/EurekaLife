import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Tooltip as MantineTooltip,
  type TooltipProps as MantineTooltipProps,
} from '@mantine/core';

export interface TooltipProps extends MantineTooltipProps {}

export const tooltipClassNames = {
  tooltip: 'shadow-none',
};

export function resolveTooltipProps({
  radius = 8,
  color = 'rgba(0,0,0,0.9)',
  events = { hover: true, focus: true, touch: false },
  ...props
}: TooltipProps): TooltipProps {
  return {
    p: 8,
    ff: 'PingFang SC, sans-serif',
    fz: 12,
    fw: 400,
    lh: 1.5,
    lts: 0,
    fs: 'normal' as const,
    bd: 0,
    ...props,
    radius,
    color,
    events,
  };
}
export function resolveTooltipClassNames(
  overrides: Partial<
    Record<import('@mantine/core').TooltipStylesNames, string>
  > = {},
) {
  return {
    tooltip: cx(tooltipClassNames.tooltip, overrides.tooltip),
    arrow: overrides.arrow,
  };
}
const TooltipRoot = forwardRef<HTMLDivElement, TooltipProps>(
  ({ classNames, ...props }, ref) => (
    <MantineTooltip
      {...resolveTooltipProps(props)}
      ref={ref}
      classNames={(theme, values, ctx) =>
        resolveTooltipClassNames(
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames,
        )
      }
    />
  ),
);
TooltipRoot.displayName = 'SWorks/Tooltip';
export const Tooltip = Object.assign(TooltipRoot, {
  Group: MantineTooltip.Group,
  Floating: MantineTooltip.Floating,
});
