import React from 'react';
import { Loader2, X } from 'lucide-react';
import { cn } from '../../../utils/cn';

// Shared building blocks so every Database tab looks and behaves the same.

export type Tone = 'default' | 'accent' | 'success' | 'warning' | 'danger';

const TONE_TEXT: Record<Tone, string> = {
  default: 'text-primary',
  accent: 'text-accent',
  success: 'text-success',
  warning: 'text-warning',
  danger: 'text-danger',
};

const TONE_BORDER: Record<Tone, string> = {
  default: 'border-border/60',
  accent: 'border-accent/30',
  success: 'border-success/30',
  warning: 'border-warning/30',
  danger: 'border-danger/30',
};

const TONE_DOT: Record<Tone, string> = {
  default: 'bg-muted',
  accent: 'bg-accent',
  success: 'bg-success',
  warning: 'bg-warning',
  danger: 'bg-danger',
};

export const inputClass =
  'w-full bg-black/20 border border-border/60 rounded-md px-3 py-2.5 text-base text-primary placeholder:text-muted/60 outline-none focus:border-accent/60 transition-colors';

export const Panel: React.FC<{ className?: string; children: React.ReactNode }> = ({ className, children }) => (
  <div className={cn('bg-bg-secondary/40 border border-border/60 rounded-lg', className)}>{children}</div>
);

export interface StatItem {
  label: string;
  value: React.ReactNode;
  tone?: Tone;
  hint?: string;
}

export const StatStrip: React.FC<{ items: StatItem[] }> = ({ items }) => (
  <div
    className="grid divide-x divide-border/60 bg-bg-secondary/40 border border-border/60 rounded-lg shrink-0"
    style={{ gridTemplateColumns: `repeat(${items.length}, minmax(0, 1fr))` }}
  >
    {items.map((item) => (
      <div key={item.label} className="px-5 py-3.5 min-w-0">
        <p className="text-sm text-muted truncate">{item.label}</p>
        <p
          className={cn(
            'text-2xl font-semibold tabular-nums leading-tight mt-1 truncate',
            TONE_TEXT[item.tone ?? 'default'],
          )}
        >
          {item.value}
        </p>
        {item.hint && <p className="text-[13px] text-muted/70 truncate">{item.hint}</p>}
      </div>
    ))}
  </div>
);

export interface SegmentOption<T extends string> {
  id: T;
  label: string;
  count?: number;
}

export const Segmented = <T extends string>({
  options,
  value,
  onChange,
  className,
}: {
  options: SegmentOption<T>[];
  value: T;
  onChange: (value: T) => void;
  className?: string;
}) => (
  <div className={cn('inline-flex items-center gap-0.5 p-0.5 rounded-md border border-border/60 bg-black/20', className)}>
    {options.map((option) => (
      <button
        key={option.id}
        onClick={() => onChange(option.id)}
        className={cn(
          'flex-1 px-3 py-1.5 rounded text-sm font-medium whitespace-nowrap transition-colors',
          value === option.id ? 'bg-white/10 text-primary' : 'text-muted hover:text-primary',
        )}
      >
        {option.label}
        {option.count !== undefined && <span className="ml-1.5 text-muted tabular-nums">{option.count}</span>}
      </button>
    ))}
  </div>
);

export const Toolbar: React.FC<{ className?: string; children: React.ReactNode }> = ({ className, children }) => (
  <div className={cn('flex items-center gap-2 flex-wrap shrink-0', className)}>{children}</div>
);

type ButtonVariant = 'default' | 'primary' | 'danger' | 'ghost';

const BUTTON_VARIANTS: Record<ButtonVariant, string> = {
  default: 'bg-white/5 border-border/60 text-primary hover:bg-white/10',
  primary: 'bg-accent border-accent text-white hover:bg-accent/90',
  danger: 'bg-danger/10 border-danger/30 text-danger hover:bg-danger/20',
  ghost: 'bg-transparent border-transparent text-muted hover:text-primary hover:bg-white/5',
};

export const Button: React.FC<
  React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; icon?: React.ReactNode; busy?: boolean }
> = ({ variant = 'default', icon, busy, className, children, disabled, ...props }) => (
  <button
    {...props}
    disabled={disabled || busy}
    className={cn(
      'inline-flex items-center justify-center gap-1.5 px-3.5 py-2 rounded-md border text-sm font-medium transition-colors disabled:opacity-40 disabled:pointer-events-none',
      BUTTON_VARIANTS[variant],
      className,
    )}
  >
    {busy ? <Loader2 size={13} className="animate-spin" /> : icon}
    {children}
  </button>
);

export const IconButton: React.FC<
  React.ButtonHTMLAttributes<HTMLButtonElement> & { tone?: 'default' | 'danger'; spinning?: boolean }
> = ({ tone = 'default', spinning, className, children, ...props }) => (
  <button
    {...props}
    className={cn(
      'p-1.5 rounded-md transition-colors disabled:opacity-40',
      tone === 'danger' ? 'text-muted hover:text-danger hover:bg-danger/10' : 'text-muted hover:text-primary hover:bg-white/10',
      spinning && '[&>svg]:animate-spin',
      className,
    )}
  >
    {children}
  </button>
);

export const StatusDot: React.FC<{ tone: Tone; label?: React.ReactNode; className?: string }> = ({
  tone,
  label,
  className,
}) => (
  <span className={cn('inline-flex items-center gap-1.5 text-sm', className)}>
    <span className={cn('w-2 h-2 rounded-full shrink-0', TONE_DOT[tone])} />
    {label !== undefined && <span className={tone === 'default' ? 'text-muted' : TONE_TEXT[tone]}>{label}</span>}
  </span>
);

export const Badge: React.FC<{ children: React.ReactNode; tone?: Tone; className?: string }> = ({
  children,
  tone = 'default',
  className,
}) => (
  <span
    className={cn(
      'inline-flex items-center px-1.5 py-0.5 rounded border text-[13px] leading-none whitespace-nowrap',
      TONE_BORDER[tone],
      tone === 'default' ? 'text-muted' : TONE_TEXT[tone],
      className,
    )}
  >
    {children}
  </span>
);

/** Thin bar for 0-100 values like fuel or engine health. */
export const Meter: React.FC<{ value: number; className?: string }> = ({ value, className }) => {
  const clamped = Math.max(0, Math.min(100, value));
  const tone = clamped < 25 ? 'bg-danger' : clamped < 60 ? 'bg-warning' : 'bg-success';
  return (
    <span className={cn('flex items-center gap-2 min-w-0', className)}>
      <span className="h-1 flex-1 rounded-full bg-white/10 overflow-hidden">
        <span className={cn('block h-full rounded-full', tone)} style={{ width: `${clamped}%` }} />
      </span>
      <span className="text-sm text-muted tabular-nums w-8 text-right">{Math.round(clamped)}%</span>
    </span>
  );
};

export const EmptyState: React.FC<{ icon?: React.ReactNode; title: string; hint?: string; className?: string }> = ({
  icon,
  title,
  hint,
  className,
}) => (
  <div className={cn('flex flex-col items-center justify-center text-center py-12 px-6 text-muted', className)}>
    {icon && <div className="mb-3 opacity-40">{icon}</div>}
    <p className="text-base text-primary/70">{title}</p>
    {hint && <p className="text-sm mt-1 max-w-xs">{hint}</p>}
  </div>
);

export interface Column<T> {
  key: string;
  header: React.ReactNode;
  /** CSS grid track, e.g. "1fr", "120px", "minmax(0,2fr)". */
  width?: string;
  align?: 'left' | 'right' | 'center';
  render: (row: T) => React.ReactNode;
}

const ALIGN = { left: 'justify-start text-left', right: 'justify-end text-right', center: 'justify-center text-center' };

export const DataTable = <T,>({
  columns,
  rows,
  rowKey,
  onRowClick,
  selectedKey,
  loading,
  empty,
  className,
}: {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  selectedKey?: string | null;
  loading?: boolean;
  empty?: React.ReactNode;
  className?: string;
}) => {
  const template = columns.map((column) => column.width ?? 'minmax(0,1fr)').join(' ');
  return (
    <div className={cn('flex flex-col min-h-0', className)}>
      <div
        className="grid gap-4 px-5 py-2.5 border-b border-border/60 text-sm text-muted font-semibold shrink-0 bg-black/10"
        style={{ gridTemplateColumns: template }}
      >
        {columns.map((column) => (
          <div key={column.key} className={cn('flex items-center truncate', ALIGN[column.align ?? 'left'])}>
            {column.header}
          </div>
        ))}
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto custom-scrollbar">
        {loading && rows.length === 0 ? (
          <div className="flex items-center justify-center py-12 text-muted">
            <Loader2 size={18} className="animate-spin" />
          </div>
        ) : rows.length === 0 ? (
          empty
        ) : (
          rows.map((row) => {
            const key = rowKey(row);
            const selected = selectedKey === key;
            return (
              <div
                key={key}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  'group grid gap-4 px-5 py-3 border-b border-border/30 text-base items-center transition-colors',
                  onRowClick && 'cursor-pointer',
                  selected ? 'bg-accent/10 shadow-[inset_2px_0_0_rgb(var(--accent))]' : 'hover:bg-white/[0.03]',
                )}
                style={{ gridTemplateColumns: template }}
              >
                {columns.map((column) => (
                  <div key={column.key} className={cn('flex items-center min-w-0', ALIGN[column.align ?? 'left'])}>
                    {column.render(row)}
                  </div>
                ))}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export const PanelHeader: React.FC<{
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  actions?: React.ReactNode;
  onClose?: () => void;
}> = ({ title, subtitle, actions, onClose }) => (
  <div className="flex items-center justify-between gap-3 px-5 py-3.5 border-b border-border/60 shrink-0">
    <div className="min-w-0">
      <div className="text-lg font-semibold text-primary truncate">{title}</div>
      {subtitle && <div className="text-sm text-muted truncate mt-0.5">{subtitle}</div>}
    </div>
    <div className="flex items-center gap-1 shrink-0">
      {actions}
      {onClose && (
        <IconButton onClick={onClose}>
          <X size={14} />
        </IconButton>
      )}
    </div>
  </div>
);

export const Section: React.FC<{ title: string; right?: React.ReactNode; className?: string; children: React.ReactNode }> = ({
  title,
  right,
  className,
  children,
}) => (
  <div className={cn('space-y-2', className)}>
    <div className="flex items-center justify-between">
      <h4 className="text-sm font-semibold text-muted">{title}</h4>
      {right}
    </div>
    {children}
  </div>
);

export const Field: React.FC<{ label: string; children: React.ReactNode; mono?: boolean }> = ({
  label,
  children,
  mono,
}) => (
  <div className="flex items-center justify-between gap-3 py-2 border-b border-border/30 last:border-0 text-base">
    <span className="text-muted shrink-0">{label}</span>
    <span className={cn('text-primary min-w-0 truncate text-right flex items-center gap-1', mono && 'font-mono text-sm')}>
      {children}
    </span>
  </div>
);

export const Modal: React.FC<{
  title: string;
  subtitle?: string;
  onClose: () => void;
  footer?: React.ReactNode;
  width?: string;
  children: React.ReactNode;
}> = ({ title, subtitle, onClose, footer, width = 'max-w-md', children }) => (
  <div
    className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/70 animate-in fade-in duration-150"
    onClick={onClose}
  >
    <div
      className={cn('w-full bg-bg-primary border border-border/80 rounded-lg flex flex-col max-h-[80vh]', width)}
      onClick={(e) => e.stopPropagation()}
    >
      <PanelHeader title={title} subtitle={subtitle} onClose={onClose} />
      <div className="p-4 overflow-y-auto custom-scrollbar">{children}</div>
      {footer && <div className="flex justify-end gap-2 px-4 py-3 border-t border-border/60">{footer}</div>}
    </div>
  </div>
);

export const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <label className="block text-sm text-muted mb-1.5">{children}</label>
);

export const formatMoney = (value: number) => `$${(Number(value) || 0).toLocaleString()}`;
