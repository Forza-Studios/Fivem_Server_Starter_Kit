import React from 'react';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';
import { fetchNui } from '../../../../utils/fetchNui';

interface ReportHeaderProps {
  openedReport: { Id: number } | null;
}

export const ReportHeader: React.FC<ReportHeaderProps> = ({ openedReport }) => {
  const { options, setOptions, t, menuSize } = useAdminMenu();
  const isMuted = options?.ReportsMuted || false;

  const toggleMute = () => {
    const newMuted = !isMuted;
    setOptions((prev) => ({ ...prev, ReportsMuted: newMuted }));
    // The menu context forwards the new state to the server.
    fetchNui('setPreference', { type: 'options', key: 'ReportsMuted', value: newMuted }).catch(() => {});
  };

  return (
    <div className="flex items-center justify-between mb-6">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
          <div className="absolute inset-0 bg-accent/20"></div>
          <i className="fa-solid fa-flag text-2xl relative z-10"></i>
        </div>
        <div>
          <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
            {openedReport ? `Report #${openedReport.Id}` : t('ui.tabs.reports')}
          </h2>
          <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70">
            {t('ui.pages.reports.title')}
          </p>
        </div>
      </div>

      {!openedReport && (
        <button
          onClick={toggleMute}
          className={`flex items-center justify-center rounded-lg border transition-all ${
            menuSize === 'Large' ? 'w-9 h-9' : 'gap-2 px-4 py-2'
          } ${
            isMuted
              ? 'bg-red-500/10 border-red-500/30 text-red-400 hover:bg-red-500/20'
              : 'bg-white/5 border-white/10 text-primary/80 hover:bg-white/10 hover:text-primary'
          }`}
          title={isMuted ? t('ui.pages.reports.unmute_title') : t('ui.pages.reports.mute_title')}
        >
          <i
            className={`fa-solid ${isMuted ? 'fa-bell-slash' : 'fa-bell'} ${menuSize === 'Large' ? 'text-base' : 'text-sm'}`}
          ></i>
          {menuSize !== 'Large' && (
            <span className="text-sm font-medium">
              {isMuted ? t('ui.pages.reports.notifications_muted') : t('ui.pages.reports.notifications_active')}
            </span>
          )}
        </button>
      )}
    </div>
  );
};
