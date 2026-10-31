import React from 'react';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';
import { SubTabs, Tab } from '../../../ui/SubTabs';
import { Player } from '../../../../types';

type PlayerListTab = 'online' | 'all' | 'disconnected';

interface PlayerListHeaderProps {
  players: Player[];
  activeSubTab: PlayerListTab;
  setActiveSubTab: (tab: PlayerListTab) => void;
}

export const PlayerListHeader: React.FC<PlayerListHeaderProps> = ({ players, activeSubTab, setActiveSubTab }) => {
  const { t } = useAdminMenu();
  const tabs: Tab<PlayerListTab>[] = [
    { id: 'online', label: t('ui.pages.players.online'), icon: 'fa-solid fa-circle-check', count: players.length },
    { id: 'disconnected', label: t('ui.pages.players.disconnected'), icon: 'fa-solid fa-circle-xmark' },
    { id: 'all', label: t('ui.pages.players.all'), icon: 'fa-solid fa-users' },
  ];

  return (
    <>
      <div className="flex items-center gap-4 mb-6">
        <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
          <div className="absolute inset-0 bg-accent/20"></div>
          <i className="fa-solid fa-users text-2xl relative z-10"></i>
        </div>
        <div>
          <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
            {t('ui.pages.players.title')}
          </h2>
          <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70">
            {t('ui.pages.players.subtitle')}
          </p>
        </div>
      </div>

      <div className="border-b border-white/10 pb-4 mb-4">
        <SubTabs tabs={tabs} activeTab={activeSubTab} onChange={setActiveSubTab} />
      </div>
    </>
  );
};
