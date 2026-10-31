import React, { useEffect } from 'react';
import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from 'lucide-react';

interface PaginationProps {
  currentPage: number; // 1-indexed
  totalItems: number;
  itemsPerPage: number;
  onPageChange: (page: number) => void;
  className?: string;
  label?: string; // e.g. "records", "entries"
  /** Puts range text above controls (same buttons, better fit in narrow panels) */
  stacked?: boolean;
}

const Pagination: React.FC<PaginationProps> = ({
  currentPage,
  totalItems,
  itemsPerPage,
  onPageChange,
  className = '',
  label = 'entries',
  stacked = false,
}) => {
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  // A filter/search can shrink totalItems out from under an already-advanced
  // page number; clamp what we render and ask the parent to correct its state
  // rather than showing a page that no longer exists.
  const page = Math.min(Math.max(1, currentPage), totalPages);

  useEffect(() => {
    if (currentPage !== page) onPageChange(page);
  }, [currentPage, page, onPageChange]);

  const startItem = totalItems === 0 ? 0 : (page - 1) * itemsPerPage + 1;
  const endItem = Math.min(page * itemsPerPage, totalItems);

  if (totalPages <= 1 && totalItems === 0) return null;

  // Build the page numbers to show, always show first, last, current ±1
  const pages: (number | 'ellipsis')[] = [];
  if (totalPages <= 7) {
    for (let i = 1; i <= totalPages; i++) pages.push(i);
  } else {
    pages.push(1);
    if (page > 3) pages.push('ellipsis');
    for (let i = Math.max(2, page - 1); i <= Math.min(totalPages - 1, page + 1); i++) {
      pages.push(i);
    }
    if (page < totalPages - 2) pages.push('ellipsis');
    pages.push(totalPages);
  }

  const btnSize = stacked ? 'w-8 h-8' : 'w-9 h-9';

  const btn = (onClick: () => void, disabled: boolean, children: React.ReactNode, title?: string) => (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`
 ${btnSize} shrink-0 flex items-center justify-center rounded-lg border text-xs font-bold transition-all
 ${
   disabled
     ? 'border-white/5 text-white/20 cursor-not-allowed'
     : 'border-white/10 text-white/60 hover:border-accent/40 hover:text-accent hover:bg-accent/10 active:scale-95'
 }
 `}
    >
      {children}
    </button>
  );

  return (
    <div
      className={`select-none min-w-0 ${stacked ? 'flex flex-col gap-2.5' : 'flex items-center justify-between gap-3'} ${className}`}
    >
      <span
        className={`text-sm text-muted ${stacked ? 'text-center' : 'shrink-0'}`}
      >
        {totalItems === 0 ? `No ${label}` : `${startItem}–${endItem} of ${totalItems.toLocaleString()} ${label}`}
      </span>

      <div
        className={`flex items-center gap-0.5 min-w-0 ${
          stacked ? 'flex-nowrap justify-center w-full overflow-x-auto' : 'shrink-0'
        }`}
      >
        {btn(() => onPageChange(1), page === 1, <ChevronsLeft size={14} />, 'First page')}
        {btn(() => onPageChange(page - 1), page === 1, <ChevronLeft size={14} />, 'Previous page')}

        {pages.map((p, i) =>
          p === 'ellipsis' ? (
            <span
              key={`ellipsis-${i}`}
              className={`${btnSize} shrink-0 flex items-center justify-center text-white/20 text-xs`}
            >
              …
            </span>
          ) : (
            <button
              key={p}
              onClick={() => onPageChange(p as number)}
              className={`
 ${btnSize} shrink-0 flex items-center justify-center rounded-lg border text-sm font-semibold transition-all
 ${
   page === p
     ? 'bg-accent text-white border-accent '
     : 'border-white/10 text-white/60 hover:border-white/20 hover:text-white hover:bg-white/5 active:scale-95'
 }
 `}
            >
              {p}
            </button>
          ),
        )}

        {btn(() => onPageChange(page + 1), page === totalPages, <ChevronRight size={14} />, 'Next page')}
        {btn(() => onPageChange(totalPages), page === totalPages, <ChevronsRight size={14} />, 'Last page')}
      </div>
    </div>
  );
};

export default Pagination;
