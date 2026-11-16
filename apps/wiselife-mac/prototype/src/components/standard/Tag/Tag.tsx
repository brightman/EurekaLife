import {
  forwardRef,
  type ComponentPropsWithoutRef,
  type ElementType,
  type MouseEvent,
} from 'react';
import cx from 'clsx';
import {
  Badge as MantineBadge,
  CloseButton,
  createPolymorphicComponent,
  type BadgeProps,
  type BadgeStylesNames,
  type CloseButtonProps,
} from '@mantine/core';
import { TagCloseIcon } from './icons.js';
export type TagSize = 'lg' | 'md' | 'sm';
export type TagTone = 'neutral' | 'primary' | 'success' | 'error' | 'warning';
export type TagVariant = 'filled' | 'outline' | 'soft' | 'light';
export type TagShape = 'base' | 'rounded' | 'pill';
export interface TagProps
  extends Omit<BadgeProps, 'variant' | 'size' | 'color' | 'gradient' | 'autoContrast' | 'circle'> {
  size?: TagSize;
  tone?: TagTone;
  variant?: TagVariant;
  shape?: TagShape;
  disabled?: boolean;
  closable?: boolean;
  onClose?: (event: MouseEvent<HTMLButtonElement>) => void;
  closeButtonProps?: CloseButtonProps & ComponentPropsWithoutRef<'button'>;
}
const sizes = {
  lg: {
    h: 32,
    fz: 14,
    px: 12,
    line: 'leading-[22px]',
    start: 'me-[8px]',
    end: 'ms-[8px]',
    r: { base: 4, rounded: 6, pill: 16 },
  },
  md: {
    h: 24,
    fz: 12,
    px: 8,
    line: 'leading-[18px]',
    start: 'me-[4px]',
    end: 'ms-[4px]',
    r: { base: 3, rounded: 6, pill: 12 },
  },
  sm: {
    h: 20,
    fz: 12,
    px: 6,
    line: 'leading-[18px]',
    start: 'me-[4px]',
    end: 'ms-[4px]',
    r: { base: 3, rounded: 4, pill: 12 },
  },
};
const palette = {
  neutral: {
    filled: {
      normal: 'text-[#262626] bg-[#f2f3f5] shadow-none',
      disabled: 'text-[#bfbfbf] bg-[#f2f3f5] shadow-none',
    },
    outline: {
      normal: 'text-[#262626] bg-transparent shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08)]',
      disabled: 'text-[#bfbfbf] bg-transparent shadow-[inset_0_0_0_1px_rgba(0,0,0,0.05)]',
    },
    soft: {
      normal: 'text-[#262626] bg-[#f5f5f5] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08)]',
      disabled: 'text-[#bfbfbf] bg-[#f5f5f5] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.05)]',
    },
    light: {
      normal: 'text-[#262626] bg-[#f5f5f5] shadow-none',
      disabled: 'text-[#bfbfbf] bg-[#f5f5f5] shadow-none',
    },
  },
  primary: {
    filled: {
      normal: 'text-white bg-[#165dff] shadow-none',
      disabled: 'text-white bg-[#adc6ff] shadow-none',
    },
    outline: {
      normal: 'text-[#165dff] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#adc6ff] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
    },
    soft: {
      normal: 'text-[#165dff] bg-[#f3f7ff] shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#adc6ff] bg-[#f3f7ff] shadow-[inset_0_0_0_1px_currentColor]',
    },
    light: {
      normal: 'text-[#165dff] bg-[#f3f7ff] shadow-none',
      disabled: 'text-[#adc6ff] bg-[#f3f7ff] shadow-none',
    },
  },
  success: {
    filled: {
      normal: 'text-white bg-[#0dc15b] shadow-none',
      disabled: 'text-white bg-[#b6ecce] shadow-none',
    },
    outline: {
      normal: 'text-[#0dc15b] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#b6ecce] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
    },
    soft: {
      normal: 'text-[#0dc15b] bg-[#e7f9ef] shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#b6ecce] bg-[#e7f9ef] shadow-[inset_0_0_0_1px_currentColor]',
    },
    light: {
      normal: 'text-[#0dc15b] bg-[#e7f9ef] shadow-none',
      disabled: 'text-[#b6ecce] bg-[#e7f9ef] shadow-none',
    },
  },
  error: {
    filled: {
      normal: 'text-white bg-[#fa8c16] shadow-none',
      disabled: 'text-white bg-[#fdd7ad] shadow-none',
    },
    outline: {
      normal: 'text-[#fa8c16] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#fdd7ad] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
    },
    soft: {
      normal: 'text-[#fa8c16] bg-[#fff9f3] shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#fdd7ad] bg-[#fff9f3] shadow-[inset_0_0_0_1px_currentColor]',
    },
    light: {
      normal: 'text-[#fa8c16] bg-[#fff9f3] shadow-none',
      disabled: 'text-[#fdd7ad] bg-[#fff9f3] shadow-none',
    },
  },
  warning: {
    filled: {
      normal: 'text-white bg-[#f53f3f] shadow-none',
      disabled: 'text-white bg-[#fbbcbc] shadow-none',
    },
    outline: {
      normal: 'text-[#f53f3f] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#fbbcbc] bg-transparent shadow-[inset_0_0_0_1px_currentColor]',
    },
    soft: {
      normal: 'text-[#f53f3f] bg-[#fef5f5] shadow-[inset_0_0_0_1px_currentColor]',
      disabled: 'text-[#fbbcbc] bg-[#fef5f5] shadow-[inset_0_0_0_1px_currentColor]',
    },
    light: {
      normal: 'text-[#f53f3f] bg-[#fef5f5] shadow-none',
      disabled: 'text-[#fbbcbc] bg-[#fef5f5] shadow-none',
    },
  },
};
export function resolveTagProps({
  size = 'md',
  shape = 'base',
  tone: _tone,
  variant: _variant,
  disabled: _disabled,
  closable: _closable,
  onClose: _onClose,
  closeButtonProps: _close,
  ...props
}: TagProps = {}) {
  return {
    h: sizes[size].h,
    fz: sizes[size].fz,
    px: sizes[size].px,
    ...props,
    size,
    radius: props.radius ?? sizes[size].r[shape],
    variant: 'default' as const,
  };
}
export function resolveTagClassNames(
  {
    size = 'md',
    tone = 'neutral',
    variant = 'filled',
    disabled = false,
  }: Pick<TagProps, 'size' | 'tone' | 'variant' | 'disabled'> = {},
  overrides: Partial<Record<BadgeStylesNames, string>> = {},
) {
  return {
    ...overrides,
    root: cx(
      'inline-flex flex-none items-center border-0 py-0 font-normal normal-case tracking-[0px] [font-family:PingFang_SC,sans-serif]',
      sizes[size].line,
      palette[tone][variant][disabled ? 'disabled' : 'normal'],
      disabled ? 'cursor-not-allowed' : '',
      overrides.root,
    ),
    label: cx('leading-[inherit]', overrides.label),
    section: cx(
      'inline-flex shrink-0 items-center leading-none data-[position=left]:ms-0 data-[position=right]:me-0',
      size === 'lg'
        ? 'data-[position=left]:me-[8px] data-[position=right]:ms-[8px]'
        : 'data-[position=left]:me-[4px] data-[position=right]:ms-[4px]',
      overrides.section,
    ),
  };
}
export function renderTagCloseButton({
  disabled,
  onClose,
  closeButtonProps,
}: Pick<TagProps, 'disabled' | 'onClose' | 'closeButtonProps'>) {
  return (
    <CloseButton
      size={16}
      radius={0}
      c="inherit"
      variant="transparent"
      {...closeButtonProps}
      icon={closeButtonProps?.icon ?? <TagCloseIcon />}
      disabled={disabled || closeButtonProps?.disabled}
      aria-label={closeButtonProps?.['aria-label'] ?? '移除标签'}
      classNames={(theme, values, context) => {
        const overrides =
          typeof closeButtonProps?.classNames === 'function'
            ? closeButtonProps.classNames(theme, values, context)
            : closeButtonProps?.classNames;
        return {
          ...overrides,
          root: cx(
            'p-0 hover:bg-transparent disabled:bg-transparent disabled:opacity-100',
            overrides?.root,
          ),
        };
      }}
      onClick={(event) => {
        event.stopPropagation();
        if (disabled) return;
        closeButtonProps?.onClick?.(event);
        if (!event.defaultPrevented) onClose?.(event);
      }}
    />
  );
}
type TagRootProps = TagProps &
  Omit<ComponentPropsWithoutRef<'span'>, keyof TagProps> & { component?: ElementType };
const TagRoot = forwardRef<HTMLSpanElement, TagRootProps>(
  (
    {
      size = 'md',
      tone = 'neutral',
      variant = 'filled',
      shape = 'base',
      disabled = false,
      closable = false,
      onClose,
      closeButtonProps,
      classNames,
      onClick,
      onKeyDown,
      ...props
    },
    ref,
  ) => (
    <MantineBadge
      component="span"
      {...resolveTagProps({ size, shape, ...props })}
      {...(props.component === 'button' ? { disabled } : {})}
      ref={ref}
      aria-disabled={disabled || props['aria-disabled']}
      data-disabled={disabled || undefined}
      rightSection={
        props.rightSection !== undefined
          ? props.rightSection
          : closable
            ? renderTagCloseButton({ disabled, onClose, closeButtonProps })
            : undefined
      }
      onClick={(event) => {
        if (disabled) {
          event.preventDefault();
          event.stopPropagation();
          return;
        }
        onClick?.(event);
      }}
      onKeyDown={(event) => {
        if (disabled) {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            event.stopPropagation();
          }
          return;
        }
        onKeyDown?.(event);
      }}
      classNames={(theme, values, context) =>
        resolveTagClassNames(
          { size, tone, variant, disabled },
          typeof classNames === 'function' ? classNames(theme, values, context) : classNames,
        )
      }
    />
  ),
);
TagRoot.displayName = 'SWorks/Tag';
export const Tag = createPolymorphicComponent<'span', TagProps>(TagRoot);
