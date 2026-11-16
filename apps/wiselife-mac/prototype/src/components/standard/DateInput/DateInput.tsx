import { forwardRef, useState, useId } from "react";
import cx from "clsx";
import { Input, type InputWrapperProps } from "@mantine/core";
import {
  DateInput as MantineDateInput,
  type DateInputProps as MantineDateInputProps,
  type DateInputStylesNames,
} from "@mantine/dates";
import { Calendar, CalendarFocus, CalendarDisabled, CalendarMini, CalendarMiniFocus, CalendarMiniDisabled } from "./icons.js";
export type DateInputSize = "sm" | "md";
export type DateInputAppearance = "filled" | "outlined";
export interface DateInputProps extends MantineDateInputProps {
  size?: DateInputSize;
  appearance?: DateInputAppearance;
}
interface VisualOptions {
  size?: DateInputSize;
  appearance?: DateInputAppearance;
  disabled?: boolean;
}
const sizeClasses = {
  md: {
    input: "px-[8px] pr-[32px] text-[14px] leading-[22px]",
    height: "h-[40px]",
    radius: 8,
    rangeRadius: "rounded-[8px]",
    rangeWidth: 240,
    section: 32,
  },
  sm: {
    input: "px-[8px] pr-[24px] text-[12px] leading-[18px]",
    height: "h-[32px]",
    radius: 6,
    rangeRadius: "rounded-[6px]",
    rangeWidth: 200,
    section: 28,
  },
};
const appearances = {
  filled:
    "border-0 bg-[#f2f3f5] enabled:hover:bg-[#e5e6eb] enabled:focus:bg-white enabled:focus:shadow-[inset_0_0_0_1px_#165dff]",
  outlined:
    "border border-solid border-black/[0.08] bg-white enabled:hover:border-black/[0.12] enabled:focus:border-[#165dff]",
};
export function resolveDateInputClassNames(
  { size = "md", appearance = "filled" }: VisualOptions = {},
  overrides: Partial<Record<DateInputStylesNames, string>> = {},
) {
  const config = sizeClasses[size];
  return {
    ...overrides,
    root: cx(
      "group/date-input [font-family:PingFang_SC,sans-serif] tracking-[0px]",
      overrides.root,
    ),
    wrapper: overrides.wrapper,
    input: cx(
      "min-h-0 py-0 font-normal text-[#262626] placeholder:text-[#8c8c8c] disabled:cursor-not-allowed disabled:opacity-100 disabled:text-[#bfbfbf] disabled:placeholder:text-[#bfbfbf] data-[error]:border-[#ff4d4f]",
      config.input,
      config.height,
      appearances[appearance],
      overrides.input,
    ),
    section: cx(
      "text-[#262626] data-[position=right]:end-0",
      overrides.section,
    ),
  };
}
export function DateInputCalendarIcon({
  size = "md",
  disabled = false,
}: VisualOptions) {
  const Normal = size === "sm" ? CalendarMini : Calendar;
  const Focus = size === "sm" ? CalendarMiniFocus : CalendarFocus;
  const Disabled = size === "sm" ? CalendarMiniDisabled : CalendarDisabled;
  return (
    <span
      aria-hidden="true"
      className={cx("relative flex items-center justify-center", size === "sm" ? "h-[12px] w-[12px]" : "h-[16px] w-[16px]")}
    >
      {disabled ? (
        <Disabled />
      ) : (
        <>
          <span className="flex group-focus-within/date-input:hidden">
            <Normal />
          </span>
          <span className="hidden group-focus-within/date-input:flex">
            <Focus />
          </span>
        </>
      )}
    </span>
  );
}
const SingleDateInput = forwardRef<HTMLInputElement, DateInputProps>(
  (
    {
      size = "md",
      appearance = "filled",
      value,
      defaultValue,
      onChange,
      classNames,
      rightSection,
      ...props
    },
    ref,
  ) => {
    const visual = {
      size,
      appearance,
      disabled: props.disabled,
    };
    return (
      <MantineDateInput
        ref={ref}
        size={size}
        radius={sizeClasses[size].radius}
        w={220}
        maw="100%"
        valueFormat="YYYY/MM/DD"
        placeholder="日期"
        rightSectionWidth={sizeClasses[size].section}
        rightSectionPointerEvents="none"
        {...props}
        value={value}
        defaultValue={defaultValue}
        onChange={onChange}
        rightSection={
          rightSection === undefined ? (
            <DateInputCalendarIcon {...visual} />
          ) : (
            rightSection
          )
        }
        classNames={(theme, values, ctx) =>
          resolveDateInputClassNames(
            visual,
            typeof classNames === "function"
              ? classNames(theme, values, ctx)
              : classNames,
          )
        }
      />
    );
  },
);
SingleDateInput.displayName = "SWorks/DateInput";
export interface DateInputRangeProps
  extends Omit<
    DateInputProps,
    "value" | "defaultValue" | "onChange" | "ref" | "placeholder" | "classNames"
  > {
  value?: [string | null, string | null];
  defaultValue?: [string | null, string | null];
  onChange?: (value: [string | null, string | null]) => void;
  classNames?: Partial<Record<DateInputStylesNames, string>>;
  startPlaceholder?: string;
  endPlaceholder?: string;
  startLabel?: string;
  endLabel?: string;
}
const rangeSizes = {
  md: "gap-[8px] px-[8px] text-[14px] leading-[22px]",
  sm: "gap-[4px] px-[8px] text-[12px] leading-[18px]",
};
const rangeAppearances = {
  filled:
    "border-0 bg-[#f2f3f5] hover:bg-[#e5e6eb] focus-within:bg-white focus-within:shadow-[inset_0_0_0_1px_#165dff]",
  outlined:
    "border border-solid border-black/[0.08] bg-white hover:border-black/[0.12] focus-within:border-[#165dff]",
};
const disabledRangeAppearances = {
  filled: "border-0 bg-[#f2f3f5]",
  outlined: "border border-solid border-black/[0.08] bg-white",
};
const RangeDateInput = forwardRef<HTMLDivElement, DateInputRangeProps>(
  (
    {
      size = "md",
      appearance = "filled",
      value,
      defaultValue = [null, null],
      onChange,
      label,
      description,
      error,
      required,
      withAsterisk,
      startPlaceholder = "开始日期",
      endPlaceholder = "结束日期",
      startLabel = "开始日期",
      endLabel = "结束日期",
      classNames,
      w,
      maw,
      ...props
    },
    ref,
  ) => {
    const generatedId = useId();
    const inputId = props.id ?? generatedId;
    const [local, setLocal] =
      useState<[string | null, string | null]>(defaultValue);
    const current = value ?? local;
    const config = rangeSizes[size];
    const change = (index: number, next: string | null) => {
      const pair: [string | null, string | null] = [...current];
      pair[index] = next;
      if (pair[0] && pair[1] && pair[0] > pair[1]) {
        if (index === 0) pair[1] = null;
        else pair[0] = null;
      }
      setLocal(pair);
      onChange?.(pair);
    };
    const wrapperProps: InputWrapperProps = {
      label,
      description,
      error,
      required,
      withAsterisk,
    };
    const rangeFont = {
      md: "text-[14px] leading-[22px]",
      sm: "text-[12px] leading-[18px]",
    };
    const nativeClasses = {
      root: "h-full min-w-0 flex-1",
      wrapper: "h-full",
      input:
        "h-full min-h-0 rounded-none border-0 bg-transparent p-0 font-normal text-[#262626] placeholder:text-[#8c8c8c] disabled:bg-transparent disabled:text-[#bfbfbf] disabled:placeholder:text-[#bfbfbf]",
    };
    return (
      <Input.Wrapper
        {...wrapperProps}
        labelElement="div"
        role="group"
        aria-labelledby={label ? inputId + "-label" : undefined}
        ref={ref}
        w={w ?? sizeClasses[size].rangeWidth}
        maw={maw ?? "100%"}
        id={inputId}
        classNames={{
          root: cx(
            "[font-family:PingFang_SC,sans-serif] tracking-[0px]",
            classNames?.root,
          ),
          label: classNames?.label,
          error: classNames?.error,
          description: classNames?.description,
        }}
      >
        <div
          className={cx(
            "group/date-input flex items-center",
            sizeClasses[size].rangeRadius,
            config,
            sizeClasses[size].height,
            props.disabled
              ? disabledRangeAppearances[appearance]
              : rangeAppearances[appearance],
            Boolean(error) && "shadow-[inset_0_0_0_1px_#ff4d4f]",
            classNames?.wrapper,
          )}
        >
          <MantineDateInput
            {...props}
            required={required}
            id={inputId + "-start"}
            name={props.name ? props.name + ".0" : undefined}
            aria-describedby={
              description ? inputId + "-description" : undefined
            }
            label={undefined}
            description={undefined}
            error={Boolean(error)}
            size={size}
            value={current[0]}
            onChange={(next) => change(0, next)}
            aria-label={startLabel}
            placeholder={startPlaceholder}
            valueFormat={props.valueFormat ?? "YYYY/MM/DD"}
            rightSection={null}
            rightSectionWidth={0}
            classNames={{
              ...nativeClasses,
              input: cx(
                nativeClasses.input,
                rangeFont[size],
                classNames?.input,
              ),
            }}
          />
          <span
            aria-hidden="true"
            className={cx(
              "w-[16px] shrink-0 text-center",
              props.disabled ? "text-[#bfbfbf]" : "text-[#8c8c8c]",
            )}
          >
            -
          </span>
          <MantineDateInput
            {...props}
            required={required}
            id={inputId + "-end"}
            name={props.name ? props.name + ".1" : undefined}
            aria-describedby={
              description ? inputId + "-description" : undefined
            }
            label={undefined}
            description={undefined}
            error={Boolean(error)}
            size={size}
            value={current[1]}
            onChange={(next) => change(1, next)}
            aria-label={endLabel}
            placeholder={endPlaceholder}
            valueFormat={props.valueFormat ?? "YYYY/MM/DD"}
            rightSection={null}
            rightSectionWidth={0}
            classNames={{
              ...nativeClasses,
              input: cx(
                nativeClasses.input,
                rangeFont[size],
                classNames?.input,
              ),
            }}
          />
          <span className={cx("shrink-0", classNames?.section)}>
            <DateInputCalendarIcon
              size={size}
              appearance={appearance}
              disabled={props.disabled}
            />
          </span>
        </div>
      </Input.Wrapper>
    );
  },
);
RangeDateInput.displayName = "SWorks/DateInput.Range";
export const DateInput: typeof SingleDateInput & {
  Range: typeof RangeDateInput;
} = Object.assign(SingleDateInput, { Range: RangeDateInput });
