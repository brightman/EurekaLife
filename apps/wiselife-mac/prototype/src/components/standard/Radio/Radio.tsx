import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Radio as MantineRadio,
  type RadioProps as MantineRadioProps,
} from '@mantine/core';
export interface RadioProps extends MantineRadioProps {}
export const radioClassNames = {
  root: '[font-family:PingFang_SC,sans-serif] tracking-[0px] not-italic',
  body: 'items-center',
  labeledBody: 'min-h-[22px] items-start',
  labeledInner: 'mt-[5px]',
  radio:
    'border-2 border-solid border-[#e5e6eb] bg-white enabled:hover:[&:not(:checked)]:border-[#dadbe2] checked:border-[var(--radio-color)] checked:bg-[var(--radio-color)] disabled:border-[#e5e6eb] disabled:bg-[#f2f3f5] disabled:checked:border-[#adc6ff] disabled:checked:bg-[#adc6ff]',
  icon: 'h-[6px] w-[6px] left-[calc(50%-3px)] top-[calc(50%-3px)]',
  label:
    'pl-[8px] text-[14px] font-normal leading-[22px] text-[#262626] data-[disabled]:text-[#bfbfbf]',
};
export function resolveRadioProps({
  size = '14px',
  color = '#165dff',
  iconColor = '#ffffff',
  ...props
}: RadioProps = {}) {
  return { ...props, size, color, iconColor };
}
export function resolveRadioClassNames(
  { label }: Pick<RadioProps, 'label'> = {},
  overrides: Partial<
    Record<import('@mantine/core').RadioStylesNames, string>
  > = {},
) {
  return {
    ...overrides,
    root: cx(radioClassNames.root, overrides.root),
    body: cx(
      radioClassNames.body,
      label && radioClassNames.labeledBody,
      overrides.body,
    ),
    radio: cx(radioClassNames.radio, overrides.radio),
    icon: cx(radioClassNames.icon, overrides.icon),
    inner: cx(label && radioClassNames.labeledInner, overrides.inner),
    label: cx(radioClassNames.label, overrides.label),
  };
}
const RadioRoot = forwardRef<HTMLInputElement, RadioProps>(
  ({ classNames, ...props }, ref) => (
    <MantineRadio
      {...resolveRadioProps(props)}
      ref={ref}
      classNames={(theme, values, ctx) => {
        const overrides =
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames;
        return resolveRadioClassNames(props, overrides);
      }}
    />
  ),
);
RadioRoot.displayName = 'SWorks/Radio';
export const Radio: typeof RadioRoot &
  Pick<typeof MantineRadio, 'Group' | 'Card' | 'Indicator'> = Object.assign(
  RadioRoot,
  {
    Group: MantineRadio.Group,
    Card: MantineRadio.Card,
    Indicator: MantineRadio.Indicator,
  },
);
