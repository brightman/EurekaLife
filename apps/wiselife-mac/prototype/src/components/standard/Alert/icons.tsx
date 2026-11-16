import { useId, type SVGProps } from 'react';

// Special design glyphs: keep the original viewBox, paths and colors.
export function CloseIcon({
  size,
  width = size ?? '6.33074',
  height = size ?? '6.33074',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 6.33074 6.33074"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path
        d="M5.19464 0.194563C5.45427 -0.0648887 5.87638 -0.0648198 6.13605 0.194563C6.3957 0.454208 6.39559 0.876257 6.13605 1.13597L4.10675 3.16527L6.13605 5.19456C6.3957 5.45421 6.39559 5.87626 6.13605 6.13597C5.87635 6.39567 5.45434 6.39567 5.19464 6.13597L3.16535 4.10667L1.13605 6.13597C0.87635 6.39567 0.454341 6.39567 0.194642 6.13597C-0.0647931 5.87625 -0.0649685 5.45417 0.194642 5.19456L2.22394 3.16527L0.194642 1.13597C-0.0647928 0.876248 -0.0649684 0.454174 0.194642 0.194563C0.454267 -0.0648888 0.876381 -0.0648196 1.13605 0.194563L3.16535 2.22386L5.19464 0.194563Z"
        fill="#BFBFBF"
      />
    </svg>
  );
}

export function CloseNormalIcon({
  size,
  width = size ?? '6.33074',
  height = size ?? '6.33074',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 6.33074 6.33074"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path
        d="M5.19464 0.194563C5.45427 -0.0648887 5.87638 -0.0648198 6.13605 0.194563C6.3957 0.454208 6.39559 0.876257 6.13605 1.13597L4.10675 3.16527L6.13605 5.19456C6.3957 5.45421 6.39559 5.87626 6.13605 6.13597C5.87635 6.39567 5.45434 6.39567 5.19464 6.13597L3.16535 4.10667L1.13605 6.13597C0.87635 6.39567 0.454341 6.39567 0.194642 6.13597C-0.0647931 5.87625 -0.0649685 5.45417 0.194642 5.19456L2.22394 3.16527L0.194642 1.13597C-0.0647928 0.876248 -0.0649684 0.454174 0.194642 0.194563C0.454267 -0.0648888 0.876381 -0.0648196 1.13605 0.194563L3.16535 2.22386L5.19464 0.194563Z"
        fill="black"
      />
    </svg>
  );
}

export function DoneIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_89)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM11.9707 5.5293C11.711 5.2696 11.289 5.2696 11.0293 5.5293L7 9.55859L4.9707 7.5293C4.711 7.2696 4.289 7.2696 4.0293 7.5293C3.7696 7.789 3.7696 8.211 4.0293 8.4707L6.5293 10.9707L7 11.4404L7.4707 10.9707L11.9707 6.4707C12.2304 6.211 12.2304 5.789 11.9707 5.5293Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#165DFF"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_89'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function ErrorIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_111)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM8 11.335C7.63273 11.335 7.33496 11.6327 7.33496 12C7.33496 12.3673 7.63273 12.665 8 12.665C8.36726 12.665 8.66504 12.3673 8.66504 12C8.66504 11.6327 8.36727 11.335 8 11.335ZM8 3.33496C7.63273 3.33496 7.33496 3.63273 7.33496 4V9.5C7.33496 9.86727 7.63273 10.165 8 10.165C8.36727 10.165 8.66504 9.86727 8.66504 9.5V4C8.66504 3.63273 8.36727 3.33496 8 3.33496Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#F53F3F"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_111'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function LoadingIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g>
        <g clipPath={`url(#${id}-clip0_0_59)`}>
          <g>
            <mask id={id + '-stroke0_0_59'}>
              <path
                d="M15 8C15 11.866 11.866 15 8 15C4.13401 15 1 11.866 1 8C1 4.13401 4.13401 1 8 1C11.866 1 15 4.13401 15 8Z"
                strokeWidth="2"
                stroke="white"
              />
            </mask>
            <g
              clipPath={`url(#${id}-paint0_angular_0_59_clip_path)`}
              mask={`url(#${id}-stroke0_0_59)`}
            >
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
            <path
              d="M15 8C15 11.866 11.866 15 8 15C4.13401 15 1 11.866 1 8C1 4.13401 4.13401 1 8 1C11.866 1 15 4.13401 15 8Z"
              strokeWidth="2"
              stroke="black"
              strokeOpacity="0"
            />
          </g>
        </g>
      </g>
      <defs>
        <clipPath id={id + '-paint0_angular_0_59_clip_path'}>
          <rect x="-8" y="-8" width="32" height="32" />
        </clipPath>
        <clipPath id={id + '-clip0_0_59'}>
          <rect width="16" height="16" rx="8" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function QuestionIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM8.07812 10.8281C7.83098 10.8281 7.60858 10.9023 7.43555 11.0752C7.26247 11.2359 7.17578 11.4464 7.17578 11.7061C7.17583 11.9532 7.26258 12.1629 7.43555 12.3359C7.60861 12.509 7.83089 12.5957 8.07812 12.5957C8.32531 12.5957 8.54765 12.5093 8.7207 12.3486C8.89373 12.1756 8.99311 11.9656 8.99316 11.7061C8.99316 11.4464 8.90648 11.2359 8.7334 11.0752C8.56033 10.9022 8.3377 10.8281 8.07812 10.8281ZM8.30078 3.5957C7.38602 3.5957 6.66863 3.85521 6.14941 4.38672C5.76139 4.77474 5.51895 5.26688 5.4209 5.86719C5.36317 6.22084 5.66121 6.51353 6.01953 6.51367C6.37795 6.51367 6.65496 6.21887 6.7334 5.86914C6.78818 5.62477 6.87807 5.41944 7.00293 5.25293C7.25014 4.89448 7.6577 4.72076 8.21387 4.7207C8.65881 4.7207 9.0174 4.84467 9.26465 5.0918C9.49952 5.33903 9.62303 5.67282 9.62305 6.10547C9.62305 6.42685 9.4998 6.72351 9.27734 7.00781L9.06738 7.24316C8.3009 7.92311 7.83064 8.43021 7.66992 8.77637C7.49705 9.09767 7.42287 9.49307 7.42285 9.9502C7.42285 10.0662 7.51688 10.16 7.63281 10.1602H8.53516C8.65123 10.1602 8.74609 10.0663 8.74609 9.9502C8.74611 9.65369 8.80753 9.38188 8.94336 9.13477C9.05462 8.91224 9.228 8.68901 9.46289 8.49121C10.0435 7.98468 10.3896 7.66342 10.501 7.52734C10.81 7.13174 10.9707 6.62432 10.9707 6.01855C10.9706 5.27703 10.7239 4.68358 10.2295 4.25098C9.735 3.80594 9.09195 3.59572 8.30078 3.5957Z"
          fill="#165DFF"
        />
      </g>
    </svg>
  );
}

export function QuestionOrangeIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM8.07812 10.8281C7.83098 10.8281 7.60858 10.9023 7.43555 11.0752C7.26247 11.2359 7.17578 11.4464 7.17578 11.7061C7.17583 11.9532 7.26258 12.1629 7.43555 12.3359C7.60861 12.509 7.83089 12.5957 8.07812 12.5957C8.32531 12.5957 8.54765 12.5093 8.7207 12.3486C8.89373 12.1756 8.99311 11.9656 8.99316 11.7061C8.99316 11.4464 8.90648 11.2359 8.7334 11.0752C8.56033 10.9022 8.3377 10.8281 8.07812 10.8281ZM8.30078 3.5957C7.38602 3.5957 6.66863 3.85521 6.14941 4.38672C5.76139 4.77474 5.51895 5.26688 5.4209 5.86719C5.36317 6.22084 5.66121 6.51353 6.01953 6.51367C6.37795 6.51367 6.65496 6.21887 6.7334 5.86914C6.78818 5.62477 6.87807 5.41944 7.00293 5.25293C7.25014 4.89448 7.6577 4.72076 8.21387 4.7207C8.65881 4.7207 9.0174 4.84467 9.26465 5.0918C9.49952 5.33903 9.62303 5.67282 9.62305 6.10547C9.62305 6.42685 9.4998 6.72351 9.27734 7.00781L9.06738 7.24316C8.3009 7.92311 7.83064 8.43021 7.66992 8.77637C7.49705 9.09767 7.42287 9.49307 7.42285 9.9502C7.42285 10.0662 7.51688 10.16 7.63281 10.1602H8.53516C8.65123 10.1602 8.74609 10.0663 8.74609 9.9502C8.74611 9.65369 8.80753 9.38188 8.94336 9.13477C9.05462 8.91224 9.228 8.68901 9.46289 8.49121C10.0435 7.98468 10.3896 7.66342 10.501 7.52734C10.81 7.13174 10.9707 6.62432 10.9707 6.01855C10.9706 5.27703 10.7239 4.68358 10.2295 4.25098C9.735 3.80594 9.09195 3.59572 8.30078 3.5957Z"
          fill="#FA8C16"
        />
      </g>
    </svg>
  );
}

export function SuccessIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_141)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM11.9707 5.5293C11.711 5.2696 11.289 5.2696 11.0293 5.5293L7 9.55859L4.9707 7.5293C4.711 7.2696 4.289 7.2696 4.0293 7.5293C3.7696 7.789 3.7696 8.211 4.0293 8.4707L6.5293 10.9707L7 11.4404L7.4707 10.9707L11.9707 6.4707C12.2304 6.211 12.2304 5.789 11.9707 5.5293Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#0DC15B"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_141'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function WaitingIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_115)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C1.88982e-07 3.58172 3.58172 1.88988e-07 8 0ZM8 3.33496C7.63273 3.33496 7.33496 3.63273 7.33496 4V8C7.33496 8.36727 7.63273 8.66504 8 8.66504H12C12.3673 8.66504 12.665 8.36727 12.665 8C12.665 7.63273 12.3673 7.33496 12 7.33496H8.66504V4C8.66504 3.63273 8.36727 3.33496 8 3.33496Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#165DFF"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_115'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function WaitingOrangeIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_107)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C1.88982e-07 3.58172 3.58172 1.88988e-07 8 0ZM8 3.33496C7.63273 3.33496 7.33496 3.63273 7.33496 4V8C7.33496 8.36727 7.63273 8.66504 8 8.66504H12C12.3673 8.66504 12.665 8.36727 12.665 8C12.665 7.63273 12.3673 7.33496 12 7.33496H8.66504V4C8.66504 3.63273 8.36727 3.33496 8 3.33496Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#FA8C16"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_107'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function WarningIcon({
  size,
  width = size ?? '16',
  height = size ?? '16',
  ...props
}: SVGProps<SVGSVGElement> & { size?: number | string }) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      viewBox="0 0 16 16"
      fill="none"
      width={width}
      height={height}
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_119)`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM8 11.335C7.63273 11.335 7.33496 11.6327 7.33496 12C7.33496 12.3673 7.63273 12.665 8 12.665C8.36726 12.665 8.66504 12.3673 8.66504 12C8.66504 11.6327 8.36727 11.335 8 11.335ZM8 3.33496C7.63273 3.33496 7.33496 3.63273 7.33496 4V9.5C7.33496 9.86727 7.63273 10.165 8 10.165C8.36727 10.165 8.66504 9.86727 8.66504 9.5V4C8.66504 3.63273 8.36727 3.33496 8 3.33496Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#FA8C16"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_119'}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export const alertStatusIcons = {
  done: DoneIcon,
  error: ErrorIcon,
  loading: LoadingIcon,
  question: QuestionIcon,
  questionOrange: QuestionOrangeIcon,
  success: SuccessIcon,
  waiting: WaitingIcon,
  waitingOrange: WaitingOrangeIcon,
  warning: WarningIcon,
};

export const alertIcons = {
  ...alertStatusIcons,
  close: CloseIcon,
  closeNormal: CloseNormalIcon,
};
