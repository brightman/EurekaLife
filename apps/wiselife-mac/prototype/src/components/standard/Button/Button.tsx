import { forwardRef } from 'react';
import cx from 'clsx';
import {
  createPolymorphicComponent,
  Button as MantineButton,
  type ButtonStylesNames,
  type ButtonProps as MantineButtonProps,
} from '@mantine/core';

export type ButtonProps = MantineButtonProps;
type ButtonSlots = Record<ButtonStylesNames, string>;

// Public numeric props follow Mantine's rem/scale conversion.
const buttonSizeProps: Record<string, Partial<ButtonProps>> = {
  xs: {
    h: 24,
    px: 8,
    py: 12,
    fz: 12,
    lh: 1.5,
  },
  sm: {
    h: 32,
    px: 12,
    py: 12,
    fz: 14,
    lh: 22 / 14,
  },
  md: {
    h: 40,
    px: 12,
    py: 12,
    fz: 14,
    lh: 22 / 14,
  },
};
const buttonRadiusProps: Record<string, number> = {
  xs: 4,
  sm: 6,
  md: 8,
};

// Shared by the component and its standalone copyable Mantine examples.
// Public props own root geometry and constant styles; consumer props win.
export function resolveButtonProps(props: ButtonProps = {}): ButtonProps {
  const { size = 'sm', variant = 'filled', color } = props;
  const definedProps = Object.fromEntries(
    Object.entries(props).filter(([, value]) => value !== undefined),
  );
  const standardColor =
    color === undefined || color === 'blue' || color === 'blue.8';
  const standardVariant = ['filled', 'outline', 'light', 'subtle'].includes(
    variant,
  );
  const palette = standardColor && standardVariant;
  return {
    ff: 'PingFang SC, sans-serif',
    fw: 400,
    radius: buttonRadiusProps[size] ?? 6,
    ...buttonSizeProps[size],
    ...(palette ? { bd: 0 } : {}),
    ...(palette && variant === 'filled' ? { c: '#ffffff' } : {}),
    ...(palette && (variant === 'outline' || variant === 'subtle')
      ? { bg: '#ffffff' }
      : {}),
    ...definedProps,
    size,
    variant,
    color: palette
      ? variant === 'light' || color === undefined
        ? '#262626'
        : '#165dff'
      : color,
  };
}

// Only design differences without equivalent props remain in public slots.
export const buttonClassNames = {
  root: 'transition-colors duration-150 focus-visible:[outline-style:solid] focus-visible:outline-[2px] focus-visible:outline-offset-[2px] focus-visible:outline-[#165dff] active:translate-y-0 motion-reduce:transition-none',
  inner: 'motion-reduce:transition-none',
  label: 'min-w-0',
  section: 'm-0 shrink-0',
  // Match the upstream loader transition's rem(1) offset, including root font size.
  loader: 'flex mt-[calc(-0.0625rem*var(--mantine-scale))]',
};
export const buttonLoaderClassNames = {
  root: "after:content-[''] after:w-3/4 after:h-3/4 after:m-[12.5%]",
};
const buttonInnerSizeClasses: Record<string, string> = {
  xs: 'gap-[4px]',
  sm: 'gap-[8px]',
  md: 'gap-[8px]',
};
const lightClasses =
  'bg-[#f5f5f5] [&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#ebebeb] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#d9d9d9] [&:is(:disabled,[data-disabled]):not([data-loading])]:bg-[#fafafa] [&:is(:disabled,[data-disabled]):not([data-loading])]:text-[#bfbfbf]';
const buttonVariantClasses: Record<string, Record<string, string>> = {
  action: {
    filled:
      '[&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#404040] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#141414] [&:is(:disabled,[data-disabled]):not([data-loading])]:bg-[#e5e5e5]',
    outline:
      'ring-inset ring-[1px] ring-[#262626] [&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:text-[#404040] [&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:ring-[#404040] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:text-black [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:ring-[#141414] [&:is(:disabled,[data-disabled]):not([data-loading])]:text-[#bfbfbf] [&:is(:disabled,[data-disabled]):not([data-loading])]:ring-[#e5e5e5]',
    subtle:
      '[&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:text-[#404040] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:text-black [&:is(:disabled,[data-disabled]):not([data-loading])]:text-[#bfbfbf]',
    light: lightClasses,
  },
  brand: {
    filled:
      '[&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#3975ff] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:bg-[#0044e5] [&:is(:disabled,[data-disabled]):not([data-loading])]:bg-[#adc6ff]',
    outline:
      'ring-inset ring-[1px] ring-[#165dff] [&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:text-[#3975ff] [&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:ring-[#3975ff] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:text-[#0044e5] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:ring-[#0044e5] [&:is(:disabled,[data-disabled]):not([data-loading])]:text-[#adc6ff] [&:is(:disabled,[data-disabled]):not([data-loading])]:ring-[#adc6ff]',
    subtle:
      '[&:hover:not(:active):not(:disabled):not([data-disabled]):not([data-loading])]:text-[#3975ff] [&:active:not(:disabled):not([data-disabled]):not([data-loading])]:text-[#0044e5] [&:is(:disabled,[data-disabled]):not([data-loading])]:text-[#adc6ff]',
    light: lightClasses,
  },
};

export function resolveButtonClassNames(
  {
    color,
    size = 'sm',
    variant = 'filled',
  }: Pick<ButtonProps, 'color' | 'size' | 'variant' | 'radius'> = {},
  overrides: Partial<ButtonSlots> = {},
): ButtonSlots {
  return {
    root: cx(
      buttonClassNames.root,
      color === undefined
        ? buttonVariantClasses.action[variant]
        : color === 'blue' || color === 'blue.8'
          ? buttonVariantClasses.brand[variant]
          : undefined,
      overrides.root,
    ),
    inner: cx(
      buttonClassNames.inner,
      buttonInnerSizeClasses[size] ?? 'gap-[8px]',
      overrides.inner,
    ),
    label: cx(
      buttonClassNames.label,
      ['xs', 'sm', 'md'].includes(size) ? 'h-auto' : undefined,
      overrides.label,
    ),
    section: cx(buttonClassNames.section, overrides.section),
    loader: cx(buttonClassNames.loader, overrides.loader),
  };
}

const ButtonRoot = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ classNames, ...props }, ref) => (
    <MantineButton
      {...resolveButtonProps(props)}
      ref={ref}
      loaderProps={{
        color: 'currentColor',
        size: 16,
        ...props.loaderProps,
        classNames: (theme, loaderValues, ctx) => {
          const overrides =
            typeof props.loaderProps?.classNames === 'function'
              ? props.loaderProps.classNames(theme, loaderValues, ctx)
              : props.loaderProps?.classNames;
          return {
            root: cx(
              loaderValues.size === 16 && loaderValues.type === 'oval'
                ? buttonLoaderClassNames.root
                : undefined,
              overrides?.root,
            ),
          };
        },
      }}
      classNames={(theme, buttonProps, ctx) => {
        const overrides =
          typeof classNames === 'function'
            ? classNames(
                theme,
                { ...buttonProps, color: props.color, radius: props.radius },
                ctx,
              )
            : classNames;
        return resolveButtonClassNames(props, overrides);
      }}
    />
  ),
);
ButtonRoot.displayName = 'SWorks/Button';
export const Button = createPolymorphicComponent<'button', ButtonProps>(
  ButtonRoot,
);
