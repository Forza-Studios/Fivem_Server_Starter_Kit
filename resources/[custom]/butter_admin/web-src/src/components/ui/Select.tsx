import { ReactNode, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Check, ChevronDown } from 'lucide-react';
import { cn } from '../../utils/cn';

export interface SelectOption<T extends string> {
  id: T;
  label: string;
}

interface SelectProps<T extends string> {
  value: T;
  options: SelectOption<T>[];
  onChange: (value: T) => void;
  icon?: ReactNode;
  className?: string;
  /** Trigger appearance (background, border, padding, text). */
  triggerClassName?: string;
}

const DEFAULT_TRIGGER =
  'bg-black/20 border border-border/60 rounded-md px-3 py-2.5 text-base text-primary focus:border-accent/60';

/** Returns the nearest ancestor that clips its overflow, so the menu can flip when it lacks room below. */
const getClippingRect = (el: HTMLElement) => {
  for (let node = el.parentElement; node; node = node.parentElement) {
    if (/(auto|scroll|hidden)/.test(getComputedStyle(node).overflowY)) return node.getBoundingClientRect();
  }
  return { top: 0, bottom: window.innerHeight };
};

export const Select = <T extends string>({
  value,
  options,
  onChange,
  icon,
  className,
  triggerClassName = DEFAULT_TRIGGER,
}: SelectProps<T>) => {
  const [open, setOpen] = useState(false);
  const [dropUp, setDropUp] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const selected = options.find((option) => option.id === value);

  useEffect(() => {
    if (!open) return;

    const handleMouseDown = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };

    document.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handleMouseDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [open]);

  useLayoutEffect(() => {
    if (!open || !rootRef.current || !menuRef.current) return;

    const trigger = rootRef.current.getBoundingClientRect();
    const bounds = getClippingRect(rootRef.current);
    const menuHeight = menuRef.current.offsetHeight;
    const spaceBelow = bounds.bottom - trigger.bottom;
    const spaceAbove = trigger.top - bounds.top;
    setDropUp(spaceBelow < menuHeight && spaceAbove > spaceBelow);

    menuRef.current.querySelector('[data-active="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [open]);

  return (
    <div ref={rootRef} className={cn('relative shrink-0', className)}>
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        className={cn(
          'w-full flex items-center gap-2 text-left outline-none cursor-pointer transition-colors font-barlow',
          triggerClassName,
        )}
      >
        {icon}
        <span className="flex-1 truncate">{selected?.label}</span>
        <ChevronDown
          size={14}
          className={cn('shrink-0 text-white/30 transition-transform duration-150', open && 'rotate-180')}
        />
      </button>

      {open && (
        <div
          ref={menuRef}
          className={cn(
            'absolute right-0 z-50 min-w-full max-h-60 overflow-y-auto custom-scrollbar p-1 bg-bg-primary border border-white/10 rounded-lg shadow-xl shadow-black/40 animate-in fade-in zoom-in-95 duration-100',
            dropUp ? 'bottom-full mb-1.5 origin-bottom-right' : 'top-full mt-1.5 origin-top-right',
          )}
        >
          {options.map((option) => {
            const isActive = option.id === value;
            return (
              <button
                key={option.id}
                type="button"
                data-active={isActive}
                onClick={() => {
                  onChange(option.id);
                  setOpen(false);
                }}
                className={cn(
                  'w-full flex items-center gap-3 px-2.5 py-1.5 rounded-md text-sm font-barlow text-left whitespace-nowrap transition-colors',
                  isActive ? 'bg-accent/15 text-accent' : 'text-white/70 hover:bg-white/5 hover:text-white',
                )}
              >
                <span className="flex-1">{option.label}</span>
                <Check size={13} className={cn('shrink-0', !isActive && 'invisible')} />
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};
