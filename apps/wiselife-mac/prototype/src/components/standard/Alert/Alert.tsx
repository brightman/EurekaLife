import { forwardRef } from 'react';
import cx from 'clsx';
import {
  Alert as MantineAlert,
  type AlertProps as MantineAlertProps,
} from '@mantine/core';
import { alertIcons, alertStatusIcons } from './icons.js';
export type AlertStatus =
  | 'success'
  | 'done'
  | 'warning'
  | 'error'
  | 'question'
  | 'questionOrange'
  | 'waiting'
  | 'waitingOrange'
  | 'loading';
export interface AlertProps extends MantineAlertProps {
  status?: AlertStatus;
  appearance?: 'message' | 'banner';
}
export const alertClassNames = {
  root: 'inline-block max-w-full border-0 [font-family:PingFang_SC,sans-serif] tracking-[0px] not-italic shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08),0_8px_16px_rgba(0,0,0,0.1)]',
  banner: 'shadow-[inset_0_0_0_1px_#fee8d0,0_8px_16px_rgba(0,0,0,0.1)]',
  wrapper: 'h-full items-center gap-[8px]',
  body: 'min-w-0 gap-[4px]',
  message:
    'text-[14px] font-normal leading-[22px] text-[#262626] whitespace-nowrap',
  title: 'p-0 text-[14px] font-medium leading-[22px]',
  icon: 'm-0 h-[16px] w-[16px] shrink-0 items-center justify-center',
  closeButton: 'h-[24px] w-[24px] shrink-0 rounded-[6px] p-0 text-[#262626]',
};
export function renderAlertIcon(status: AlertStatus) {
  const StatusIcon = alertStatusIcons[status];
  return (
    <span
      className={status === 'loading' ? 'motion-safe:animate-spin' : undefined}
    >
      <StatusIcon />
    </span>
  );
}
export function resolveAlertProps({
  status = 'success',
  appearance = 'message',
  withCloseButton = false,
  closeButtonLabel = '关闭提示',
  icon,
  attributes,
  ...props
}: AlertProps = {}) {
  const CloseIcon =
    appearance === 'banner' ? alertIcons.close : alertIcons.closeNormal;
  return {
    radius: 8,
    h: props.title ? undefined : 40,
    px: 16,
    py: props.title ? 8 : 0,
    pr: withCloseButton ? 8 : 16,
    bg: appearance === 'banner' ? '#fff9f3' : '#ffffff',
    c: '#262626',
    ...props,
    withCloseButton,
    closeButtonLabel,
    icon: icon === undefined ? renderAlertIcon(status) : icon,
    attributes: {
      ...attributes,
      closeButton: { icon: <CloseIcon />, ...attributes?.closeButton },
    },
  };
}
export function resolveAlertClassNames(
  { appearance = 'message' }: Pick<AlertProps, 'appearance'> = {},
  overrides: Partial<
    Record<import('@mantine/core').AlertStylesNames, string>
  > = {},
) {
  return {
    ...overrides,
    root: cx(
      alertClassNames.root,
      appearance === 'banner' && alertClassNames.banner,
      overrides.root,
    ),
    wrapper: cx(alertClassNames.wrapper, overrides.wrapper),
    body: cx(alertClassNames.body, overrides.body),
    message: cx(alertClassNames.message, overrides.message),
    title: cx(alertClassNames.title, overrides.title),
    icon: cx(alertClassNames.icon, overrides.icon),
    closeButton: cx(alertClassNames.closeButton, overrides.closeButton),
  };
}
export const Alert = forwardRef<HTMLDivElement, AlertProps>(
  ({ classNames, ...props }, ref) => (
    <MantineAlert
      {...resolveAlertProps(props)}
      ref={ref}
      classNames={(theme, values, ctx) =>
        resolveAlertClassNames(
          props,
          typeof classNames === 'function'
            ? classNames(theme, values, ctx)
            : classNames,
        )
      }
    />
  ),
);
Alert.displayName = 'SWorks/Alert';
