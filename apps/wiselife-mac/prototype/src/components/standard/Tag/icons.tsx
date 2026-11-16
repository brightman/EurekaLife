import type { SVGProps } from 'react';
export function SearchSmall(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="12"
      height="12"
      viewBox="0 0 12 12"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      {...props}
    >
      <g>
        <path
          d="M9.00146 5.49976C9.00133 3.56618 7.43336 1.99878 5.49976 1.99878C3.56626 1.99891 1.99891 3.56626 1.99878 5.49976C1.99878 7.43336 3.56618 9.00133 5.49976 9.00146C7.43344 9.00146 9.00146 7.43344 9.00146 5.49976ZM9.99902 5.49976C9.99902 6.56231 9.62919 7.53812 9.01318 8.30786L10.853 10.147C11.0477 10.3416 11.0475 10.6575 10.853 10.8523C10.6583 11.0471 10.3425 11.0471 10.1477 10.8523L8.30786 9.01318C7.53812 9.62919 6.56231 9.99902 5.49976 9.99902C3.01528 9.99889 1.00122 7.98427 1.00122 5.49976C1.00135 3.01536 3.01536 1.00135 5.49976 1.00122C7.98426 1.00122 9.99889 3.01528 9.99902 5.49976Z"
          fill="white"
        />
      </g>
    </svg>
  );
}
export function SearchLarge(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      {...props}
    >
      <g>
        <path
          d="M12.002 7.33301C12.0018 4.75491 9.91115 2.66504 7.33301 2.66504C4.75502 2.66522 2.66522 4.75502 2.66504 7.33301C2.66504 9.91115 4.75491 12.0018 7.33301 12.002C9.91126 12.002 12.002 9.91126 12.002 7.33301ZM13.332 7.33301C13.332 8.74975 12.8389 10.0508 12.0176 11.0771L14.4707 13.5293C14.7303 13.7889 14.73 14.21 14.4707 14.4697C14.211 14.7294 13.79 14.7294 13.5303 14.4697L11.0771 12.0176C10.0508 12.8389 8.74975 13.332 7.33301 13.332C4.02037 13.3319 1.33496 10.6457 1.33496 7.33301C1.33514 4.02048 4.02048 1.33514 7.33301 1.33496C10.6457 1.33496 13.3319 4.02037 13.332 7.33301Z"
          fill="white"
        />
      </g>
    </svg>
  );
}
export function CloseVector(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="6.33074"
      height="6.33074"
      viewBox="0 0 6.33074 6.33074"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      {...props}
    >
      <path
        d="M5.19464 0.194563C5.45427 -0.0648887 5.87638 -0.0648198 6.13605 0.194563C6.3957 0.454208 6.39559 0.876257 6.13605 1.13597L4.10675 3.16527L6.13605 5.19456C6.3957 5.45421 6.39559 5.87626 6.13605 6.13597C5.87635 6.39567 5.45434 6.39567 5.19464 6.13597L3.16535 4.10667L1.13605 6.13597C0.87635 6.39567 0.454341 6.39567 0.194642 6.13597C-0.0647931 5.87625 -0.0649685 5.45417 0.194642 5.19456L2.22394 3.16527L0.194642 1.13597C-0.0647928 0.876248 -0.0649684 0.454174 0.194642 0.194563C0.454267 -0.0648888 0.876381 -0.0648196 1.13605 0.194563L3.16535 2.22386L5.19464 0.194563Z"
        fill="white"
      />
    </svg>
  );
}
export function TagSearchIcon({ size = 'md' }: { size?: 'lg' | 'md' | 'sm' }) {
  return size === 'lg' ? <SearchLarge /> : <SearchSmall />;
}
export function TagCloseIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true" {...props}>
      <g transform="translate(4.834526538848877 4.834324836730957)">
        <CloseVector />
      </g>
    </svg>
  );
}
