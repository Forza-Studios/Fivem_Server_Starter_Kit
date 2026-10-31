import React, { useEffect } from 'react';
import { useAdminMenu } from '../../providers/AdminMenuContext';
import { fetchNui } from '../../utils/fetchNui';
import { PlayerProfile } from '../../types';

const PinnedPlayers: React.FC = () => {
  const { pinnedTargets, pinnedVisible, setPinnedVisible, menuSize } = useAdminMenu();
  const [pinnedData, setPinnedData] = React.useState<PlayerProfile[]>([]);

  // Profiles are only loaded while the panel is open.
  useEffect(() => {
    if (!pinnedVisible) return;
    let cancelled = false;

    const keys = Object.keys(pinnedTargets).filter((key) => pinnedTargets[key]);
    Promise.all(
      keys.map((key) => fetchNui<PlayerProfile | false>('fetchPlayerProfile', { id: key }).catch(() => false)),
    )
      .then((profiles) => {
        if (!cancelled) setPinnedData(profiles.filter((profile): profile is PlayerProfile => !!profile));
      })
      .catch(() => {});

    return () => {
      cancelled = true;
    };
  }, [pinnedTargets, pinnedVisible]);

  const isLarge = menuSize === 'Large';

  return (
    <div
      className={`absolute top-0 h-full w-80 bg-black/90 flex flex-col transition-all duration-500 ease-in-out z-0 ${
        isLarge
          ? `right-0 border-y border-r border-border/50 rounded-r-2xl ${pinnedVisible ? 'translate-x-full opacity-100' : 'translate-x-0 opacity-0 pointer-events-none'}`
          : `left-0 border-y border-l border-border/50 rounded-l-2xl ${pinnedVisible ? '-translate-x-full opacity-100' : 'translate-x-0 opacity-0 pointer-events-none'}`
      }`}
    >
      <div className="p-4 border-b border-border/50 bg-black/40 flex justify-between items-center">
        <h3 className="font-rajdhani text-lg text-primary flex items-center gap-2">
          <i className="fa-solid fa-thumbtack text-accent -rotate-45"></i>
          <span className="font-semibold text-accent tracking-wider uppercase">Pinned Targets</span>
        </h3>
        <button
          onClick={() => setPinnedVisible(false)}
          className="w-8 h-8 flex items-center justify-center rounded-lg text-muted hover:text-white hover:bg-white/10 transition-colors"
        >
          <i className="fa-solid fa-times"></i>
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 custom-scrollbar space-y-3">
        {pinnedData.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-muted/50 gap-3">
            <i className="fa-solid fa-thumbtack text-4xl mb-2 opacity-20"></i>
            <p className="font-rajdhani text-lg">No pinned targets</p>
            <p className="font-barlow text-sm text-center px-4">Pin players from the Player List to keep them here.</p>
          </div>
        ) : (
          pinnedData.map((player, idx) => (
            <div
              key={idx}
              className="glass-panel rounded-xl overflow-hidden border border-border/30 hover:border-accent/50 transition-all duration-300 group"
            >
              <div className="p-3 bg-gradient-to-r from-black/60 to-black/20 border-b border-border/30 flex justify-between items-start">
                <div className="overflow-hidden">
                  <div
                    className="font-rajdhani font-bold text-primary text-lg truncate tracking-wide"
                    title={player.Name}
                  >
                    {player.Name}
                  </div>
                  <div className="font-mono text-[10px] text-muted truncate mt-0.5" title={player.Steam}>
                    {player.Steam}
                  </div>
                </div>
                <div className="bg-accent/20 border border-accent/30 text-accent font-mono text-xs px-2 py-1 rounded-md">
                  ID: {player.isOnline ? player.ServerId : '-'}
                </div>
              </div>

              <div className="p-3 space-y-2 bg-black/20">
                <div className="flex justify-between items-center bg-black/20 px-2 py-1.5 rounded">
                  <span className="font-rajdhani text-[11px] text-muted uppercase tracking-widest">Character</span>
                  <span className="font-barlow text-sm text-primary font-medium">{player.CharName}</span>
                </div>
                <div className="flex justify-between items-center bg-black/20 px-2 py-1.5 rounded">
                  <span className="font-rajdhani text-[11px] text-muted uppercase tracking-widest">Citizen ID</span>
                  <span className="font-mono text-xs text-primary/80">{player.CitizenId}</span>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default PinnedPlayers;
