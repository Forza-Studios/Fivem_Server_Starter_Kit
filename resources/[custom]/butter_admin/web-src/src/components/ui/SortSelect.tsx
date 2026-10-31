import { ArrowDownUp } from 'lucide-react';
import { Select, SelectOption } from './Select';

interface SortSelectProps<T extends string> {
  value: T;
  options: SelectOption<T>[];
  onChange: (value: T) => void;
  className?: string;
}

export const SortSelect = <T extends string>({ value, options, onChange, className }: SortSelectProps<T>) => (
  <Select
    value={value}
    options={options}
    onChange={onChange}
    className={className}
    icon={<ArrowDownUp size={14} className="shrink-0 text-white/30" />}
    triggerClassName="bg-black/30 border border-white/5 hover:border-white/10 focus:border-accent/40 rounded-lg py-2.5 px-2.5 text-sm text-white/80 whitespace-nowrap"
  />
);
