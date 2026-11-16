import { type SVGProps } from 'react';

// Special design glyphs: keep the original viewBox, paths and colors.
export function CheckboxCheckIcon({
  size,
  width = size ?? '14',
  height = size ?? '14',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 14 14"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g>
        <path
          d="M10.1787 4.48866C10.3626 4.67236 10.3747 4.96606 10.207 5.16469L7.02914 8.92534L7.05538 8.95296L6.74049 9.26785L6.46221 9.59723C6.38965 9.68306 6.29457 9.73609 6.19359 9.75951C6.00891 9.83603 5.78823 9.79845 5.64116 9.64488L3.79053 7.71138C3.60265 7.51508 3.60545 7.20484 3.79744 7.01256L4.15099 6.65901C4.34921 6.46067 4.67172 6.46412 4.86569 6.66661L5.99057 7.83982L9.09176 4.16963C9.28044 3.94631 9.61944 3.93146 9.82649 4.13787L10.1787 4.48866Z"
          fill="currentColor"
        />
      </g>
    </svg>
  );
}
