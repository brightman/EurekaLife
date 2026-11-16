import { forwardRef, type ReactNode } from 'react';
import cx from 'clsx';
import { Select as MantineSelect, type SelectProps as MantineSelectProps, type SelectStylesNames } from '@mantine/core';
import { ChevronDown, CheckIcon } from './icons.js';

export type SelectSize = 'lg' | 'md' | 'sm';
export type SelectAppearance = 'filled' | 'outlined';
export type SelectMenuTone = 'blue' | 'dark' | 'neutral';
export interface SelectProps extends MantineSelectProps {
  size?: SelectSize;
  appearance?: SelectAppearance;
  menuTone?: SelectMenuTone;
  optionIcon?: ReactNode;
}
interface VisualOptions {
  size?: SelectSize;
  appearance?: SelectAppearance;
  menuTone?: SelectMenuTone;
  hasLeftSection?: boolean;
}
const sizes = {
  lg: { input:'pe-[44px] text-[16px] leading-[24px]', noIconInput:'h-[48px] ps-[16px]', iconInput:'h-[44px] ps-[44px]', option:'h-[48px] px-[12px] text-[16px] leading-[24px]', dropdown:'p-[8px] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08),0_8px_16px_rgba(0,0,0,0.1)]', radius:8, section:48 },
  md: { input:'h-[40px] pe-[36px] text-[14px] leading-[22px]', noIconInput:'ps-[12px]', iconInput:'ps-[36px]', option:'h-[40px] px-[8px] text-[14px] leading-[22px]', dropdown:'p-[8px] shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08),0_8px_16px_rgba(0,0,0,0.1)]', radius:8, section:40 },
  sm: { input:'h-[32px] pe-[32px] text-[14px] leading-[22px]', noIconInput:'ps-[8px]', iconInput:'ps-[32px]', option:'h-[32px] px-[8px] text-[14px] leading-[22px]', dropdown:'p-[6px] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.08),0_8px_16px_rgba(0,0,0,0.1)]', radius:6, section:32 },
};
const appearances = {
  filled:'bg-[#f2f3f5] enabled:hover:bg-[#e5e6eb] enabled:focus:bg-white enabled:focus:shadow-[inset_0_0_0_1px_#165dff] data-[expanded]:bg-white data-[expanded]:shadow-[inset_0_0_0_1px_#165dff]',
  outlined:'bg-white shadow-[inset_0_0_0_1px_rgba(0,0,0,0.08)] enabled:hover:shadow-[inset_0_0_0_1px_rgba(0,0,0,0.12)] enabled:focus:shadow-[inset_0_0_0_1px_#165dff] data-[expanded]:shadow-[inset_0_0_0_1px_#165dff]',
};
const tones = {
  blue:'hover:bg-[#165dff]/[0.05] data-[checked]:bg-[#165dff]/[0.05] data-[combobox-selected]:bg-[#165dff]/[0.05]',
  dark:'hover:bg-black/[0.03] data-[checked]:bg-black/[0.03] data-[combobox-selected]:bg-black/[0.03]',
  neutral:'hover:bg-black/[0.03] data-[checked]:bg-white data-[combobox-selected]:bg-black/[0.03]',
};
export function resolveSelectProps({size='md',leftSection,appearance: _appearance,menuTone: _menuTone,optionIcon: _optionIcon,...props}: SelectProps = {}): SelectProps {
  return { size, radius:sizes[size].radius, w:280, maw:'100%', leftSectionWidth:sizes[size].section, rightSectionWidth:sizes[size].section, rightSectionPointerEvents:'none', placeholder:'请选择', withScrollArea:false, ...props, leftSection };
}
export function resolveSelectClassNames({size='md',appearance='filled',menuTone='blue',hasLeftSection=false}: VisualOptions = {}, overrides: Partial<Record<SelectStylesNames,string>> = {}) {
  return {
    ...overrides,
    root:cx('group/select min-w-0 [font-family:PingFang_SC,sans-serif] tracking-[0px]',overrides.root),
    input:cx('min-h-0 border-0 py-0 font-normal text-[#262626] placeholder:text-[#262626] disabled:cursor-not-allowed disabled:text-[#bfbfbf] disabled:placeholder:text-[#bfbfbf] disabled:opacity-100 data-[error]:text-[#ff4d4f] data-[error]:shadow-[inset_0_0_0_1px_#ff4d4f]',sizes[size].input,hasLeftSection ? sizes[size].iconInput : sizes[size].noIconInput,appearances[appearance],overrides.input),
    section:cx('text-[#262626] group-has-[[disabled]]/select:text-[#bfbfbf] data-[position=right]:end-0 data-[position=left]:start-0',overrides.section),
    dropdown:cx('rounded-[8px] border-0 bg-white text-[#262626] [font-family:PingFang_SC,sans-serif] tracking-[0px]',sizes[size].dropdown,overrides.dropdown),
    options:cx('p-0',overrides.options),
    option:cx('flex items-center gap-[8px] rounded-[4px] border-0 bg-white py-0 font-normal text-[#262626] data-[combobox-selected]:text-[#262626] data-[combobox-disabled]:cursor-not-allowed data-[combobox-disabled]:bg-white data-[combobox-disabled]:text-[#bfbfbf] data-[combobox-disabled]:opacity-100',sizes[size].option,tones[menuTone],overrides.option),
    empty:cx('px-[8px] py-[12px] text-[14px] leading-[22px] text-[#8c8c8c]',overrides.empty),
  };
}
export function SelectChevron() {
  return <span aria-hidden="true" className="flex h-[16px] w-[16px] group-has-[[data-expanded]]/select:-scale-y-100"><ChevronDown /></span>;
}
export function SelectOptionContent({icon, label, checked, withCheckIcon}: {icon?:ReactNode; label:string; checked:boolean; withCheckIcon:boolean}) {
  return <>{icon && <span aria-hidden="true" className="flex h-[16px] w-[16px] shrink-0">{icon}</span>}<span className="min-w-0 flex-1 truncate">{label}</span>{checked && withCheckIcon && <span className="flex h-[16px] w-[16px] shrink-0"><CheckIcon /></span>}</>;
}
export const Select = forwardRef<HTMLInputElement, SelectProps>(
  ({size='md',appearance='filled',menuTone='blue',optionIcon,classNames,rightSection,renderOption,withCheckIcon=Boolean(optionIcon),comboboxProps,...props},ref) => (
    <MantineSelect
      ref={ref}
      {...resolveSelectProps({size,...props})}
      withCheckIcon={withCheckIcon}
      comboboxProps={{offset:4,...comboboxProps}}
      rightSection={rightSection === undefined ? <SelectChevron /> : rightSection}
      renderOption={renderOption ?? (({option,checked}) => <SelectOptionContent icon={optionIcon} label={option.label} checked={Boolean(checked)} withCheckIcon={withCheckIcon} />)}
      classNames={(theme,values,context)=>resolveSelectClassNames({size,appearance,menuTone,hasLeftSection:Boolean(props.leftSection)},typeof classNames==='function'?classNames(theme,values,context):classNames)}
    />
  ),
);
Select.displayName = 'SWorks/Select';
