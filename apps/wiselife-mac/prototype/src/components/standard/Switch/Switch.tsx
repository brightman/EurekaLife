import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Switch as MantineSwitch,
  type SwitchProps as MantineSwitchProps,
} from '@mantine/core';
export interface SwitchProps extends MantineSwitchProps {}
export const switchClassNames = {
  root: '[font-family:PingFang_SC,sans-serif] tracking-[0px] not-italic',
  body: 'items-center',
  track:
    'border-0 bg-[#dadbe2] [input:checked+&]:bg-[var(--switch-color)] [input:disabled+&]:bg-[#f2f3f5] [input:checked:disabled+&]:bg-[#adc6ff]',
  thumb: 'border-0 bg-white shadow-[0_1px_3px_rgba(0,0,0,0.1)]',
  largeTrack: 'w-[40px] min-w-[40px] h-[24px]',
  smallTrack: 'w-[28px] min-w-[28px] h-[16px]',
  largeThumb:
    'h-[16px] w-[16px] start-[4px] [input:checked+*>&]:start-[calc(100%-20px)]',
  smallThumb:
    'h-[12px] w-[12px] start-[2px] [input:checked+*>&]:start-[calc(100%-14px)] shadow-[0_0.75px_2.25px_rgba(0,0,0,0.1)]',
  label:
    'pl-[8px] text-[14px] font-normal leading-[22px] text-[#262626] data-[disabled]:text-[#bfbfbf]',
};
export function resolveSwitchProps({
  size = 'md',
  radius = 24,
  color = '#165dff',
  withThumbIndicator = false,
  ...props
}: SwitchProps = {}) {
  return { ...props, size, radius, color, withThumbIndicator };
}
export function resolveSwitchClassNames(
  { size = 'md' }: Pick<SwitchProps, 'size'> = {},
  overrides: Partial<
    Record<import('@mantine/core').SwitchStylesNames, string>
  > = {},
) {
  return {
    ...overrides,
    root: cx(switchClassNames.root, overrides.root),
    body: cx(switchClassNames.body, overrides.body),
    track: cx(
      switchClassNames.track,
      size === 'md' && switchClassNames.largeTrack,
      size === 'xs' && switchClassNames.smallTrack,
      overrides.track,
    ),
    thumb: cx(
      switchClassNames.thumb,
      size === 'md' && switchClassNames.largeThumb,
      size === 'xs' && switchClassNames.smallThumb,
      overrides.thumb,
    ),
    label: cx(switchClassNames.label, overrides.label),
  };
}
const SwitchRoot = forwardRef<HTMLInputElement, SwitchProps>(
  ({ classNames, ...props }, ref) => (
    <MantineSwitch
      {...resolveSwitchProps(props)}
      ref={ref}
      classNames={(theme, values, ctx) => {
        const overrides =
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames;
        return resolveSwitchClassNames(props, overrides);
      }}
    />
  ),
);
SwitchRoot.displayName = 'SWorks/Switch';
export const Switch: typeof SwitchRoot & Pick<typeof MantineSwitch, 'Group'> =
  Object.assign(SwitchRoot, { Group: MantineSwitch.Group });
