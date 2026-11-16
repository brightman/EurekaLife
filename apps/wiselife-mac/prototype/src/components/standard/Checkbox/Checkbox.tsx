import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Checkbox as MantineCheckbox,
  type CheckboxProps as MantineCheckboxProps,
} from '@mantine/core';
import { CheckboxCheckIcon } from './icons.js';
export interface CheckboxProps extends MantineCheckboxProps {}
export const checkboxClassNames = {
  root: '[font-family:PingFang_SC,sans-serif] tracking-[0px] not-italic',
  body: 'items-center',
  labeledBody: 'min-h-[22px] items-start',
  labeledInner: 'mt-[5px]',
  input:
    'border-2 border-solid border-[#e5e6eb] bg-white enabled:hover:[&:not(:checked):not([data-indeterminate])]:border-[#dadbe2] checked:border-transparent checked:bg-[var(--checkbox-color)] data-[indeterminate]:border-transparent data-[indeterminate]:bg-[var(--checkbox-color)] disabled:border-[#e5e6eb] disabled:bg-[#f2f3f5] disabled:checked:border-transparent disabled:checked:bg-[#adc6ff] disabled:data-[indeterminate]:border-transparent disabled:data-[indeterminate]:bg-[#adc6ff]',
  icon: 'm-0 flex h-full w-full items-center justify-center',
  label:
    'pl-[8px] text-[14px] font-normal leading-[22px] text-[#262626] data-[disabled]:text-[#bfbfbf]',
};
export function CheckGlyph({
  indeterminate,
  className,
}: {
  indeterminate?: boolean;
  className?: string;
}) {
  return (
    <span className={className}>
      {indeterminate ? (
        <span className="h-[2px] w-[6px] rounded-[0.5px] bg-current" />
      ) : (
        <CheckboxCheckIcon width="100%" height="100%" />
      )}
    </span>
  );
}
export function resolveCheckboxProps({
  size = '14px',
  radius = 2,
  color = '#165dff',
  iconColor = '#ffffff',
  icon = CheckGlyph,
  ...props
}: CheckboxProps = {}) {
  return { ...props, size, radius, color, iconColor, icon };
}
export function resolveCheckboxClassNames(
  { label }: Pick<CheckboxProps, 'label'> = {},
  overrides: Partial<
    Record<import('@mantine/core').CheckboxStylesNames, string>
  > = {},
) {
  return {
    ...overrides,
    root: cx(checkboxClassNames.root, overrides.root),
    body: cx(
      checkboxClassNames.body,
      label && checkboxClassNames.labeledBody,
      overrides.body,
    ),
    input: cx(checkboxClassNames.input, overrides.input),
    icon: cx(checkboxClassNames.icon, overrides.icon),
    inner: cx(label && checkboxClassNames.labeledInner, overrides.inner),
    label: cx(checkboxClassNames.label, overrides.label),
  };
}
const CheckboxRoot = forwardRef<HTMLInputElement, CheckboxProps>(
  ({ classNames, ...props }, ref) => (
    <MantineCheckbox
      {...resolveCheckboxProps(props)}
      ref={ref}
      classNames={(theme, values, ctx) => {
        const overrides =
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames;
        return resolveCheckboxClassNames(props, overrides);
      }}
    />
  ),
);
CheckboxRoot.displayName = 'SWorks/Checkbox';
export const Checkbox: typeof CheckboxRoot &
  Pick<typeof MantineCheckbox, 'Group' | 'Card' | 'Indicator'> = Object.assign(
  CheckboxRoot,
  {
    Group: MantineCheckbox.Group,
    Card: MantineCheckbox.Card,
    Indicator: MantineCheckbox.Indicator,
  },
);
