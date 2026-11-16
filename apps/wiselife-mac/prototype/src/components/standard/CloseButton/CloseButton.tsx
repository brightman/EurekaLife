import { forwardRef, type ComponentPropsWithoutRef } from 'react';
import cx from 'clsx';
import {
  CloseButton as MantineCloseButton,
  createPolymorphicComponent,
  rem,
  type CloseButtonProps as MantineCloseButtonProps,
} from '@mantine/core';
import { CloseLargeIcon, CloseMediumIcon, CloseSmallIcon } from './icons.js';

export interface CloseButtonProps extends MantineCloseButtonProps {
  'aria-label'?: string;
}
const closeButtonSizes: Record<string, number> = { lg: 24, md: 20, sm: 16 };
export function resolveCloseButtonProps({
  size = 'lg',
  radius,
  variant = 'subtle',
  ...props
}: CloseButtonProps): CloseButtonProps {
  return {
    p: 0,
    'aria-label': '关闭',
    ...props,
    size: typeof size === 'string' ? (closeButtonSizes[size] ?? size) : size,
    radius:
      radius ??
      (size === 'md' || size === 20 ? 5 : size === 'sm' || size === 16 ? 4 : 6),
    variant,
  };
}
export function resolveCloseButtonIcon({
  size = 'lg',
  icon,
  iconSize,
}: CloseButtonProps) {
  if (icon !== undefined) return icon;
  const Glyph =
    size === 'md' || size === 20
      ? CloseMediumIcon
      : size === 'sm' || size === 16
        ? CloseSmallIcon
        : CloseLargeIcon;
  return iconSize === undefined ? (
    <Glyph />
  ) : (
    <Glyph width={rem(iconSize)} height={rem(iconSize)} />
  );
}
export function resolveCloseButtonClassNames(
  overrides: Partial<Record<'root', string>> = {},
) {
  return {
    root: cx(
      'bg-transparent text-[#262626] [&[data-variant=subtle]:not(:disabled):not([data-disabled]):hover]:bg-[#f5f5f5]',
      overrides.root,
    ),
  };
}
type CloseButtonRootProps = CloseButtonProps &
  Omit<ComponentPropsWithoutRef<'button'>, keyof CloseButtonProps>;
const CloseButtonRoot = forwardRef<HTMLButtonElement, CloseButtonRootProps>(
  ({ classNames, ...props }, ref) => (
    <MantineCloseButton
      {...resolveCloseButtonProps(props)}
      ref={ref}
      icon={resolveCloseButtonIcon(props)}
      classNames={(theme, values, context) =>
        resolveCloseButtonClassNames(
          typeof classNames === 'function'
            ? classNames(theme, values, context)
            : classNames,
        )
      }
    />
  ),
);
CloseButtonRoot.displayName = 'SWorks/CloseButton';
export const CloseButton = createPolymorphicComponent<
  'button',
  CloseButtonProps
>(CloseButtonRoot);
