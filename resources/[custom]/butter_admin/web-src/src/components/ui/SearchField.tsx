import React from 'react';
import { Search, X } from 'lucide-react';
import { cn } from '../../utils/cn';

interface SearchFieldProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
  autoFocus?: boolean;
}

export const SearchField: React.FC<SearchFieldProps> = ({ value, onChange, placeholder, className, autoFocus }) => (
  <div className={cn('relative', className)}>
    <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 pointer-events-none" />
    <input
      type="text"
      value={value}
      autoFocus={autoFocus}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === 'Escape' && value) {
          e.stopPropagation();
          onChange('');
        }
      }}
      className="w-full bg-black/30 border border-white/5 hover:border-white/10 focus:border-accent/40 rounded-lg py-2.5 pl-9 pr-8 text-sm text-white placeholder:text-white/40 outline-none transition-colors font-barlow"
    />
    {value && (
      <button
        onClick={() => onChange('')}
        className="absolute right-2.5 top-1/2 -translate-y-1/2 text-white/30 hover:text-white transition-colors"
      >
        <X size={14} />
      </button>
    )}
  </div>
);
