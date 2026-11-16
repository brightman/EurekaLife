import { forwardRef, type ComponentPropsWithoutRef } from 'react';
import cx from 'clsx';
import {
  Loader as MantineLoader,
  type LoaderProps as MantineLoaderProps,
} from '@mantine/core';
import { RingIcon, GradientIcon } from './icons.js';

export interface LoaderProps extends MantineLoaderProps {}
export const RingLoader = forwardRef<
  HTMLSpanElement,
  ComponentPropsWithoutRef<'span'>
>((props, ref) => (
  <span {...props} ref={ref}>
    <RingIcon className="block h-full w-full animate-spin motion-reduce:animate-none" />
  </span>
));
RingLoader.displayName = 'SWorks/RingLoader';
export const GradientLoader = forwardRef<
  HTMLSpanElement,
  ComponentPropsWithoutRef<'span'>
>((props, ref) => (
  <span {...props} ref={ref}>
    <GradientIcon className="block h-full w-full animate-spin motion-reduce:animate-none" />
  </span>
));
GradientLoader.displayName = 'SWorks/GradientLoader';
export const loaderTypes = {
  ...MantineLoader.defaultLoaders,
  ring: RingLoader,
  gradient: GradientLoader,
};
export function resolveLoaderProps({
  size = 16,
  color = '#165dff',
  type = 'ring',
  loaders,
  ...props
}: LoaderProps = {}): LoaderProps {
  return {
    role: 'status',
    'aria-label': '正在加载',
    ...props,
    size,
    color,
    type,
    loaders: { ...loaderTypes, ...loaders },
  };
}
export function resolveLoaderClassNames(
  overrides: Partial<Record<'root', string>> = {},
) {
  return {
    root: cx(
      'relative inline-flex h-[var(--loader-size)] w-[var(--loader-size)] shrink-0 items-center justify-center text-[var(--loader-color)]',
      overrides.root,
    ),
  };
}
const LoaderRoot = forwardRef<HTMLSpanElement, LoaderProps>(
  ({ classNames, ...props }, ref) => (
    <MantineLoader
      {...resolveLoaderProps(props)}
      ref={ref}
      classNames={(theme, values, context) =>
        resolveLoaderClassNames(
          typeof classNames === 'function'
            ? classNames(theme, values, context)
            : classNames,
        )
      }
    />
  ),
);
LoaderRoot.displayName = 'SWorks/Loader';
export const Loader = Object.assign(LoaderRoot, {
  defaultLoaders: loaderTypes,
});
