import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { getReportTypeStyles } from '../../../../utils/misc';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface ReportTypeFilterProps {
  activeFilter: string;
  onChange: (filter: string) => void;
}

const FILTERS = [
  { id: 'All', key: 'all', icon: 'fa-solid fa-layer-group' },
  { id: 'Bug', key: 'bug', icon: 'fa-solid fa-bug' },
  { id: 'Player', key: 'player', icon: 'fa-solid fa-user-slash' },
  { id: 'Staff', key: 'staff', icon: 'fa-solid fa-shield-halved' },
  { id: 'Question', key: 'question', icon: 'fa-solid fa-circle-question' },
  { id: 'Claim', key: 'claim', icon: 'fa-solid fa-suitcase-rolling' },
  { id: 'Other', key: 'other', icon: 'fa-solid fa-ellipsis' },
];

export const ReportTypeFilter: React.FC<ReportTypeFilterProps> = ({ activeFilter, onChange }) => {
  const { t } = useAdminMenu();
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const activeData = FILTERS.find((f) => f.id === activeFilter) || FILTERS[0];

  return (
    <div className="relative w-full" ref={dropdownRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={`w-full bg-black/40 border border-border/50 rounded-xl py-2.5 px-4 flex items-center justify-between transition-all duration-300 group ${
          isOpen
            ? 'border-accent/50 text-accent outline outline-1 outline-accent/20'
            : 'text-primary hover:border-accent/30 hover:bg-black/60'
        }`}
      >
        <div className="flex items-center gap-3">
          <i
            className={`${activeData.icon} text-[11px] ${isOpen ? 'text-accent' : 'text-muted/60 group-hover:text-accent/80 transition-colors'}`}
          ></i>
          <span className="font-barlow text-sm font-semibold tracking-wide">
            {t(`ui.pages.reports.type_filters.${activeData.key}`)}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <i
            className={`fa-solid fa-chevron-down text-[10px] text-muted/50 transition-transform duration-300 ${isOpen ? 'rotate-180 text-accent/80' : ''}`}
          ></i>
        </div>
      </button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -4, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
            transition={{ duration: 0.15, ease: 'easeOut' }}
            className="absolute top-[calc(100%+8px)] left-0 w-full z-[100] bg-[#0c0f16]/95 border border-white/10 rounded-xl p-1.5 overflow-hidden outline outline-1 outline-black/5"
          >
            <div className="flex flex-col gap-0.5">
              {FILTERS.map((filter) => {
                const isActive = activeFilter === filter.id;
                const typeStyles = getReportTypeStyles(filter.id);

                return (
                  <button
                    key={filter.id}
                    onClick={() => {
                      onChange(filter.id);
                      setIsOpen(false);
                    }}
                    className={`w-full px-3 py-2.5 rounded-lg flex items-center justify-between group transition-all duration-200 ${
                      isActive ? 'bg-accent/10' : 'hover:bg-white/[0.04]'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={`w-7 h-7 rounded-lg flex items-center justify-center transition-all ${
                          isActive
                            ? typeStyles
                            : 'bg-black/40 border border-white/5 text-muted/40 group-hover:text-muted/70 group-hover:bg-black/60 group-hover:border-white/10'
                        }`}
                      >
                        <i className={`fa-solid ${filter.icon} text-[11px]`}></i>
                      </div>
                      <span
                        className={`font-barlow text-[13px] font-medium tracking-wide ${isActive ? 'text-primary' : 'text-muted/80 group-hover:text-primary/90'}`}
                      >
                        {t(`ui.pages.reports.type_filters.${filter.key}`)}
                      </span>
                    </div>
                    {isActive && <i className="fa-solid fa-check text-[10px] text-accent"></i>}
                  </button>
                );
              })}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};
