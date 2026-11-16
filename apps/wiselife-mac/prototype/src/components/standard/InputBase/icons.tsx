import {useId, type SVGProps} from 'react';
export function SearchIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      aria-hidden="true"
      preserveAspectRatio="none"
      overflow="visible"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <g>
        <path
          d="M12.002 7.33301C12.0018 4.75491 9.91115 2.66504 7.33301 2.66504C4.75502 2.66522 2.66522 4.75502 2.66504 7.33301C2.66504 9.91115 4.75491 12.0018 7.33301 12.002C9.91126 12.002 12.002 9.91126 12.002 7.33301ZM13.332 7.33301C13.332 8.74975 12.8389 10.0508 12.0176 11.0771L14.4707 13.5293C14.7303 13.7889 14.73 14.21 14.4707 14.4697C14.211 14.7294 13.79 14.7294 13.5303 14.4697L11.0771 12.0176C10.0508 12.8389 8.74975 13.332 7.33301 13.332C4.02037 13.3319 1.33496 10.6457 1.33496 7.33301C1.33514 4.02048 4.02048 1.33514 7.33301 1.33496C10.6457 1.33496 13.3319 4.02037 13.332 7.33301Z"
          fill="currentColor"
        />
      </g>
    </svg>
  );
}
export function ClearIcon(props: SVGProps<SVGSVGElement>) {
  const clipId=useId();
  return (
    <svg
      aria-hidden="true"
      preserveAspectRatio="none"
      overflow="visible"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <g clipPath={`url(#${clipId})`}>
        <path
          d="M8 0C12.4183 0 16 3.58172 16 8C16 12.4183 12.4183 16 8 16C3.58172 16 0 12.4183 0 8C0 3.58172 3.58172 0 8 0ZM10.9707 5.0293C10.711 4.7696 10.289 4.7696 10.0293 5.0293L8 7.05859L5.9707 5.0293C5.711 4.7696 5.289 4.7696 5.0293 5.0293C4.7696 5.289 4.7696 5.711 5.0293 5.9707L7.05859 8L5.0293 10.0293C4.7696 10.289 4.7696 10.711 5.0293 10.9707C5.289 11.2304 5.711 11.2304 5.9707 10.9707L8 8.94141L10.0293 10.9707C10.289 11.2304 10.711 11.2304 10.9707 10.9707C11.2304 10.711 11.2304 10.289 10.9707 10.0293L8.94141 8L10.9707 5.9707C11.2304 5.711 11.2304 5.289 10.9707 5.0293Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#BFBFBF"
        />
      </g>
      <defs>
        <clipPath id={clipId}>
          <rect width="16" height="16" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}
