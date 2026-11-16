import { useId, type SVGProps } from 'react';
export function ModalCloseIcon(props: SVGProps<SVGSVGElement>) {
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
      focusable="false"
      {...props}
    >
      <g>
        <path
          d="M13.0296 2.02974C13.2893 1.77005 13.7113 1.77005 13.971 2.02974C14.2303 2.28947 14.2306 2.71157 13.971 2.97115L8.94169 8.00045L13.971 13.0297C14.2303 13.2895 14.2306 13.7116 13.971 13.9711C13.7114 14.2307 13.2893 14.2305 13.0296 13.9711L8.00028 8.94185L2.97099 13.9711C2.7114 14.2307 2.28929 14.2305 2.02958 13.9711C1.7699 13.7115 1.76994 13.2894 2.02958 13.0297L7.05888 8.00045L2.02958 2.97115C1.7699 2.71147 1.76994 2.28945 2.02958 2.02974C2.28928 1.77005 2.71129 1.77005 2.97099 2.02974L8.00028 7.05904L13.0296 2.02974Z"
          fill="#262626"
        />
      </g>
    </svg>
  );
}

export function ModalErrorIcon(props: SVGProps<SVGSVGElement>) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_235)`}>
        <path
          d="M12 0C18.6274 0 24 5.37258 24 12C24 18.6274 18.6274 24 12 24C5.37258 24 0 18.6274 0 12C0 5.37258 5.37258 0 12 0ZM16.4561 7.54395C16.0665 7.1544 15.4335 7.1544 15.0439 7.54395L12 10.5879L8.95605 7.54395C8.56651 7.1544 7.93349 7.1544 7.54395 7.54395C7.1544 7.93349 7.1544 8.56651 7.54395 8.95605L10.5879 12L7.54395 15.0439C7.1544 15.4335 7.1544 16.0665 7.54395 16.4561C7.93349 16.8456 8.56651 16.8456 8.95605 16.4561L12 13.4121L15.0439 16.4561C15.4335 16.8456 16.0665 16.8456 16.4561 16.4561C16.8456 16.0665 16.8456 15.4335 16.4561 15.0439L13.4121 12L16.4561 8.95605C16.8456 8.56651 16.8456 7.93349 16.4561 7.54395Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#F53F3F"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_235'}>
          <rect width="24" height="24" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function ModalSuccessIcon(props: SVGProps<SVGSVGElement>) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_295)`}>
        <path
          d="M12 0C18.6274 0 24 5.37258 24 12C24 18.6274 18.6274 24 12 24C5.37258 24 0 18.6274 0 12C0 5.37258 5.37258 0 12 0ZM17.9561 8.29395C17.5665 7.9044 16.9335 7.9044 16.5439 8.29395L10.5 14.3379L7.45605 11.2939C7.06651 10.9044 6.43349 10.9044 6.04395 11.2939C5.6544 11.6835 5.6544 12.3165 6.04395 12.7061L9.79395 16.4561L10.5 17.1606L11.2061 16.4561L17.9561 9.70605C18.3456 9.31651 18.3456 8.68349 17.9561 8.29395Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#00D58A"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_295'}>
          <rect width="24" height="24" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function ModalWarningIcon(props: SVGProps<SVGSVGElement>) {
  const id = useId();
  return (
    <svg
      preserveAspectRatio="none"
      overflow="visible"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <g clipPath={`url(#${id}-clip0_0_315)`}>
        <path
          d="M12 0C18.6274 0 24 5.37258 24 12C24 18.6274 18.6274 24 12 24C5.37258 24 0 18.6274 0 12C0 5.37258 5.37258 0 12 0ZM12 17.0024C11.4491 17.0024 11.0024 17.4491 11.0024 18C11.0024 18.5509 11.4491 18.9976 12 18.9976C12.5509 18.9975 12.9976 18.5509 12.9976 18C12.9976 17.4491 12.5509 17.0024 12 17.0024ZM12 5.00244C11.4491 5.00245 11.0024 5.4491 11.0024 6V14.25C11.0024 14.8009 11.4491 15.2476 12 15.2476C12.5509 15.2476 12.9976 14.8009 12.9976 14.25V6C12.9976 5.4491 12.5509 5.00244 12 5.00244Z"
          fillRule="evenodd"
          clipRule="evenodd"
          fill="#FA8C16"
        />
      </g>
      <defs>
        <clipPath id={id + '-clip0_0_315'}>
          <rect width="24" height="24" fill="white" />
        </clipPath>
      </defs>
    </svg>
  );
}

export function ModalEditIcon(props: SVGProps<SVGSVGElement>) {
  const id = useId();
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
      focusable="false"
      {...props}
    >
      <g>
        <g>
          <path
            d="M14.5826 4.41504C14.5826 4.85667 14.4076 5.2805 14.0953 5.59277L6.0885 13.5996C5.90016 13.7879 5.66747 13.9265 5.41174 14.001L3.49768 14.5596C3.39729 14.5889 3.29039 14.5904 3.18909 14.5645C3.08792 14.5385 2.9954 14.4859 2.92151 14.4121C2.84757 14.3382 2.79512 14.2449 2.76917 14.1436C2.74329 14.0424 2.74482 13.9362 2.77405 13.8359L3.33264 11.9209C3.40722 11.6656 3.54493 11.4332 3.73303 11.2451L11.7408 3.2373C12.053 2.92534 12.4763 2.75009 12.9176 2.75C13.3591 2.75 13.7831 2.92517 14.0953 3.2373C14.4076 3.54955 14.5826 3.97345 14.5826 4.41504Z"
            fill={`url(#${id}-paint0_linear_0_303)`}
          />
          <path
            d="M13.9998 12.6681L14.1336 12.6818C14.4368 12.7437 14.6649 13.0117 14.6649 13.3332C14.6649 13.6546 14.4368 13.9227 14.1336 13.9845L13.9998 13.9982H9.07406C8.70679 13.9982 8.40902 13.7004 8.40902 13.3332C8.40902 12.9659 8.70679 12.6681 9.07406 12.6681H13.9998Z"
            fill={`url(#${id}-paint1_linear_0_303)`}
          />
          <path
            d="M4.24265 6.24973C4.29294 6.27847 4.35402 6.29284 4.42587 6.29284C4.49772 6.29284 4.55879 6.27847 4.60909 6.24973C4.65938 6.22098 4.6989 6.17069 4.72764 6.09884L5.35274 4.63308L6.92628 3.94331C6.99813 3.91457 7.04842 3.87506 7.07716 3.82476C7.1059 3.77446 7.12027 3.71339 7.12027 3.64154C7.12027 3.56969 7.1059 3.50862 7.07716 3.45832C7.04842 3.40802 6.99813 3.36851 6.92628 3.33977L5.35274 2.67155L4.72764 1.27046C4.6989 1.19861 4.65938 1.14832 4.60909 1.11958C4.55879 1.09084 4.49772 1.07646 4.42587 1.07646C4.35402 1.07646 4.29294 1.09084 4.24265 1.11958C4.19235 1.14832 4.15284 1.19861 4.1241 1.27046L3.49899 2.67155L1.92546 3.33977C1.85361 3.36851 1.80331 3.40802 1.77457 3.45832C1.74583 3.50862 1.73146 3.56969 1.73146 3.64154C1.73146 3.71339 1.74583 3.77446 1.77457 3.82476C1.80331 3.87506 1.85361 3.91457 1.92546 3.94331L3.49899 4.63308L4.1241 6.09884C4.15284 6.17069 4.19235 6.22098 4.24265 6.24973Z"
            fill={`url(#${id}-paint2_linear_0_303)`}
          />
        </g>
      </g>
      <defs>
        <linearGradient
          id={id + '-paint0_linear_0_303'}
          x1="8.90395"
          y1="0.21206"
          x2="8.90395"
          y2="14.5828"
          gradientUnits="userSpaceOnUse"
        >
          <stop stopColor="#4318FF" />
          <stop offset="1" stopColor="#165DFF" />
        </linearGradient>
        <linearGradient
          id={id + '-paint1_linear_0_303'}
          x1="8.90395"
          y1="0.21206"
          x2="8.90395"
          y2="14.5828"
          gradientUnits="userSpaceOnUse"
        >
          <stop stopColor="#4318FF" />
          <stop offset="1" stopColor="#165DFF" />
        </linearGradient>
        <linearGradient
          id={id + '-paint2_linear_0_303'}
          x1="8.90395"
          y1="0.21206"
          x2="8.90395"
          y2="14.5828"
          gradientUnits="userSpaceOnUse"
        >
          <stop stopColor="#4318FF" />
          <stop offset="1" stopColor="#165DFF" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function ModalStatusIcon({
  status,
  ...props
}: SVGProps<SVGSVGElement> & { status: 'error' | 'success' | 'warning' | 'edit' }) {
  const Icon = {
    error: ModalErrorIcon,
    success: ModalSuccessIcon,
    warning: ModalWarningIcon,
    edit: ModalEditIcon,
  }[status];
  return <Icon {...props} />;
}
