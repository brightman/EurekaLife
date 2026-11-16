import { forwardRef } from 'react';
import cx from 'clsx';
import {
  createPolymorphicComponent,
  InputBase as MantineInputBase,
  type InputBaseProps as MantineInputBaseProps,
  type InputBaseFactory,
} from '@mantine/core';
export type InputBaseSize = 'lg' | 'md' | 'sm';
export type InputBaseAppearance = 'filled' | 'outlined';
export interface InputBaseProps extends MantineInputBaseProps {
  size?: InputBaseSize;
  appearance?: InputBaseAppearance;
}
interface VisualOptions {
  size?: InputBaseSize;
  appearance?: InputBaseAppearance;
  hasLeftSection?: boolean;
  hasRightSection?: boolean;
  disabled?: boolean;
}
const sizes = {
  lg: {
    input: 'h-[48px] text-[16px] leading-[24px]',
    padding: 'ps-[16px]',
    end: 'pe-[16px]',
    left: 'ps-[44px] focus:ps-[40px]',
    right: 'pe-[44px]',
    radius: 8,
    section: 48,
  },
  md: {
    input: 'h-[40px] text-[14px] leading-[22px]',
    padding: 'ps-[12px]',
    end: 'pe-[12px]',
    left: 'ps-[36px]',
    right: 'pe-[36px]',
    radius: 8,
    section: 40,
  },
  sm: {
    input: 'h-[32px] text-[14px] leading-[22px]',
    padding: 'ps-[8px]',
    end: 'pe-[8px]',
    left: 'ps-[32px]',
    right: 'pe-[32px]',
    radius: 6,
    section: 32,
  },
};
const appearances = {
  filled:
    'bg-[#f2f3f5] [&:enabled:hover:not(:focus)]:bg-[#e5e6eb] enabled:focus:bg-white enabled:focus:shadow-[inset_0_0_0_1px_#165dff]',
  outlined:
    'bg-white shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08)] [&:enabled:hover:not(:focus)]:shadow-[inset_0_0_0_1px_rgba(0,0,0,0.12)] enabled:focus:shadow-[inset_0_0_0_1px_#165dff]',
};
export function resolveInputBaseProps({
  size = 'md',
  appearance: _appearance,
  ...props
}: InputBaseProps = {}) {
  return {
    w: 220,
    maw: '100%',
    ...props,
    size,
    radius: props.radius ?? sizes[size].radius,
    leftSectionWidth: props.leftSectionWidth ?? sizes[size].section,
    rightSectionWidth: props.rightSectionWidth ?? sizes[size].section,
    leftSectionPointerEvents: props.leftSectionPointerEvents ?? 'none',
    inputWrapperOrder: props.inputWrapperOrder ?? ['label', 'input', 'description', 'error'],
  };
}
export function resolveInputBaseClassNames(
  {
    size = 'md',
    appearance = 'filled',
    hasLeftSection = false,
    hasRightSection = false,
    disabled = false,
  }: VisualOptions = {},
  overrides: Partial<Record<InputBaseFactory['stylesNames'], string>> = {},
) {
  return {
    ...overrides,
    root: cx(
      'group/base min-w-0 [font-family:PingFang_SC,sans-serif] tracking-[0px]',
      overrides.root,
    ),
    wrapper: cx('mb-0', overrides.wrapper),
    input: cx(
      'min-h-0 border-0 py-0 font-normal text-[#262626] placeholder:text-[#8c8c8c] disabled:cursor-not-allowed disabled:text-[#bfbfbf] disabled:placeholder:text-[#bfbfbf] disabled:opacity-100 data-[error]:shadow-[inset_0_0_0_1px_#ff4d4f]',
      sizes[size].input,
      hasLeftSection ? sizes[size].left : sizes[size].padding,
      hasRightSection ? sizes[size].right : sizes[size].end,
      appearances[appearance],
      overrides.input,
    ),
    section: cx(
      'data-[position=left]:start-0 data-[position=right]:end-0',
      disabled
        ? 'text-[#bfbfbf]'
        : 'text-[#8c8c8c] group-has-[input:not(:placeholder-shown)]/base:text-[#262626]',
      overrides.section,
    ),
    description: cx(
      'mb-0 mt-[4px] text-[12px] font-normal leading-[18px] text-[#8c8c8c]',
      overrides.description,
    ),
    error: cx('mt-[4px] text-[12px] leading-[18px] text-[#ff4d4f]', overrides.error),
  };
}
const InputBaseRoot = forwardRef<HTMLInputElement, InputBaseProps>(
  ({ size = 'md', appearance = 'filled', classNames, ...props }, ref) => (
    <MantineInputBase
      ref={ref}
      {...resolveInputBaseProps({ size, ...props })}
      classNames={(theme, values, context) =>
        resolveInputBaseClassNames(
          {
            size,
            appearance,
            disabled: props.disabled,
            hasLeftSection: Boolean(props.leftSection),
            hasRightSection: Boolean(props.rightSection),
          },
          typeof classNames === 'function' ? classNames(theme, values, context) : classNames,
        )
      }
    />
  ),
);
InputBaseRoot.displayName = 'SWorks/InputBase';
export const InputBase = createPolymorphicComponent<'input', InputBaseProps>(InputBaseRoot);
