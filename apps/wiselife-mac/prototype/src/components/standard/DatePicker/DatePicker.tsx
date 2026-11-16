import { forwardRef, useState, type ForwardedRef, type ReactElement } from 'react';
import cx from 'clsx';
import dayjs from 'dayjs';
import { Paper, NativeSelect, ActionIcon, Button } from '@mantine/core';
import { DatePicker as MantineDatePicker, DatesProvider, useDatesContext, type DatePickerProps as MantineDatePickerProps, type DatePickerType, type DatePickerStylesNames } from '@mantine/dates';
import { ChevronDown, ChevronLeft, ChevronRight } from './icons.js';

type PickerValue<Type extends DatePickerType> = Parameters<NonNullable<MantineDatePickerProps<Type>['onChange']>>[0];
export interface DatePickerProps<Type extends DatePickerType = 'default'> extends Omit<MantineDatePickerProps<Type>, 'size' | 'numberOfColumns' | 'maxLevel' | 'minLevel' | 'level' | 'defaultLevel' | 'onLevelChange'> {
  /** 日期1带今天按钮，日期2无底部；区间默认显示今天与确定。 */
  withFooter?: boolean;
  onConfirm?: (value: PickerValue<Type>) => void;
}

export function resolveDatePickerClassNames(overrides: Partial<Record<DatePickerStylesNames, string>> = {}) {
  return {
    ...overrides,
    calendarHeader: cx('hidden', overrides.calendarHeader),
    levelsGroup: cx('gap-0', overrides.levelsGroup),
    month: cx('block w-[280px] border-collapse', overrides.month),
    monthThead: cx('block', overrides.monthThead),
    monthTbody: cx('block', overrides.monthTbody),
    weekdaysRow: cx('flex h-[30px] items-center justify-between px-[16px]', overrides.weekdaysRow),
    weekday: cx('flex h-[24px] w-[24px] items-center justify-center p-0 text-[14px] font-normal leading-[22px] text-black/[0.4]', overrides.weekday),
    monthRow: cx('flex h-[30px] items-center justify-between px-[16px]', overrides.monthRow),
    monthCell: cx('relative h-[24px] w-[24px] p-0 before:pointer-events-none before:absolute before:-inset-x-[8px] before:inset-y-0 has-[[data-in-range]]:before:bg-[#f3f7ff] has-[[data-first-in-range]]:before:start-[12px] has-[[data-last-in-range]]:before:end-[12px] has-[[data-first-in-range][data-last-in-range]]:before:hidden', overrides.monthCell),
    day: cx('relative z-[1] h-[24px] w-[24px] rounded-[3px] border-0 bg-transparent p-0 text-[14px] font-normal leading-[22px] text-black opacity-100 hover:bg-transparent hover:shadow-[inset_0_0_0_1px_#165dff] data-[outside]:text-[#bfbfbf] data-[outside]:opacity-100 [&[data-today]:not([data-selected]):not([data-in-range])]:bg-[#f3f7ff] [&[data-today]:not([data-selected]):not([data-in-range])]:text-[#0052d9] data-[in-range]:rounded-[3px] data-[in-range]:bg-transparent data-[in-range]:text-black data-[selected]:rounded-[3px] data-[selected]:bg-[#165dff] data-[selected]:text-white data-[selected]:hover:bg-[#165dff] data-[disabled]:cursor-not-allowed data-[disabled]:bg-[#f2f3f5] data-[disabled]:text-[#bfbfbf] data-[disabled]:opacity-100 data-[disabled]:shadow-[inset_0_0_0_1px_#e5e6eb] data-[disabled]:hover:shadow-[inset_0_0_0_1px_#e5e6eb]', overrides.day),
  };
}
const selectClasses = {
  root: 'w-[80px]',
  input: 'h-[30px] min-h-0 border border-solid border-black/[0.08] bg-white py-0 ps-[8px] pe-[24px] text-[14px] leading-[22px] text-[#262626] focus:border-[#165dff]',
  section: 'w-[24px] text-[#262626]',
};
const arrowClasses = { root: 'h-[24px] min-h-0 w-[24px] min-w-0 border-0 bg-transparent p-0 text-[#262626] hover:bg-[#f2f3f5] disabled:bg-transparent disabled:opacity-40' };
const footerClasses = {
  root: 'h-[24px] min-h-0 border border-solid border-black/[0.08] bg-white px-[8px] py-0 text-[12px] font-normal leading-[18px] text-[#262626] hover:bg-[#f2f3f5]',
  label: 'font-normal',
};
function DatePickerInner<Type extends DatePickerType = 'default'>(
  { type = 'default' as Type, value, defaultValue, onChange, date, defaultDate, onDateChange, withFooter = type === 'range', onConfirm, classNames, minDate, maxDate, excludeDate, locale, firstDayOfWeek = 0, weekdayFormat = 'dd', ...props }: DatePickerProps<Type>,
  ref: ForwardedRef<HTMLDivElement>,
) {
  const ctx = useDatesContext();
  const [local, setLocal] = useState<PickerValue<Type>>(() => (defaultValue ?? (type === 'range' ? [null, null] : type === 'multiple' ? [] : null)) as PickerValue<Type>);
  const raw = value !== undefined ? value : local;
  const current = (Array.isArray(raw) ? raw.map(item => item ? dayjs(item).format('YYYY-MM-DD') : null) : raw ? dayjs(raw as string | Date).format('YYYY-MM-DD') : null) as PickerValue<Type>;
  const initial: string | null = Array.isArray(current) ? current[0] : typeof current === 'string' ? current : null;
  const [localDate, setLocalDate] = useState(() => dayjs(defaultDate ?? initial ?? new Date()).startOf('month').format('YYYY-MM-DD'));
  const displayed = dayjs(date ?? localDate).startOf('month');
  const columns = type === 'range' ? 2 : 1;
  const changeMonth = (next: string) => { setLocalDate(next); onDateChange?.(next); };
  const change = (next: PickerValue<Type>) => { setLocal(next); onChange?.(next as Parameters<NonNullable<typeof onChange>>[0]); };
  const today = dayjs().format('YYYY-MM-DD');
  const todayDisabled = (minDate && dayjs(today).isBefore(minDate, 'day')) || (maxDate && dayjs(today).isAfter(maxDate, 'day')) || excludeDate?.(today);
  const years = Array.from({ length: (maxDate ? dayjs(maxDate).year() : Math.max(displayed.year() + 100, dayjs().year() + 100)) - (minDate ? dayjs(minDate).year() : Math.min(1900, displayed.year())) + 1 }, (_, index) => String(index + (minDate ? dayjs(minDate).year() : Math.min(1900, displayed.year()))));
  return (
    <Paper ref={ref} radius={8} classNames={{root: cx('w-fit bg-white font-normal text-[#262626] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08),0_8px_16px_rgba(0,0,0,0.1)] [font-family:PingFang_SC,sans-serif] tracking-[0px]')}}>
      <div className="flex">
        {Array.from({length: columns}, (_, index) => {
          const month = displayed.add(index, 'month');
          const previousDisabled = Boolean(minDate && displayed.subtract(1, 'month').endOf('month').isBefore(minDate, 'day'));
          const nextDisabled = Boolean(maxDate && displayed.add(columns, 'month').startOf('month').isAfter(maxDate, 'day'));
          return <div key={index} className="flex h-[42px] w-[280px] items-center justify-between px-[12px] pt-[12px]">
            <div className="flex gap-[8px]">
              <NativeSelect aria-label={`第${index + 1}个月年份`} radius={6} value={String(month.year())} data={years} rightSection={<ChevronDown />} classNames={selectClasses} onChange={event => changeMonth(month.year(Number(event.currentTarget.value)).subtract(index, 'month').format('YYYY-MM-DD'))} />
              <NativeSelect aria-label={`第${index + 1}个月月份`} radius={6} value={String(month.month() + 1)} data={Array.from({length:12}, (_, i) => String(i + 1))} rightSection={<ChevronDown />} classNames={selectClasses} onChange={event => changeMonth(month.month(Number(event.currentTarget.value) - 1).subtract(index, 'month').format('YYYY-MM-DD'))} />
            </div>
            <div className="flex">
              <ActionIcon aria-label={`第${index + 1}个月上个月`} radius={6} disabled={previousDisabled} classNames={arrowClasses} onClick={() => changeMonth(displayed.subtract(1, 'month').format('YYYY-MM-DD'))}><ChevronLeft /></ActionIcon>
              <ActionIcon aria-label={`第${index + 1}个月下个月`} radius={6} disabled={nextDisabled} classNames={arrowClasses} onClick={() => changeMonth(displayed.add(1, 'month').format('YYYY-MM-DD'))}><ChevronRight /></ActionIcon>
            </div>
          </div>;
        })}
      </div>
      <div className={cx('pt-[12px]', !withFooter && 'pb-[12px]')}>
        <DatesProvider settings={{...ctx, consistentWeeks: true}}>
          <MantineDatePicker<Type>
            {...props} type={type} value={current as MantineDatePickerProps<Type>['value']} onChange={change}
            date={displayed.format('YYYY-MM-DD')} onDateChange={changeMonth}
            numberOfColumns={columns} columnsToScroll={1} maxLevel="month"
            firstDayOfWeek={firstDayOfWeek} weekdayFormat={weekdayFormat} locale={locale ?? ctx.locale}
            minDate={minDate} maxDate={maxDate} excludeDate={excludeDate} hideOutsideDates={props.hideOutsideDates ?? false} withCellSpacing={false}
            classNames={(theme, values, context) => resolveDatePickerClassNames(typeof classNames === 'function' ? classNames(theme, values, context) : classNames)}
          />
        </DatesProvider>
      </div>
      {withFooter && <div className={cx('flex h-[48px] items-start justify-end gap-[10px] px-[16px] pt-[8px] pb-[16px]')}>
        <Button radius={4} disabled={Boolean(todayDisabled)} fullWidth={type !== 'range'} classNames={footerClasses} onClick={() => {change((type === 'range' ? [today, today] : type === 'multiple' ? [today] : today) as PickerValue<Type>); changeMonth(dayjs().startOf('month').format('YYYY-MM-DD'));}}>今天</Button>
        {type === 'range' && <Button radius={4} disabled={!Array.isArray(current) || !current[0] || !current[1]} classNames={{root:'h-[24px] min-h-0 border-0 bg-[#165dff] px-[8px] py-0 text-[12px] font-normal leading-[18px] text-white hover:bg-[#165dff] disabled:bg-[#f2f3f5] disabled:text-[#bfbfbf]',label:'font-normal'}} onClick={() => onConfirm?.(current as PickerValue<Type>)}>确定</Button>}
      </div>}
    </Paper>
  );
}
export const DatePicker = forwardRef(DatePickerInner) as <Type extends DatePickerType = 'default'>(props: DatePickerProps<Type> & {ref?: ForwardedRef<HTMLDivElement>}) => ReactElement;
