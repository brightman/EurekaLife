import { useId, type SVGProps } from 'react';

export function RingIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path
        d="M14 8C14 4.68629 11.3137 2 8 2C4.68629 2 2 4.68629 2 8C2 11.3137 4.68629 14 8 14V16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16V14C11.3137 14 14 11.3137 14 8Z"
        fill="currentColor"
        fillOpacity="0.1"
      />
      <path
        d="M8 0C12.4183 0 16 3.58172 16 8H14C14 4.68629 11.3137 2 8 2V0Z"
        fill="currentColor"
      />
    </svg>
  );
}

export function GradientIcon(props: SVGProps<SVGSVGElement>) {
  const id = useId();
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <defs>
        <mask id={id + '-mask'}>
          <path
            d="M15 8C15 11.866 11.866 15 8 15C4.13401 15 1 11.866 1 8C1 4.13401 4.13401 1 8 1C11.866 1 15 4.13401 15 8Z"
            strokeWidth="2"
            stroke="white"
          />
        </mask>
        <clipPath id={id + '-clip'}>
          <rect width="16" height="16" rx="8" />
        </clipPath>
      </defs>
      <g clipPath={`url(#${id}-clip)`}>
        <g mask={`url(#${id}-mask)`}>
          <g transform="matrix(0 0.007 -0.007 0 8 8)">
            <foreignObject
              x="-2285.71"
              y="-2285.71"
              width="4571.43"
              height="4571.43"
            >
              <div className="h-full w-full bg-[conic-gradient(from_90deg,rgba(22,93,255,0)_0deg,rgba(22,93,255,0.5)_90deg,rgba(22,93,255,0.5)_144deg,rgba(22,93,255,0.5)_216deg,rgba(22,93,255,0)_270deg,rgba(22,93,255,0)_360deg)]" />
            </foreignObject>
          </g>
        </g>
      </g>
    </svg>
  );
}
