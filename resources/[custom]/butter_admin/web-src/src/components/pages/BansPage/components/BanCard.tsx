import React from 'react';
import { BannedPlayer } from '../../../../types';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface BanCardProps {
  ban: BannedPlayer & { _idx: number };
  idx: number;
  isExpanded: boolean;
  activeTab: 'active' | 'history';
  confirmUnbanIdx: number | null;
  banNotes: Record<string, string>;
  onToggle: () => void;
  onCopy: (text: string, e: React.MouseEvent) => void;
  onUnban: (ban: BannedPlayer, e: React.MouseEvent) => void;
  onConfirmUnban: (idx: number | null) => void;
  onSetNote: (banId: string, note: string) => void;
  formatDate: (val: BannedPlayer['Expires'] | undefined) => string;
}

type DateVal = number | { day: number; month: number; year: number; hour: number; min: number };

const toMs = (val: DateVal): number | null => {
  if (!val) return null;
  if (typeof val === 'number') return val * 1000;
  return new Date(val.year, val.month - 1, val.day, val.hour, val.min).getTime();
};

const remaining = (expires: DateVal): { label: string; tone: 'red' | 'amber' | 'muted' } => {
  const ms = toMs(expires);
  if (ms === null) return { label: 'Permanent', tone: 'red' };
  const diff = ms - Date.now();
  if (diff <= 0) return { label: 'Expired', tone: 'muted' };
  const days = Math.floor(diff / 86400000);
  const hours = Math.floor((diff % 86400000) / 3600000);
  if (days >= 1) return { label: `${days}d left`, tone: days <= 3 ? 'amber' : 'muted' };
  return { label: `${hours}h left`, tone: 'amber' };
};

const IdentityChip: React.FC<{
  icon: string;
  value: string;
  color: string;
  onCopy: (e: React.MouseEvent) => void;
  title: string;
}> = ({ icon, value, color, onCopy, title }) => (
  <button
    className="flex items-center gap-2 bg-black/30 hover:bg-black/50 border border-white/5 hover:border-accent/40 rounded-lg px-3 py-2 transition-all group text-left w-full"
    onClick={onCopy}
    title={title}
  >
    <i className={`${icon}`} style={{ color }}></i>
    <span className="font-mono text-xs text-primary truncate flex-1">{value}</span>
    <i className="fa-regular fa-copy text-muted group-hover:text-accent opacity-0 group-hover:opacity-100 transition-all text-xs"></i>
  </button>
);

export const BanCard: React.FC<BanCardProps> = ({
  ban,
  idx,
  isExpanded,
  activeTab,
  confirmUnbanIdx,
  banNotes,
  onToggle,
  onCopy,
  onUnban,
  onConfirmUnban,
  onSetNote,
  formatDate,
}) => {
  const { t } = useAdminMenu();
  const banId = ban.BanId || String(ban._idx);
  const isPermanent = !ban.Expires;
  const initial = ban.Name?.trim().charAt(0).toUpperCase() || '?';
  const rem = remaining(ban.Expires);
  const remTones = {
    red: 'text-red-400 bg-red-500/10 border-red-500/25',
    amber: 'text-amber-400 bg-amber-500/10 border-amber-500/25',
    muted: 'text-muted bg-white/5 border-white/10',
  } as const;

  return (
    <div
      className={`group/card relative rounded-xl overflow-hidden transition-all duration-300 bg-black/20 border ${isExpanded ? 'border-accent/50' : 'border-white/5 hover:border-white/15'}`}
    >
      {/* Header Row */}
      <div
        className="px-4 py-4 flex justify-between items-center cursor-pointer hover:bg-white/[0.03] transition-colors"
        onClick={onToggle}
      >
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-white/10 to-white/5 border border-white/10 flex items-center justify-center font-rajdhani font-bold text-lg text-primary shrink-0">
            {initial}
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h3 className="font-rajdhani font-semibold text-primary text-lg leading-tight truncate">{ban.Name}</h3>
              <span
                className={`shrink-0 px-2 py-0.5 rounded-full text-[10px] font-mono uppercase tracking-wider border ${isPermanent ? 'text-red-400 bg-red-500/10 border-red-500/25' : 'text-amber-400 bg-amber-500/10 border-amber-500/25'}`}
              >
                {isPermanent ? 'perma' : 'temp'}
              </span>
            </div>
            <p className="font-barlow text-muted text-xs truncate">
              <span className="text-primary/70">{ban.Reason}</span>
              <span className="opacity-40"> · </span>
              {t('ui.pages.bans.card.banned_by', ban.BannedBy)}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          {activeTab === 'active' && (
            <span
              className={`hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-mono border ${remTones[rem.tone]}`}
            >
              <i className={`fa-solid ${isPermanent ? 'fa-infinity' : 'fa-hourglass-half'} text-[9px]`}></i>
              {rem.label}
            </span>
          )}
          <button
            className="w-8 h-8 rounded-lg border border-transparent hover:border-accent/30 flex items-center justify-center text-muted hover:bg-white/10 hover:text-accent transition-all"
            onClick={(e) =>
              onCopy(
                `Player Name: ${ban.Name}\nDiscord ID: ${ban.Discord || 'N/A'}\nBan Reason: ${ban.Reason}\nDate & Time: ${formatDate(ban.BannedOn)}`,
                e,
              )
            }
            title={t('ui.pages.bans.card.copy_details')}
          >
            <i className="fa-regular fa-copy text-sm"></i>
          </button>
          <div className="w-8 h-8 flex items-center justify-center">
            <i
              className={`fa-solid fa-chevron-down text-muted transition-transform duration-300 ${isExpanded ? 'rotate-180 text-accent' : ''}`}
            ></i>
          </div>
        </div>
      </div>

      {/* Expanded Section */}
      <div
        className={`overflow-hidden transition-all duration-300 ease-in-out ${isExpanded ? 'max-h-[600px] opacity-100' : 'max-h-0 opacity-0'}`}
      >
        <div className="px-4 pb-4 border-t border-white/5">
          {/* Reason banner */}
          <div className="mt-4 rounded-lg bg-red-500/5 border border-red-500/15 p-3">
            <div className="flex items-center gap-2 mb-1">
              <i className="fa-solid fa-circle-exclamation text-red-400 text-xs"></i>
              <h4 className="font-rajdhani text-xs text-red-400 uppercase tracking-wider">
                {t('ui.pages.bans.card.reason')}
              </h4>
            </div>
            <p className="font-barlow text-sm text-primary break-words">{ban.Reason}</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            {/* Identifiers */}
            <div className="space-y-2">
              <h4 className="font-rajdhani text-xs text-accent uppercase tracking-wider">
                {t('ui.pages.bans.card.identifiers')}
              </h4>
              <div className="space-y-2">
                {ban.Discord && (
                  <IdentityChip
                    icon="fa-brands fa-discord"
                    value={ban.Discord}
                    color="#5865F2"
                    onCopy={(e) => onCopy(ban.Discord!, e)}
                    title={t('ui.pages.bans.card.copy_discord')}
                  />
                )}
                {ban.Steam && (
                  <IdentityChip
                    icon="fa-brands fa-steam"
                    value={ban.Steam}
                    color="#9ca3af"
                    onCopy={(e) => onCopy(ban.Steam ?? '', e)}
                    title={t('ui.pages.bans.card.copy_steam')}
                  />
                )}
                {!ban.Discord && !ban.Steam && <p className="font-barlow text-xs text-muted italic">—</p>}
              </div>
            </div>

            {/* Timeline */}
            <div className="space-y-2">
              <h4 className="font-rajdhani text-xs text-accent uppercase tracking-wider">
                {t('ui.pages.bans.card.banned_on')}
              </h4>
              <div className="space-y-2">
                <div className="flex items-center justify-between bg-black/30 border border-white/5 rounded-lg px-3 py-2">
                  <span className="font-barlow text-xs text-muted">
                    <i className="fa-regular fa-calendar mr-2"></i>
                    {t('ui.pages.bans.card.banned_on')}
                  </span>
                  <span className="font-mono text-xs text-primary">{formatDate(ban.BannedOn)}</span>
                </div>
                <div className="flex items-center justify-between bg-black/30 border border-white/5 rounded-lg px-3 py-2">
                  <span className="font-barlow text-xs text-muted">
                    <i className="fa-regular fa-hourglass-half mr-2"></i>
                    {t('ui.pages.bans.card.expires')}
                  </span>
                  <span className={`font-mono text-xs ${isPermanent ? 'text-red-400' : 'text-primary'}`}>
                    {isPermanent ? '∞' : formatDate(ban.Expires)}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Ban Notes */}
          <div className="mt-4">
            <label className="font-rajdhani text-xs text-muted uppercase tracking-wider mb-2 block">
              {t('ui.pages.bans.card.notes')}
            </label>
            <textarea
              className="w-full bg-black/40 border border-white/5 rounded-lg p-3 text-primary font-barlow text-sm focus:outline-none focus:border-accent transition-colors resize-y min-h-[70px] custom-scrollbar"
              placeholder={t('ui.pages.bans.card.notes_placeholder')}
              value={banNotes[banId] || ''}
              onChange={(e) => onSetNote(banId, e.target.value)}
              onClick={(e) => e.stopPropagation()}
            />
          </div>

          <div className="mt-4 flex justify-end gap-2 items-center">
            {activeTab === 'active' &&
              (confirmUnbanIdx === idx ? (
                <>
                  <span className="font-barlow text-xs text-muted mr-auto">
                    {t('ui.pages.bans.card.confirm_unban')}?
                  </span>
                  <button
                    className="bg-black/40 hover:bg-black/60 text-muted border border-white/5 px-4 py-2 rounded-lg font-rajdhani font-semibold tracking-wide transition-colors"
                    onClick={(e) => {
                      e.stopPropagation();
                      onConfirmUnban(null);
                    }}
                  >
                    {t('common.cancel')}
                  </button>
                  <button
                    className="bg-red-500/20 hover:bg-red-500/40 text-red-400 border border-red-500/50 px-4 py-2 rounded-lg font-rajdhani font-semibold tracking-wide transition-colors flex items-center gap-2"
                    onClick={(e) => {
                      onUnban(ban, e);
                      onConfirmUnban(null);
                    }}
                  >
                    <i className="fa-solid fa-check"></i> {t('ui.pages.bans.card.confirm_unban')}
                  </button>
                </>
              ) : (
                <button
                  className="bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 px-4 py-2 rounded-lg font-rajdhani font-semibold tracking-wide transition-colors flex items-center gap-2"
                  onClick={(e) => {
                    e.stopPropagation();
                    onConfirmUnban(idx);
                  }}
                >
                  <i className="fa-solid fa-unlock"></i> {t('ui.pages.bans.card.unban_player')}
                </button>
              ))}
            {activeTab === 'history' && (
              <span className="text-muted font-barlow text-sm italic">
                {t(
                  'ui.pages.bans.card.unbanned_on',
                  ban.UnbannedDate ? formatDate(ban.UnbannedDate) : t('ui.pages.bans.card.unknown'),
                )}
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
