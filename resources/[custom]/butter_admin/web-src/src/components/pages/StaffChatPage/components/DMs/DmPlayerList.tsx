import React from 'react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';

interface Player {
  ServerId: number;
  Name: string;
}

interface DmMessage {
  id: number;
  text: string;
  isMe: boolean;
  time: string;
}

interface DmPlayerListProps {
  players: Player[];
  searchQuery: string;
  setSearchQuery: (v: string) => void;
  selectedPlayerId: number | null;
  setSelectedPlayerId: (id: number) => void;
  dmHistories: Record<number, DmMessage[]>;
  isSmall: boolean;
}

export const DmPlayerList: React.FC<DmPlayerListProps> = ({
  players,
  searchQuery,
  setSearchQuery,
  selectedPlayerId,
  setSelectedPlayerId,
  dmHistories,
  isSmall,
}) => {
  const { t } = useAdminMenu();
  const filtered = players.filter(
    (p) =>
      !searchQuery || p.Name.toLowerCase().includes(searchQuery.toLowerCase()) || p.ServerId.toString() === searchQuery,
  );

  return (
    <div
      className={`${isSmall ? 'w-full' : 'w-1/3 min-w-[280px] max-w-[350px] border-r border-white/5'} bg-black/20 flex flex-col z-10`}
    >
      <div className="p-4 border-b border-white/5 bg-black/10">
        <div className="relative">
          <i className="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-muted text-sm"></i>
          <input
            type="text"
            placeholder={t('ui.pages.chats.search_players_placeholder')}
            className="w-full bg-black/40 border border-white/5 rounded-xl pl-10 pr-3 py-2.5 text-sm text-primary font-barlow focus:outline-none focus:border-accent/50 transition-all placeholder:text-muted/60"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>
      <div className="flex-1 overflow-y-auto custom-scrollbar p-3 space-y-1.5">
        {filtered.length === 0 ? (
          <div className="text-center text-muted font-barlow py-10 opacity-70">
            {t('ui.pages.chats.no_matching_players')}
          </div>
        ) : (
          filtered.map((p) => {
            const isSelected = selectedPlayerId === p.ServerId;
            const lastMessage = dmHistories[p.ServerId]?.[dmHistories[p.ServerId].length - 1];
            return (
              <button
                key={p.ServerId}
                onClick={() => setSelectedPlayerId(p.ServerId)}
                className={`w-full text-left flex items-center gap-3 p-3 rounded-xl transition-all duration-300 border ${isSelected ? 'bg-accent/20 border-accent/40 text-accent' : 'hover:bg-white/5 border-transparent text-primary'}`}
              >
                <div className="relative flex-shrink-0">
                  <div
                    className={`w-11 h-11 rounded-full flex items-center justify-center font-rajdhani font-bold text-lg border ${isSelected ? 'bg-accent text-white border-accent' : 'bg-black/60 border-white/10 text-muted'}`}
                  >
                    {p.Name.charAt(0).toUpperCase()}
                  </div>
                  <div className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-green-500 border-2 border-[#151515]"></div>
                </div>
                <div className="flex-1 overflow-hidden">
                  <div className="flex justify-between items-baseline mb-0.5">
                    <span className="font-rajdhani font-bold truncate tracking-wide">{p.Name}</span>
                    <span className="text-[10px] font-mono text-muted/60 bg-black/40 px-1.5 rounded-sm">
                      ID: {p.ServerId}
                    </span>
                  </div>
                  <div className="text-xs font-barlow text-muted truncate opacity-80">
                    {lastMessage ? (
                      <span>
                        <i className="fa-solid fa-reply text-[8px] mr-1 opacity-50"></i>
                        {lastMessage.text}
                      </span>
                    ) : (
                      <span className="italic">{t('ui.pages.chats.no_active_messages')}</span>
                    )}
                  </div>
                </div>
              </button>
            );
          })
        )}
      </div>
    </div>
  );
};
