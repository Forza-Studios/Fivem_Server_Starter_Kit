import React from 'react';
import { Report } from '../../../../types';
import { getReportTypeStyles } from '../../../../utils/misc';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface ReportTicketListProps {
  filteredReports: Report[];
  searchQuery: string;
  activeTab: 'Active' | 'Closed';
  onSelect: (report: Report) => void;
  activeId?: number;
}

export const ReportTicketList: React.FC<ReportTicketListProps> = ({
  filteredReports,
  searchQuery,
  activeTab,
  onSelect,
  activeId,
}) => {
  const { t } = useAdminMenu();
  return (
  <div className="flex-1 overflow-y-auto px-4 pb-6 mt-2 custom-scrollbar space-y-2">
    {filteredReports.length > 0 ? (
      filteredReports.map((report) => {
        const isActive = activeId === report.Id;

        return (
          <div
            key={report.Id}
            className={`rounded-xl p-5 border cursor-pointer transition-all duration-300 group ${
              isActive
                ? 'bg-accent/15 border-accent/40 '
                : 'bg-black/40 border-border/60 hover:bg-black/60 hover:border-border/80 '
            }`}
            onClick={() => onSelect(report)}
          >
            {/* Top: ID + Status */}
            <div className="flex justify-between items-center mb-3">
              <div className="flex items-center gap-2.5">
                <span className="text-xs font-mono text-muted/70 font-bold">#{report.Id}</span>
                <div
                  className={`w-2 h-2 rounded-full ${report.Status === 'Active' ? 'bg-green-500' : 'bg-red-500'}`}
                ></div>
              </div>
              <div className="flex items-center gap-2">
                {report.Type && (
                  <span
                    className={`text-[10px] font-rajdhani font-bold uppercase tracking-wider px-2.5 py-1 rounded-md border ${getReportTypeStyles(report.Type)}`}
                  >
                    {report.Type}
                  </span>
                )}
                <span
                  className={`text-[10px] font-rajdhani font-bold uppercase tracking-wider px-2.5 py-1 rounded-md border ${
                    report.Status === 'Active'
                      ? 'bg-green-500/10 text-green-400 border-green-500/20'
                      : 'bg-red-500/10 text-red-400 border-red-500/20'
                  }`}
                >
                  {report.Status === 'Active'
                    ? report.ClaimedBy
                      ? t('ui.pages.reports.status_claimed')
                      : t('ui.pages.reports.status_open')
                    : t('ui.pages.reports.status_closed')}
                </span>
              </div>
            </div>

            {/* Title */}
            <h3
              className={`font-rajdhani font-bold text-[15px] uppercase tracking-wide leading-snug mb-3 line-clamp-2 transition-colors ${isActive ? 'text-white' : 'text-primary/90 group-hover:text-white'}`}
            >
              {report.Title ||
                report.Description?.substring(0, 60) ||
                report.Chats?.[0]?.Message?.substring(0, 60) ||
                t('ui.pages.reports.no_content')}
            </h3>

            {/* Footer: Reporter */}
            <div className="flex items-center gap-3 mt-1 text-muted/70">
              <div className="flex items-center gap-2 bg-white/5 px-2.5 py-1 rounded-md border border-white/5">
                <i className="fa-solid fa-user text-[10px] text-accent/80"></i>
                <span className="text-xs font-rajdhani font-bold text-primary/90 uppercase tracking-wider">
                  {report.Chats?.[0]?.Sender || t('ui.pages.reports.unknown')} ({report.OpenById || '?'})
                </span>
              </div>
              {report.ClaimedByName && (
                <>
                  <span className="w-1.5 h-1.5 rounded-full bg-border/50"></span>
                  <div className="flex items-center gap-2">
                    <i className="fa-solid fa-user-shield text-[10px] text-accent/70"></i>
                    <span className="text-xs font-rajdhani font-bold text-accent/70 uppercase tracking-wider">
                      {report.ClaimedByName}
                    </span>
                  </div>
                </>
              )}
            </div>
          </div>
        );
      })
    ) : (
      <div className="flex flex-col h-full items-center justify-center text-muted py-20">
        <div className="w-16 h-16 rounded-full bg-black/40 border border-white/5 flex items-center justify-center mb-4">
          <i className="fa-regular fa-flag text-2xl text-accent/30"></i>
        </div>
        <p className="font-rajdhani text-lg font-semibold uppercase tracking-wider">
          {searchQuery ? t('ui.pages.reports.no_matches') : t('ui.pages.reports.no_tickets')}
        </p>
        <p className="font-barlow text-sm mt-1 opacity-60">
          {searchQuery
            ? t('ui.pages.reports.try_other_search')
            : activeTab === 'Active'
              ? t('ui.pages.reports.no_active_reports')
              : t('ui.pages.reports.no_closed_reports')}
        </p>
      </div>
    )}
  </div>
  );
};
