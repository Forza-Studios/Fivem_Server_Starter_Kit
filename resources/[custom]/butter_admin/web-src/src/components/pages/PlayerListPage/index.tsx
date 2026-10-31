import React, { useState, useMemo, useEffect, useRef, useCallback } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { fetchNui } from '../../../utils/fetchNui';
import { copyTextToClipboard, formatPlayerListText } from '../../../utils/misc';
import { runPanelAction } from '../../../utils/panelActions';
import { PlayerListHeader } from './components/PlayerListHeader';
import { SearchField } from '../../ui/SearchField';
import { SortSelect } from '../../ui/SortSelect';
import { Select } from '../../ui/Select';
import Pagination from '../../ui/Pagination';
import { cn } from '../../../utils/cn';
import { CurrentTargetBanner } from './components/CurrentTargetBanner';
import { InventoryItemImage } from '../../ui/InventoryItemImage';
import { CurrentTarget, Player, PlayerDetails, PlayerProfile, Translate } from '../../../types';

type PlayerListTab = 'online' | 'all' | 'disconnected';

const DURATION_TRIGGER = 'bg-black/40 border border-border rounded p-2 text-primary text-sm focus:border-accent';

interface PlayerRowProps {
  player: Player;
  index: number;
  t: Translate;
  pinnedTargets: Record<string, boolean>;
  togglePinnedTarget: (key: string, pin: boolean) => void;
  currentTarget: CurrentTarget | null;
  setCurrentTarget: (target: CurrentTarget | null) => void;
  isLarge: boolean;
  activeSubTab: PlayerListTab;
  copyToClipboard: (text: string, e: React.MouseEvent) => void;
  onOpenDetails: (key: string) => void;
  hasFullProfilePerm: boolean;
  hasRevivePerm: boolean;
  hasKillPerm: boolean;
  playerNameFormat: string;
  licenseType: string;
}

const PlayerRow: React.FC<PlayerRowProps> = ({
  player,
  index,
  t,
  pinnedTargets,
  togglePinnedTarget,
  currentTarget,
  setCurrentTarget,
  isLarge,
  activeSubTab,
  copyToClipboard,
  onOpenDetails,
  hasFullProfilePerm,
  hasRevivePerm,
  hasKillPerm,
  playerNameFormat,
  licenseType,
}) => {
  const [isExpanded, setIsExpanded] = useState(false);

  const playerKey = player.CitizenId || player.License;
  const isPinned = !!pinnedTargets[playerKey];

  const listText = formatPlayerListText(player, playerNameFormat, licenseType);

  return (
    <div
      className={`group rounded-xl border transition-all duration-300 overflow-hidden ${isExpanded ? 'bg-accent/5 border-accent/30' : 'bg-black/20 border-white/5 hover:bg-white/5 hover:border-white/10'} ${!player.isOnline ? 'opacity-60 grayscale-[0.5]' : ''}`}
    >
      <div
        className="flex items-center p-3 cursor-pointer select-none"
        onClick={() =>
          player.isOnline && setCurrentTarget({ Text: `[${player.ServerId}] ${listText}`, Source: player.ServerId })
        }
      >
        <div className="w-10 flex justify-center items-center">
          <button
            className={`w-8 h-8 rounded-lg flex items-center justify-center transition-all duration-300 ${isPinned ? 'bg-accent/20 text-accent border border-accent/30' : 'text-muted hover:bg-white/5 hover:text-white'}`}
            onClick={(e) => {
              e.stopPropagation();
              togglePinnedTarget(playerKey, !isPinned);
            }}
          >
            <i
              className={`fa-solid fa-thumbtack transition-transform duration-300 ${isPinned ? '-rotate-45 scale-110' : 'opacity-40 group-hover:opacity-100'}`}
            ></i>
          </button>
        </div>
        <div className="w-6 flex justify-center items-center">
          <div className={`w-2 h-2 rounded-full ${player.isOnline ? 'bg-green-500' : 'bg-gray-500'}`}></div>
        </div>
        <div className="w-14 flex justify-center">
          <span
            className={`bg-black/40 px-2 py-0.5 rounded border border-white/10 font-mono text-xs font-bold ${player.isOnline ? 'text-accent' : 'text-muted'}`}
          >
            {player.isOnline ? player.ServerId : t('ui.pages.players.off')}
          </span>
        </div>
        <div className="flex-1 px-2">
          <div
            className={`font-rajdhani font-bold text-lg tracking-wide truncate ${player.isOnline ? 'text-primary' : 'text-muted'}`}
          >
            {player.Name}
          </div>
        </div>
        {isLarge && (
          <>
            <div className="hidden lg:flex flex-col px-4 w-48">
              <span className="text-[10px] uppercase tracking-widest text-muted font-bold">Steam</span>
              <span className="font-mono text-xs text-primary/80 truncate">{player.Steam}</span>
            </div>
            <div className="hidden xl:flex flex-col px-4 w-64">
              <span className="text-[10px] uppercase tracking-widest text-muted font-bold">License</span>
              <span className="font-mono text-xs text-primary/80 truncate">{player.License}</span>
            </div>
          </>
        )}
        <div className="flex items-center gap-2 px-2">
          <button
            className="w-8 h-8 rounded-lg flex items-center justify-center text-muted hover:bg-white/10 hover:text-accent transition-all"
            onClick={(e) => copyToClipboard(player.Steam, e)}
            title={t('ui.pages.players.copy_steam')}
          >
            <i className="fa-regular fa-copy text-sm"></i>
          </button>
          <button
            className={`w-8 h-8 rounded-lg flex items-center justify-center text-muted hover:bg-white/10 hover:text-accent transition-all duration-300 ${isExpanded ? 'rotate-180 text-accent bg-accent/10' : ''}`}
            onClick={(e) => {
              e.stopPropagation();
              setIsExpanded(!isExpanded);
            }}
          >
            <i className="fa-solid fa-chevron-down text-xs"></i>
          </button>
        </div>
      </div>

      <div
        className={`transition-all duration-300 ease-in-out overflow-hidden ${isExpanded ? 'max-h-[700px] opacity-100' : 'max-h-0 opacity-0'}`}
      >
        <div className="p-4 pt-0 border-t border-white/5 bg-black/20 space-y-3">
          {activeSubTab === 'disconnected' && (
            <div className="flex flex-col bg-red-500/10 p-3 rounded-lg border border-red-500/20 mt-4">
              <div className="flex justify-between items-center mb-1">
                <span className="text-[10px] uppercase tracking-widest text-red-300 font-bold">
                  {t('ui.pages.players.disconnect_info')}
                </span>
                <span className="text-[10px] font-mono text-red-300/80">
                  {player.Time ? new Date(player.Time * 1000).toLocaleString() : ''}
                </span>
              </div>
              <p className="text-xs text-red-200/90 font-barlow italic">
                {t('ui.pages.players.reason', player.Reason || t('ui.pages.players.unknown'))}
              </p>
            </div>
          )}

          {/* Basic Info Fields */}
          <div className="mt-3 space-y-1">
            <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted/70 block px-1">
              Basic Info
            </span>
            <div className="bg-black/30 rounded-xl border border-white/5 overflow-hidden divide-y divide-white/5">
              {[
                {
                  label: 'Server ID',
                  val: player.isOnline ? String(player.ServerId) : null,
                  icon: 'fa-solid fa-hashtag',
                  color: 'text-accent',
                },
                { label: 'Character', val: player.CharName, icon: 'fa-solid fa-id-badge', color: 'text-emerald-400' },
                { label: 'Citizen ID', val: player.CitizenId, icon: 'fa-solid fa-user-tag', color: 'text-sky-400' },
                { label: 'Steam ID', val: player.Steam, icon: 'fa-brands fa-steam', color: 'text-blue-400' },
                { label: 'Discord ID', val: player.Discord, icon: 'fa-brands fa-discord', color: 'text-indigo-400' },
                { label: 'FiveM ID', val: player.Fivem, icon: 'fa-solid fa-server', color: 'text-orange-400' },
              ].map((field) => (
                <div
                  key={field.label}
                  className="flex items-center justify-between px-3 py-2 group/item hover:bg-white/5 transition-colors"
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <i className={`${field.icon} text-[11px] ${field.color} w-4 text-center flex-shrink-0`}></i>
                    <span className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider flex-shrink-0">
                      {field.label}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 min-w-0 ml-2">
                    <span className="font-mono text-[11px] text-primary/80 truncate select-all">
                      {field.val || <span className="text-muted/40 italic not-italic">N/A</span>}
                    </span>
                    {field.val && (
                      <button
                        onClick={(e) => copyToClipboard(field.val!, e)}
                        className="text-muted hover:text-accent transition-colors p-1 opacity-0 group-hover/item:opacity-100 flex-shrink-0"
                      >
                        <i className="fa-regular fa-copy text-[10px]"></i>
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Quick Actions, Online only */}
          {player.isOnline && (hasRevivePerm || hasKillPerm) && (
            <div className="grid grid-cols-2 gap-2">
              {hasRevivePerm && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    runPanelAction('revivePlayer', { player: Number(player.ServerId) });
                  }}
                  className="px-2 py-2.5 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-400 hover:text-black border border-emerald-500/20 hover:border-emerald-500 rounded-xl font-rajdhani text-xs font-bold uppercase tracking-wider transition-all duration-300 flex items-center justify-center gap-1.5 active:scale-95 truncate"
                >
                  <i className="fa-solid fa-heart-pulse"></i>
                  Revive
                </button>
              )}
              {hasKillPerm && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    runPanelAction('killPlayer', { player: Number(player.ServerId) });
                  }}
                  className="px-2 py-2.5 bg-red-500/10 hover:bg-red-500 text-red-400 hover:text-white border border-red-500/20 hover:border-red-500 rounded-xl font-rajdhani text-xs font-bold uppercase tracking-wider transition-all duration-300 flex items-center justify-center gap-1.5 active:scale-95 truncate"
                >
                  <i className="fa-solid fa-skull"></i>
                  Kill
                </button>
              )}
            </div>
          )}

          {hasFullProfilePerm && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                onOpenDetails(playerKey);
              }}
              className="w-full px-4 py-3 bg-accent/10 hover:bg-accent text-accent hover:text-black border border-accent/20 hover:border-accent rounded-xl font-rajdhani text-xs font-bold uppercase tracking-wider transition-all duration-300 flex items-center justify-center gap-2 group active:scale-95"
            >
              <i className="fa-solid fa-address-card text-sm transition-transform group-hover:scale-110"></i>
              Open Full Profile
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

interface PlayerDetailsDrawerProps {
  player: Player;
  onClose: () => void;
  t: Translate;
  pinnedTargets: Record<string, boolean>;
  togglePinnedTarget: (key: string, pin: boolean) => void;
  currentTarget: CurrentTarget | null;
  setCurrentTarget: (target: CurrentTarget | null) => void;
  playerNotes: Record<string, string>;
  setPlayerNote: (key: string, val: string) => void;
  copyToClipboard: (text: string, e: React.MouseEvent) => void;
  isLarge: boolean;
  playerNameFormat: string;
  licenseType: string;
}

const PlayerDetailsDrawer: React.FC<PlayerDetailsDrawerProps> = ({
  player,
  onClose,
  t,
  pinnedTargets,
  togglePinnedTarget,
  currentTarget,
  setCurrentTarget,
  playerNotes,
  setPlayerNote,
  copyToClipboard,
  isLarge,
  playerNameFormat,
  licenseType,
}) => {
  const [activeAction, setActiveAction] = useState<
    'none' | 'warn' | 'kick' | 'ban' | 'tp_coords' | 'troll' | 'ghost_troll'
  >('none');
  const [reason, setReason] = useState('');
  const [banDuration, setBanDuration] = useState('1 Hour');
  const [ghostDuration, setGhostDuration] = useState('30 Seconds');
  const [coordX, setCoordX] = useState('');
  const [coordY, setCoordY] = useState('');
  const [coordZ, setCoordZ] = useState('');
  const [savingStatus, setSavingStatus] = useState<'saved' | 'saving'>('saved');
  const [activeAssetTab, setActiveAssetTab] = useState<'inventory' | 'vehicles' | 'properties'>('inventory');
  const [wipeInventoryConfirm, setWipeInventoryConfirm] = useState(false);

  const [copiedField, setCopiedField] = useState<string | null>(null);
  const [ipRevealed, setIpRevealed] = useState(false);

  const handleCopy = (label: string, value: string, e: React.MouseEvent) => {
    e.stopPropagation();
    copyTextToClipboard(value);
    setCopiedField(label);
    setTimeout(() => {
      setCopiedField(null);
    }, 1500);
  };

  const [fullPlayer, setFullPlayer] = useState<PlayerProfile | null>(null);
  const [isLoadingDetails, setIsLoadingDetails] = useState(true);
  const notesTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const playerKey = player.CitizenId || player.License;
  const isPinned = !!pinnedTargets[playerKey];

  // Read through a ref, so list refreshes and note edits don't refetch the profile.
  const latest = useRef({ player, playerNotes });
  useEffect(() => {
    latest.current = { player, playerNotes };
  });

  const refetchPlayerDetails = useCallback(() => {
    setIsLoadingDetails(true);
    fetchNui<PlayerProfile | false>('fetchPlayerProfile', { id: playerKey })
      .then((data) => {
        setFullPlayer(data || latest.current.player);
        if (data && data.Note !== undefined && latest.current.playerNotes[playerKey] !== data.Note) {
          setPlayerNote(playerKey, data.Note);
        }
      })
      .catch(() => setFullPlayer(latest.current.player))
      .finally(() => setIsLoadingDetails(false));
  }, [playerKey, setPlayerNote]);

  useEffect(() => {
    // Clear any pending note save when player changes
    if (notesTimeoutRef.current) {
      clearTimeout(notesTimeoutRef.current);
    }

    refetchPlayerDetails();
  }, [playerKey, player.isOnline, refetchPlayerDetails]);

  useEffect(() => {
    return () => {
      if (notesTimeoutRef.current) {
        clearTimeout(notesTimeoutRef.current);
      }
    };
  }, []);

  const pData: PlayerProfile = fullPlayer ?? player;
  const details: PlayerDetails = pData.Details ?? {};

  const handleActionSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (activeAction === 'warn') {
      runPanelAction('warnPlayer', { player: Number(player.ServerId), reason });
      setReason('');
    } else if (activeAction === 'kick') {
      runPanelAction('kickPlayer', { player: Number(player.ServerId), reason });
      setReason('');
    } else if (activeAction === 'ban') {
      runPanelAction('banPlayer', {
        player: Number(player.ServerId),
        expire: banDuration,
        reason,
      });
      setReason('');
    } else if (activeAction === 'tp_coords') {
      runPanelAction('teleportPlayerToCoords', {
        player: Number(player.ServerId),
        coords: { x: Number(coordX), y: Number(coordY), z: Number(coordZ) },
      });
      setCoordX('');
      setCoordY('');
      setCoordZ('');
    } else if (activeAction === 'ghost_troll') {
      let seconds = 30;
      if (ghostDuration === '15 Seconds') seconds = 15;
      else if (ghostDuration === '30 Seconds') seconds = 30;
      else if (ghostDuration === '1 Minute') seconds = 60;
      else if (ghostDuration === '2 Minutes') seconds = 120;
      else if (ghostDuration === '5 Minutes') seconds = 300;
      else if (ghostDuration === '10 Minutes') seconds = 600;
      else if (ghostDuration === 'Infinite') seconds = 0;

      runPanelAction('ghostTroll', {
        player: Number(player.ServerId),
        duration: seconds,
      });
    }
    setActiveAction('none');
  };

  const handleNotesChange = (val: string) => {
    setSavingStatus('saving');
    setPlayerNote(playerKey, val);

    if (notesTimeoutRef.current) {
      clearTimeout(notesTimeoutRef.current);
    }

    notesTimeoutRef.current = setTimeout(() => {
      fetchNui('savePlayerNote', { identifier: playerKey, note: val })
        .then(() => {
          setSavingStatus('saved');
        })
        .catch(() => {
          setSavingStatus('saved');
        });
    }, 750);
  };

  // Grouped actions
  const moderationActions = [
    {
      label: 'Warn',
      icon: 'fa-triangle-exclamation',
      color: 'hover:bg-orange-500/20 hover:text-orange-400 hover:border-orange-500/40',
      action: () => setActiveAction('warn'),
    },
    {
      label: 'Kick',
      icon: 'fa-user-xmark',
      color: 'hover:bg-rose-500/20 hover:text-rose-400 hover:border-rose-500/40',
      action: () => setActiveAction('kick'),
    },
    {
      label: 'Ban',
      icon: 'fa-ban',
      color: 'hover:bg-red-500/20 hover:text-red-400 hover:border-red-500/40',
      action: () => setActiveAction('ban'),
    },
  ];

  const teleportActions = [
    {
      label: 'Bring',
      icon: 'fa-download',
      color: 'hover:bg-violet-500/20 hover:text-violet-400 hover:border-violet-500/40',
      action: () =>
        runPanelAction('teleportPlayer', {
          player: Number(player.ServerId),
          type: 'Bring',
        }),
    },
    {
      label: 'Go to',
      icon: 'fa-upload',
      color: 'hover:bg-blue-500/20 hover:text-blue-400 hover:border-blue-500/40',
      action: () =>
        runPanelAction('teleportPlayer', {
          player: Number(player.ServerId),
          type: 'Goto',
        }),
    },
    {
      label: 'TP to Coords',
      icon: 'fa-map-location-dot',
      color: 'hover:bg-teal-500/20 hover:text-teal-400 hover:border-teal-500/40',
      action: () => setActiveAction('tp_coords'),
    },
    {
      label: 'TP to Marker',
      icon: 'fa-location-crosshairs',
      color: 'hover:bg-cyan-500/20 hover:text-cyan-400 hover:border-cyan-500/40',
      action: () =>
        runPanelAction('teleportPlayerToMarker', {
          player: Number(player.ServerId),
        }),
    },
    {
      label: 'TP into Veh.',
      icon: 'fa-car',
      color: 'hover:bg-amber-500/20 hover:text-amber-400 hover:border-amber-500/40',
      action: () => runPanelAction('teleportIntoVehicle', { player: Number(player.ServerId) }),
    },
  ];

  const adminActions = [
    {
      label: 'Heal',
      icon: 'fa-house-medical-heart',
      color: 'hover:bg-green-500/20 hover:text-green-400 hover:border-green-500/40',
      action: () => runPanelAction('healPlayer', { player: Number(player.ServerId) }),
    },
    {
      label: 'Noclip',
      icon: 'fa-ghost',
      color: 'hover:bg-indigo-500/20 hover:text-indigo-400 hover:border-indigo-500/40',
      action: () => runPanelAction('toggleNoclip'),
    },
    {
      label: 'Spectate',
      icon: 'fa-eye',
      color: 'hover:bg-purple-500/20 hover:text-purple-400 hover:border-purple-500/40',
      action: () => runPanelAction('spectatePlayer', { player: Number(player.ServerId) }),
    },
    {
      label: 'Freeze',
      icon: 'fa-snowflake',
      color: 'hover:bg-sky-500/20 hover:text-sky-400 hover:border-sky-500/40',
      action: () => runPanelAction('freezePlayer', { player: Number(player.ServerId) }),
    },
  ];

  const trollActions = [
    {
      label: 'Fling',
      icon: 'fa-wind',
      color: 'hover:bg-orange-500/20 hover:text-orange-400 hover:border-orange-500/40',
      event: 'flingPlayer',
    },
    {
      label: 'Set Fire',
      icon: 'fa-fire',
      color: 'hover:bg-red-500/20 hover:text-red-400 hover:border-red-500/40',
      event: 'setOnFire',
    },
    {
      label: 'Drunk',
      icon: 'fa-wine-glass-empty',
      color: 'hover:bg-purple-500/20 hover:text-purple-400 hover:border-purple-500/40',
      event: 'makeDrunk',
    },
    {
      label: 'UFO Abduct',
      icon: 'fa-user-astronaut',
      color: 'hover:bg-sky-500/20 hover:text-sky-400 hover:border-sky-500/40',
      event: 'ufoKidnap',
    },
    {
      label: 'Ghost Troll',
      icon: 'fa-ghost',
      color: 'hover:bg-gray-500/20 hover:text-gray-400 hover:border-gray-500/40',
      event: 'ghostTroll',
    },
    {
      label: 'Jailbox',
      icon: 'fa-cubes',
      color: 'hover:bg-indigo-500/20 hover:text-indigo-400 hover:border-indigo-500/40',
      event: 'sendToJailbox',
    },
    {
      label: 'Damage Veh.',
      icon: 'fa-car-burst',
      color: 'hover:bg-yellow-500/20 hover:text-yellow-400 hover:border-yellow-500/40',
      event: 'damageVehicle',
    },
    {
      label: 'Kidnap Van',
      icon: 'fa-truck-ramp-box',
      color: 'hover:bg-pink-500/20 hover:text-pink-400 hover:border-pink-500/40',
      event: 'kidnapVan',
    },
  ];

  const getListText = (p: Player) => formatPlayerListText(p, playerNameFormat, licenseType);

  return (
    <div className="flex flex-col h-full w-full">
      {/* Header */}
      <div className="p-6 pb-2">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-4 min-w-0 flex-1">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden shrink-0">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-user text-2xl relative z-10"></i>
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 flex-nowrap min-w-0">
                <h2
                  className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase truncate whitespace-nowrap min-w-0"
                  title={pData.Name || player.Name}
                >
                  {pData.Name || player.Name}
                </h2>
                <div className="flex items-center gap-2 shrink-0">
                  <span
                    className={`w-2 h-2 rounded-full shrink-0 ${pData.isOnline ? 'bg-green-500' : 'bg-gray-500'}`}
                  ></span>
                  <span
                    className={`bg-black/40 px-2 py-0.5 rounded border border-border/50 font-mono text-[10px] font-bold shrink-0 whitespace-nowrap ${pData.isOnline ? 'text-accent' : 'text-muted'}`}
                  >
                    {pData.isOnline ? `ID: ${pData.ServerId}` : t('ui.pages.players.off')}
                  </span>
                </div>
              </div>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold truncate">
                Player Profile & Administrative Controls
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2 shrink-0 ml-4">
            {pData.isOnline && (
              <button
                onClick={() =>
                  setCurrentTarget({ Text: `[${pData.ServerId}] ${getListText(pData)}`, Source: pData.ServerId })
                }
                className={`h-8 px-3 rounded border text-xs font-rajdhani font-bold uppercase tracking-wider transition-all duration-300 flex items-center gap-1.5 shrink-0 ${currentTarget?.Source === pData.ServerId ? 'bg-accent text-black border-accent' : 'bg-black/20 text-primary border-border/50 hover:bg-white/10'} whitespace-nowrap`}
              >
                <i className="fa-solid fa-bullseye"></i>
                {currentTarget?.Source === pData.ServerId ? 'Targeted' : 'Target'}
              </button>
            )}
            <button
              onClick={() => togglePinnedTarget(playerKey, !isPinned)}
              className={`w-8 h-8 rounded flex items-center justify-center transition-all duration-300 shrink-0 ${isPinned ? 'bg-accent/20 text-accent border border-accent/30' : 'bg-black/20 text-muted border border-border/50 hover:bg-white/10 hover:text-white'}`}
              title="Pin Target"
            >
              <i
                className={`fa-solid fa-thumbtack transition-transform duration-300 ${isPinned ? '-rotate-45 scale-110' : ''}`}
              ></i>
            </button>
            <button
              onClick={onClose}
              className="h-8 px-3 rounded flex items-center justify-center gap-1.5 bg-black/20 border border-border/50 text-muted hover:bg-white/10 hover:text-primary transition-all duration-300 font-rajdhani font-bold uppercase text-xs tracking-wider shrink-0 whitespace-nowrap"
            >
              <i className="fa-solid fa-arrow-left text-[10px]"></i>
              Back to List
            </button>
          </div>
        </div>
      </div>

      {/* Body Content */}
      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar">
        <div
          className={`grid grid-cols-1 ${isLarge ? 'grid-cols-2' : 'grid-cols-1'} gap-6 h-full max-w-[1600px] mx-auto`}
        >
          {/* LEFT COLUMN: Identifiers & Notes */}
          <div className={`space-y-6 flex flex-col ${isLarge ? 'h-full' : 'h-auto'}`}>
            {/* Player Status Card, online only */}
            {pData.isOnline && (
              <div className="space-y-2">
                <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted block flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
                  Live Player Status
                </span>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    {
                      label: 'Health',
                      val: pData.Health,
                      icon: 'fa-heart',
                      color: 'text-red-400',
                      percentage: pData.Health != null ? (pData.Health / 200) * 100 : null,
                      displayVal: pData.Health != null ? `${pData.Health} HP` : '--',
                    },
                    {
                      label: 'Armor',
                      val: pData.Armor,
                      icon: 'fa-shield-halved',
                      color: 'text-sky-400',
                      percentage: pData.Armor != null ? pData.Armor : null,
                      displayVal: pData.Armor != null ? `${pData.Armor}%` : '--',
                    },
                    {
                      label: 'Ping',
                      val: pData.Ping,
                      icon: 'fa-signal',
                      color: 'text-green-400',
                      percentage: null,
                      displayVal: pData.Ping != null ? `${pData.Ping} ms` : '--',
                    },
                    {
                      label: 'Server ID',
                      val: pData.ServerId,
                      icon: 'fa-hashtag',
                      color: 'text-accent',
                      percentage: null,
                      displayVal: pData.ServerId ? `#${pData.ServerId}` : '--',
                    },
                  ].map((s) => (
                    <div
                      key={s.label}
                      className={`bg-black/20 border border-border/50 rounded-lg p-3 flex flex-col justify-between relative`}
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center flex-shrink-0">
                          <i className={`fa-solid ${s.icon} text-sm ${s.color}`}></i>
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider">
                            {s.label}
                          </div>
                          <div
                            className={`font-mono text-sm font-extrabold ${s.val != null ? s.color : 'text-muted/40'}`}
                          >
                            {s.displayVal}
                          </div>
                        </div>
                      </div>
                      {s.percentage !== null && (
                        <div className="w-full bg-black/40 h-1 rounded-full overflow-hidden mt-3">
                          <div
                            className={`h-full rounded-full transition-all duration-500 ${s.label === 'Health' ? 'bg-red-500' : 'bg-sky-500'}`}
                            style={{ width: `${Math.min(100, Math.max(0, s.percentage))}%` }}
                          ></div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
                {/* Radio + Job & Gang row */}
                {(pData.Radio != null || details.job || details.gang) && (
                  <div className="grid grid-cols-2 gap-3">
                    {pData.Radio != null && (
                      <div className="bg-black/20 border border-border/50 rounded-lg p-3 flex items-center gap-3">
                        <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center flex-shrink-0 text-orange-400">
                          <i className="fa-solid fa-walkie-talkie text-sm"></i>
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider">
                            Radio
                          </div>
                          <div className="font-mono text-sm font-extrabold text-orange-400 truncate">
                            {pData.Radio > 0 ? `Ch. ${pData.Radio}` : 'Off'}
                          </div>
                        </div>
                      </div>
                    )}
                    {details.gang && (
                      <div className="bg-black/20 border border-border/50 rounded-lg p-3 flex items-center gap-3">
                        <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center flex-shrink-0 text-purple-400">
                          <i className="fa-solid fa-mask text-sm"></i>
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider">
                            Gang
                          </div>
                          <div className="font-rajdhani text-sm font-extrabold text-purple-300 truncate">
                            {details.gang}
                          </div>
                        </div>
                      </div>
                    )}
                    {details.job && (
                      <div className="bg-black/20 border border-border/50 rounded-lg p-3 flex items-center gap-3">
                        <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center flex-shrink-0 text-amber-400">
                          <i className="fa-solid fa-briefcase text-sm"></i>
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider">
                            Job
                          </div>
                          <div className="font-rajdhani text-sm font-extrabold text-amber-300 truncate">
                            {details.job}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}
                {/* Coords */}
                {pData.Coords && (
                  <div className="bg-black/20 border border-border/50 rounded-lg p-3 flex items-center gap-3">
                    <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center flex-shrink-0 text-teal-400">
                      <i className="fa-solid fa-map-pin text-sm"></i>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="text-[10px] text-muted font-rajdhani font-bold uppercase tracking-wider mb-0.5">
                        Coordinates
                      </div>
                      <div className="font-mono text-[11px] text-teal-300 truncate select-all">
                        X: {pData.Coords.x.toFixed(1)}&nbsp;&nbsp; Y: {pData.Coords.y.toFixed(1)}&nbsp;&nbsp; Z:{' '}
                        {pData.Coords.z.toFixed(1)}
                      </div>
                    </div>
                    {pData.Coords && (
                      <button
                        onClick={(e) => {
                          const c = pData.Coords;
                          if (c)
                            handleCopy('Coordinates', `${c.x.toFixed(2)}, ${c.y.toFixed(2)}, ${c.z.toFixed(2)}`, e);
                        }}
                        className="text-muted hover:text-teal-400 transition-colors p-1.5 flex-shrink-0"
                      >
                        {copiedField === 'Coordinates' ? (
                          <i className="fa-solid fa-check text-success text-xs animate-pulse"></i>
                        ) : (
                          <i className="fa-regular fa-copy text-xs"></i>
                        )}
                      </button>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Financial Status Card */}
            {details.money && (
              <div className="space-y-2">
                <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted block">
                  Financial Records
                </span>
                <div className="grid grid-cols-3 gap-3">
                  {[
                    {
                      label: 'Cash Balance',
                      val: details.money.cash,
                      icon: 'fa-money-bill-1-wave',
                      color: 'text-emerald-400',
                    },
                    {
                      label: 'Bank Balance',
                      val: details.money.bank,
                      icon: 'fa-building-columns',
                      color: 'text-sky-400',
                    },
                    { label: 'Crypto Assets', val: details.money.crypto, icon: 'fa-coins', color: 'text-amber-400' },
                  ].map((m) => (
                    <div
                      key={m.label}
                      className={`bg-black/20 border border-border/50 rounded-lg p-3 flex flex-col justify-between min-w-0 overflow-hidden`}
                    >
                      <div className="flex items-center justify-between gap-1 min-w-0">
                        <span className="text-[9px] text-muted font-rajdhani font-bold uppercase tracking-wider truncate">
                          {m.label}
                        </span>
                        <i className={`fa-solid ${m.icon} text-xs ${m.color} flex-shrink-0`}></i>
                      </div>
                      <div
                        className={`font-mono text-sm font-extrabold mt-2 truncate ${m.color}`}
                        title={`$${m.val != null ? m.val.toLocaleString() : '0'}`}
                      >
                        ${m.val != null ? m.val.toLocaleString() : '0'}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Character Info Card */}
            {details && (details.dob || details.phone || details.bloodgroup) && (
              <div className="space-y-2">
                <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted block">
                  Character Details
                </span>
                <div className="grid grid-cols-3 gap-3">
                  {[
                    { label: 'Date of Birth', val: details.dob, icon: 'fa-cake-candles', color: 'text-pink-400' },
                    { label: 'Phone Number', val: details.phone, icon: 'fa-phone', color: 'text-teal-400' },
                    { label: 'Blood Type', val: details.bloodgroup, icon: 'fa-droplet', color: 'text-red-400' },
                  ].map((c) => (
                    <div
                      key={c.label}
                      className={`bg-black/20 border border-border/50 rounded-lg p-3 flex flex-col justify-between`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-[9px] text-muted font-rajdhani font-bold uppercase tracking-wider">
                          {c.label}
                        </span>
                        <i className={`fa-solid ${c.icon} text-[10px] ${c.color}`}></i>
                      </div>
                      <div className="font-rajdhani text-xs font-bold text-primary mt-2 truncate">{c.val || '--'}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Identifiers Section */}
            <div className="space-y-3">
              <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted block">
                Copyable Player Identifiers
              </span>
              <div className="bg-black/20 border border-border/50 rounded-lg p-4 space-y-1">
                {[
                  { label: 'Citizen ID', val: pData.CitizenId, icon: 'fa-user-tag' },
                  { label: 'Steam ID', val: pData.Steam, icon: 'fa-steam' },
                  { label: 'Discord ID', val: pData.Discord, icon: 'fa-brands fa-discord' },
                  { label: 'FiveM ID', val: pData.Fivem, icon: 'fa-server' },
                  { label: 'Rockstar License', val: pData.License, icon: 'fa-id-card' },
                  { label: 'Xbox ID', val: pData.Xbox, icon: 'fa-brands fa-xbox' },
                  {
                    label: 'IP Address',
                    val: ipRevealed ? pData.IP : pData.IP ? '••••••••••••••' : undefined,
                    icon: 'fa-network-wired',
                    isIp: true,
                  },
                  { label: 'Hardware ID (HWID)', val: pData.HardwareId, icon: 'fa-microchip' },
                ].map((field) => (
                  <div
                    key={field.label}
                    className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 py-2 border-b border-border/30 last:border-0 group/item"
                  >
                    <span className="text-xs text-muted font-bold font-rajdhani uppercase tracking-wider flex items-center gap-2">
                      <i
                        className={`${field.icon.startsWith('fa-') && !field.icon.startsWith('fa-solid') && !field.icon.startsWith('fa-brands') ? `fa-solid ${field.icon}` : field.icon} text-[11px] text-muted/50 group-hover/item:text-accent transition-colors duration-200`}
                      ></i>
                      {field.label}
                    </span>
                    <div className="flex items-center justify-between sm:justify-end gap-2 w-full sm:w-auto">
                      {field.isIp && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setIpRevealed((v) => !v);
                          }}
                          className="h-6 w-6 flex items-center justify-center rounded border border-border/50 bg-black/30 text-muted hover:text-accent hover:border-accent/50 transition-colors flex-shrink-0"
                          title={ipRevealed ? 'Hide IP' : 'Reveal IP'}
                        >
                          <i className={`fa-solid ${ipRevealed ? 'fa-eye-slash' : 'fa-eye'} text-[10px]`}></i>
                        </button>
                      )}
                      <div
                        className="flex items-center justify-between sm:justify-end gap-2 flex-1 bg-black/30 px-2 py-1 rounded border border-border/50 hover:border-accent/50 transition-colors cursor-pointer"
                        onClick={(e) => {
                          if (field.isIp && !ipRevealed) {
                            e.stopPropagation();
                            setIpRevealed(true);
                            return;
                          }
                          field.val && field.val !== 'N/A' && handleCopy(field.label, field.val, e);
                        }}
                      >
                        <span className="font-mono text-xs text-primary truncate max-w-[200px] sm:max-w-[250px] select-all">
                          {field.val || '--'}
                        </span>
                        {field.val && field.val !== 'N/A' && !field.isIp && (
                          <i
                            className={`text-muted group-hover/item:text-accent transition-all ${copiedField === field.label ? 'fa-solid fa-check text-success' : 'fa-regular fa-copy'}`}
                          ></i>
                        )}
                        {field.isIp && ipRevealed && pData.IP && pData.IP !== 'N/A' && (
                          <i
                            className={`text-muted group-hover/item:text-accent transition-all ${copiedField === field.label ? 'fa-solid fa-check text-success' : 'fa-regular fa-copy'}`}
                          ></i>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Notes Section (Auto-saving) */}
            <div className="bg-black/20 p-4 border border-border/50 rounded-lg flex flex-col flex-1 min-h-[220px]">
              <div className="flex justify-between items-center mb-3">
                <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted block">
                  Permanent Player Records (Notes)
                </span>
                <div className="flex items-center gap-2 text-[9px] font-rajdhani font-bold uppercase tracking-wider text-muted">
                  <span
                    className={`w-1.5 h-1.5 rounded-full ${savingStatus === 'saving' ? 'bg-amber-500 animate-pulse' : 'bg-green-500'}`}
                  ></span>
                  {savingStatus === 'saving' ? 'Saving...' : 'Saved'}
                </div>
              </div>
              <textarea
                className="w-full flex-1 bg-black/40 border border-border rounded-lg p-3 text-primary font-barlow text-sm focus:outline-none focus:border-accent transition-colors resize-none custom-scrollbar"
                placeholder={t('ui.pages.players.notes_placeholder')}
                value={playerNotes[playerKey] || ''}
                onChange={(e) => handleNotesChange(e.target.value)}
              />
            </div>
          </div>

          {/* RIGHT COLUMN: Administrative Actions & Asset Tabs */}
          <div className={`space-y-6 flex flex-col ${isLarge ? 'h-full' : 'h-auto'}`}>
            <div className="space-y-3 flex flex-col">
              <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted/60 block">
                Administrative Toolset
              </span>

              <div className="bg-black/20 p-4 border border-border/50 rounded-lg">
                {pData.isOnline ? (
                  <>
                    {activeAction === 'none' ? (
                      <div className="space-y-6">
                        {/* Player Moderation Panel */}
                        <div className="space-y-3">
                          <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-white/40 block flex items-center gap-2">
                            <span className="w-1 h-3 rounded-full bg-rose-500"></span>
                            Player Moderation
                          </span>
                          <div className="grid grid-cols-2 xl:grid-cols-3 gap-2">
                            {moderationActions.map((act) => (
                              <button
                                key={act.label}
                                onClick={act.action}
                                className={`px-4 py-2 bg-black/30 border border-border/50 rounded flex items-center justify-center gap-2 text-primary font-rajdhani text-xs font-bold uppercase tracking-wider transition-colors ${act.color}`}
                              >
                                <i className={`fa-solid ${act.icon} text-xs`}></i>
                                {act.label}
                              </button>
                            ))}
                          </div>
                        </div>

                        {/* Teleportation Panel */}
                        <div className="space-y-3">
                          <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-white/40 block flex items-center gap-2">
                            <span className="w-1 h-3 rounded-full bg-teal-500"></span>
                            Teleportation Controls
                          </span>
                          <div className="grid grid-cols-2 xl:grid-cols-3 gap-2">
                            {teleportActions.map((act) => (
                              <button
                                key={act.label}
                                onClick={act.action}
                                className={`px-4 py-2 bg-black/30 border border-border/50 rounded flex items-center justify-center gap-2 text-primary font-rajdhani text-xs font-bold uppercase tracking-wider transition-colors ${act.color}`}
                              >
                                <i className={`fa-solid ${act.icon} text-xs`}></i>
                                {act.label}
                              </button>
                            ))}
                          </div>
                        </div>

                        {/* Admin Panel */}
                        <div className="space-y-3">
                          <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-white/40 block flex items-center gap-2">
                            <span className="w-1 h-3 rounded-full bg-accent"></span>
                            Administration
                          </span>
                          <div className="grid grid-cols-2 xl:grid-cols-3 gap-2">
                            {adminActions.map((act) => (
                              <button
                                key={act.label}
                                onClick={act.action}
                                className={`px-4 py-2 bg-black/30 border border-border/50 rounded flex items-center justify-center gap-2 text-primary font-rajdhani text-xs font-bold uppercase tracking-wider transition-colors ${act.color}`}
                              >
                                <i className={`fa-solid ${act.icon} text-xs`}></i>
                                {act.label}
                              </button>
                            ))}
                            <button
                              onClick={() => setActiveAction('troll')}
                              className="px-4 py-2 bg-black/30 border border-border/50 hover:border-pink-500/50 rounded flex items-center justify-center gap-2 text-primary hover:text-pink-400 font-rajdhani text-xs font-bold uppercase tracking-wider transition-colors"
                            >
                              <i className="fa-solid fa-face-grin-tears text-xs"></i>
                              Troll Menu
                            </button>
                          </div>
                        </div>
                      </div>
                    ) : activeAction === 'troll' ? (
                      <div className="space-y-4">
                        <div className="flex justify-between items-center">
                          <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-pink-400 block flex items-center gap-2">
                            <span className="w-1 h-3 rounded-full bg-pink-500 animate-pulse"></span>
                            Troll & Fun Controls
                          </span>
                          <button
                            onClick={() => setActiveAction('none')}
                            className="text-[10px] font-rajdhani font-bold uppercase text-muted/60 hover:text-accent transition-colors flex items-center gap-1"
                          >
                            <i className="fa-solid fa-arrow-left text-[9px]"></i> Back
                          </button>
                        </div>
                        <div className="grid grid-cols-2 xl:grid-cols-3 gap-2">
                          {trollActions.map((act) => (
                            <button
                              key={act.label}
                              onClick={() => {
                                if (act.label === 'Ghost Troll') {
                                  setActiveAction('ghost_troll');
                                } else {
                                  runPanelAction(act.event, { player: Number(pData.ServerId) });
                                }
                              }}
                              className={`px-4 py-2 bg-black/30 border border-border/50 rounded flex items-center justify-center gap-2 text-primary font-rajdhani text-xs font-bold uppercase tracking-wider transition-colors ${act.color}`}
                            >
                              <i className={`fa-solid ${act.icon} text-xs`}></i>
                              {act.label}
                            </button>
                          ))}
                        </div>
                      </div>
                    ) : (
                      <form
                        onSubmit={handleActionSubmit}
                        className="bg-black/20 p-4 border border-border/50 rounded-lg space-y-4 relative overflow-hidden h-full flex flex-col"
                      >
                        <div className="absolute inset-0 bg-accent/[0.02] pointer-events-none"></div>
                        <div className="relative flex flex-col gap-4 flex-1">
                          <div className="flex justify-between items-center">
                            <div className="text-sm font-rajdhani font-bold uppercase tracking-wider text-accent">
                              {activeAction === 'warn'
                                ? 'Warn Player'
                                : activeAction === 'kick'
                                  ? 'Kick Player'
                                  : activeAction === 'ban'
                                    ? 'Ban Player'
                                    : activeAction === 'ghost_troll'
                                      ? 'Ghost Troll Duration'
                                      : 'Teleport to Coordinates'}
                            </div>
                            <button
                              type="button"
                              onClick={() => setActiveAction(activeAction === 'ghost_troll' ? 'troll' : 'none')}
                              className="text-[10px] font-rajdhani font-bold uppercase text-muted hover:text-accent transition-colors flex items-center gap-1"
                            >
                              <i className="fa-solid fa-arrow-left text-[9px]"></i> Back
                            </button>
                          </div>

                          {activeAction === 'ban' && (
                            <div className="flex flex-col gap-1.5">
                              <label className="text-[9px] uppercase tracking-wider text-muted font-bold">
                                Duration
                              </label>
                              <Select
                                value={banDuration}
                                onChange={setBanDuration}
                                triggerClassName={DURATION_TRIGGER}
                                options={['1 Hour', '6 Hours', '12 Hours', '1 Day', '3 Days', '1 Week', 'Permanent'].map(
                                  (d) => ({ id: d, label: d }),
                                )}
                              />
                            </div>
                          )}

                          {activeAction === 'ghost_troll' && (
                            <div className="flex flex-col gap-1.5">
                              <label className="text-[9px] uppercase tracking-wider text-muted font-bold">
                                Ghost Visibility Duration
                              </label>
                              <Select
                                value={ghostDuration}
                                onChange={setGhostDuration}
                                triggerClassName={DURATION_TRIGGER}
                                options={[
                                  '15 Seconds',
                                  '30 Seconds',
                                  '1 Minute',
                                  '2 Minutes',
                                  '5 Minutes',
                                  '10 Minutes',
                                  'Infinite',
                                ].map((d) => ({ id: d, label: d }))}
                              />
                            </div>
                          )}

                          {activeAction === 'tp_coords' ? (
                            <div className="grid grid-cols-3 gap-2">
                              {[
                                { label: 'X', val: coordX, setVal: setCoordX },
                                { label: 'Y', val: coordY, setVal: setCoordY },
                                { label: 'Z', val: coordZ, setVal: setCoordZ },
                              ].map(({ label, val, setVal }) => (
                                <div key={label} className="flex flex-col gap-1.5">
                                  <label className="text-[9px] uppercase tracking-wider text-muted font-bold">
                                    {label}
                                  </label>
                                  <input
                                    type="number"
                                    step="any"
                                    required
                                    placeholder="0.0"
                                    value={val}
                                    onChange={(e) => setVal(e.target.value)}
                                    className="w-full bg-black/40 border border-border rounded p-2 text-primary font-mono text-sm focus:outline-none focus:border-accent transition-colors placeholder-white/10"
                                  />
                                </div>
                              ))}
                            </div>
                          ) : (
                            activeAction !== 'ghost_troll' && (
                              <div className="flex flex-col gap-1.5 flex-1">
                                <label className="text-[9px] uppercase tracking-wider text-muted font-bold">
                                  Reason
                                </label>
                                <textarea
                                  required
                                  placeholder={
                                    activeAction === 'warn'
                                      ? 'E.g., FailRP / Metagaming'
                                      : activeAction === 'kick'
                                        ? 'E.g., AFK / Trolling'
                                        : 'E.g., Exploiting / Modding'
                                  }
                                  value={reason}
                                  onChange={(e) => setReason(e.target.value)}
                                  className="w-full flex-1 min-h-[120px] bg-black/40 border border-border rounded p-3 text-primary text-sm focus:outline-none focus:border-accent transition-colors resize-none"
                                />
                              </div>
                            )
                          )}

                          <div className="flex justify-end gap-2 pt-4 border-t border-border/30 mt-auto">
                            <button
                              type="button"
                              onClick={() => setActiveAction(activeAction === 'ghost_troll' ? 'troll' : 'none')}
                              className="px-4 py-2 bg-black/30 hover:bg-black/50 border border-border/50 rounded text-primary font-rajdhani text-sm font-bold uppercase tracking-wider transition-colors"
                            >
                              Cancel
                            </button>
                            <button
                              type="submit"
                              className="px-4 py-2 bg-accent/20 hover:bg-accent text-accent hover:text-black border border-accent/50 hover:border-accent rounded font-rajdhani text-sm font-bold uppercase tracking-wider transition-colors"
                            >
                              Submit
                            </button>
                          </div>
                        </div>
                      </form>
                    )}
                  </>
                ) : (
                  <div className="p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-xl text-yellow-300/80 text-xs font-rajdhani font-bold uppercase tracking-wider flex items-center justify-center gap-2 m-auto">
                    <i className="fa-solid fa-triangle-exclamation"></i>
                    Actions unavailable while player is offline
                  </div>
                )}
              </div>
            </div>

            {/* Player Assets Section (Inventory, Vehicles, Properties) */}
            <div className="bg-black/20 border border-border/50 rounded-lg flex-1 flex flex-col overflow-hidden min-h-[380px]">
              {/* Tab Headers */}
              <div className="flex border-b border-border/30 bg-black/30 p-1.5 gap-1.5">
                {[
                  {
                    id: 'inventory' as const,
                    label: 'Inventory',
                    icon: 'fa-box-open',
                    count: details.inventory?.length || 0,
                  },
                  { id: 'vehicles' as const, label: 'Vehicles', icon: 'fa-car', count: details.vehicles?.length || 0 },
                  {
                    id: 'properties' as const,
                    label: 'Properties',
                    icon: 'fa-house',
                    count: details.properties?.length || 0,
                  },
                ].map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveAssetTab(tab.id)}
                    className={`flex-1 py-2 px-4 text-xs font-rajdhani font-bold uppercase tracking-wider rounded transition-colors flex items-center justify-center gap-2 border ${activeAssetTab === tab.id ? 'bg-accent/10 border-accent/50 text-accent' : 'bg-transparent border-transparent text-muted hover:text-primary hover:bg-white/5'}`}
                  >
                    <i className={`fa-solid ${tab.icon} text-[10px]`}></i>
                    {tab.label}
                    <span
                      className={`px-1.5 py-0.5 rounded text-[9px] font-mono font-bold transition-colors ${activeAssetTab === tab.id ? 'bg-accent/20 text-accent' : 'bg-black/40 text-muted/80'}`}
                    >
                      {tab.count}
                    </span>
                  </button>
                ))}
              </div>

              {/* Tab Contents */}
              <div className="flex-1 p-4 overflow-y-auto custom-scrollbar">
                {isLoadingDetails ? (
                  <div className="flex flex-col items-center justify-center h-full text-muted py-8">
                    <i className="fa-solid fa-circle-notch animate-spin text-2xl mb-2 text-accent"></i>
                    <span className="font-rajdhani font-bold text-xs uppercase tracking-wider">Loading Assets...</span>
                  </div>
                ) : (
                  <>
                    {activeAssetTab === 'inventory' && (
                      <div className="space-y-4">
                        <div className="flex justify-between items-center px-1">
                          <span className="text-[10px] uppercase font-bold tracking-widest text-muted">
                            Character Inventory Items
                          </span>
                          {!wipeInventoryConfirm ? (
                            <button
                              onClick={() => setWipeInventoryConfirm(true)}
                              className="px-2.5 py-1 bg-danger/10 hover:bg-danger text-danger hover:text-white border border-danger/20 hover:border-danger rounded-lg font-rajdhani text-[10px] font-bold uppercase tracking-wider transition-all duration-200"
                            >
                              Wipe Inventory
                            </button>
                          ) : (
                            <div className="flex items-center gap-1.5 animate-in zoom-in-95 duration-200">
                              <button
                                onClick={() => {
                                  setWipeInventoryConfirm(false);
                                  fetchNui<boolean>('inventoryAction', {
                                    action: 'Wipe',
                                    invId: `player:${pData.isOnline ? pData.ServerId : pData.CitizenId}`,
                                  })
                                    .then((applied) => applied && refetchPlayerDetails())
                                    .catch(() => {});
                                }}
                                className="px-2.5 py-1 bg-danger text-white rounded-lg font-rajdhani text-[10px] font-bold uppercase tracking-wider hover:bg-red-700 transition-all duration-200"
                              >
                                Confirm Wipe
                              </button>
                              <button
                                onClick={() => setWipeInventoryConfirm(false)}
                                className="w-6 h-6 flex items-center justify-center bg-white/10 text-white rounded-lg hover:bg-white/20 transition-all"
                              >
                                <i className="fa-solid fa-xmark text-[10px]"></i>
                              </button>
                            </div>
                          )}
                        </div>
                        {details.inventory && details.inventory.length > 0 ? (
                          <div
                            className={`grid gap-2 ${isLarge ? 'grid-cols-4 xl:grid-cols-5' : 'grid-cols-4 sm:grid-cols-5'}`}
                          >
                            {details.inventory.map((item, idx) => (
                              <div
                                key={`${item.name}-${idx}`}
                                className="group/slot bg-black/40 hover:bg-white/5 border border-border/30 hover:border-accent/20 rounded-xl p-2 flex flex-col items-center justify-center relative aspect-square transition-all cursor-pointer "
                                title={`${item.label} (x${item.count})`}
                              >
                                <InventoryItemImage
                                  item={item}
                                  className="w-10 h-10 object-contain transition-transform group-hover/slot:scale-110 duration-300"
                                />
                                <span className="absolute bottom-1 right-1.5 bg-black/60 text-primary border border-border/40 text-[9px] font-mono font-bold px-1 rounded">
                                  x{item.count}
                                </span>
                                <span className="text-[8px] font-rajdhani font-bold text-muted truncate max-w-full text-center mt-1 group-hover/slot:text-primary transition-colors">
                                  {item.label}
                                </span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="flex flex-col items-center justify-center py-10 text-muted/50 border border-dashed border-border/30 rounded-xl">
                            <i className="fa-solid fa-box text-2xl mb-2 opacity-30"></i>
                            <span className="text-[10px] uppercase font-bold tracking-wider">Inventory is Empty</span>
                          </div>
                        )}
                      </div>
                    )}

                    {activeAssetTab === 'vehicles' && (
                      <div className="space-y-3">
                        <span className="text-[10px] uppercase font-bold tracking-widest text-muted block px-1">
                          Registered Player Vehicles
                        </span>
                        {details.vehicles && details.vehicles.length > 0 ? (
                          <div className="grid grid-cols-1 gap-2.5">
                            {details.vehicles.map((veh) => (
                              <div
                                key={veh.plate}
                                className="bg-black/40 border border-border/30 rounded-xl p-3 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 hover:bg-white/5 hover:border-border/50 transition-all"
                              >
                                <div className="flex items-center gap-3 min-w-0">
                                  <div className="w-10 h-10 bg-black/40 rounded-lg flex items-center justify-center text-accent border border-border/30">
                                    <i className="fa-solid fa-car text-base"></i>
                                  </div>
                                  <div className="min-w-0">
                                    <div className="font-rajdhani font-bold text-sm text-primary uppercase tracking-wide truncate">
                                      {veh.model}
                                    </div>
                                    <div className="flex items-center gap-2 mt-0.5">
                                      <span className="font-mono text-[10px] bg-black/40 border border-border/40 px-1.5 py-0.2 rounded text-muted uppercase tracking-wider">
                                        {veh.plate}
                                      </span>
                                      <span
                                        className={`text-[10px] font-rajdhani font-bold uppercase tracking-wider px-1.5 py-0.2 rounded ${veh.state === 'Stored' ? 'bg-green-500/10 text-green-400 border border-green-500/20' : veh.state === 'Impounded' ? 'bg-danger/10 text-danger border border-danger/20' : 'bg-blue-500/10 text-blue-400 border border-blue-500/20'}`}
                                      >
                                        {veh.state}
                                      </span>
                                    </div>
                                  </div>
                                </div>

                                <div className="flex flex-col gap-1 w-full sm:w-36 text-xs text-muted">
                                  <div className="flex justify-between items-center text-[9px] uppercase tracking-wider">
                                    <span>Engine</span>
                                    <span className="font-mono font-bold text-primary">
                                      {Math.round((veh.engine || 1000) / 10)}%
                                    </span>
                                  </div>
                                  <div className="w-full bg-black/50 h-1 rounded-full overflow-hidden">
                                    <div
                                      className={`h-full rounded-full ${(veh.engine ?? 1000) > 600 ? 'bg-emerald-500' : (veh.engine ?? 1000) > 300 ? 'bg-amber-500' : 'bg-red-500'}`}
                                      style={{ width: `${Math.min(100, (veh.engine || 1000) / 10)}%` }}
                                    ></div>
                                  </div>

                                  <div className="flex justify-between items-center text-[9px] uppercase tracking-wider mt-1">
                                    <span>Fuel</span>
                                    <span className="font-mono font-bold text-primary">
                                      {Math.round(veh.fuel || 100)}%
                                    </span>
                                  </div>
                                  <div className="w-full bg-black/50 h-1 rounded-full overflow-hidden">
                                    <div
                                      className="h-full rounded-full bg-sky-500"
                                      style={{ width: `${Math.min(100, veh.fuel || 0)}%` }}
                                    ></div>
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="flex flex-col items-center justify-center py-10 text-muted/50 border border-dashed border-border/30 rounded-xl">
                            <i className="fa-solid fa-car-burst text-2xl mb-2 opacity-30"></i>
                            <span className="text-[10px] uppercase font-bold tracking-wider">No Owned Vehicles</span>
                          </div>
                        )}
                      </div>
                    )}

                    {activeAssetTab === 'properties' && (
                      <div className="space-y-3">
                        <span className="text-[10px] uppercase font-bold tracking-widest text-muted block px-1">
                          Owned Real Estate Properties
                        </span>
                        {details.properties && details.properties.length > 0 ? (
                          <div className="grid grid-cols-1 gap-2.5">
                            {details.properties.map((prop, idx) => (
                              <div
                                key={idx}
                                className="bg-black/40 border border-border/30 rounded-xl p-3 flex justify-between items-center hover:bg-white/5 hover:border-border/50 transition-all"
                              >
                                <div className="flex items-center gap-3 min-w-0">
                                  <div className="w-10 h-10 bg-black/40 rounded-lg flex items-center justify-center text-accent border border-border/30">
                                    <i className="fa-solid fa-house-chimney text-base"></i>
                                  </div>
                                  <div className="min-w-0">
                                    <div className="font-rajdhani font-bold text-sm text-primary truncate">
                                      {prop.label}
                                    </div>
                                    <div className="text-[10px] text-muted truncate mt-0.5">{prop.address}</div>
                                  </div>
                                </div>
                                <button
                                  onClick={() =>
                                    fetchNui('propertyAction', { action: 'teleport', propertyId: prop.id }).catch(
                                      () => {},
                                    )
                                  }
                                  className="px-2.5 py-1.5 bg-accent/10 hover:bg-accent text-accent hover:text-black border border-accent/20 hover:border-accent rounded-lg font-rajdhani text-[10px] font-bold uppercase tracking-wider transition-all duration-200 flex items-center gap-1 active:scale-95"
                                >
                                  <i className="fa-solid fa-location-arrow text-[8px]"></i>
                                  Teleport
                                </button>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="flex flex-col items-center justify-center py-10 text-muted/50 border border-dashed border-border/30 rounded-xl">
                            <i className="fa-solid fa-house-circle-exclamation text-2xl mb-2 opacity-30"></i>
                            <span className="text-[10px] uppercase font-bold tracking-wider">No Owned Properties</span>
                          </div>
                        )}
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const DB_PAGE_SIZE = 50;

type PlayerSort = 'id' | 'name' | 'ping';

const PlayerListPage: React.FC = () => {
  const {
    t,
    players,
    dbPlayers,
    dbPlayersTotal,
    disconnectedPlayers,
    pinnedTargets,
    togglePinnedTarget,
    currentTarget,
    setCurrentTarget,
    playerNotes,
    setPlayerNote,
    menuSize,
    pages,
    playerNameFormat,
    licenseType,
    requestData,
  } = useAdminMenu();
  const [searchQuery, setSearchQuery] = useState('');
  const [activeSubTab, setActiveSubTab] = useState<PlayerListTab>('online');
  const [selectedPlayerKey, setSelectedPlayerKey] = useState<string | null>(null);
  const [sort, setSort] = useState<PlayerSort>('id');
  const [pinnedOnly, setPinnedOnly] = useState(false);
  const [dbPage, setDbPage] = useState(1);

  useEffect(() => {
    setDbPage(1);
  }, [searchQuery, activeSubTab]);

  // The database list is too big to load at once, so "All" searches and pages on the server.
  useEffect(() => {
    if (activeSubTab !== 'all') return;
    const timer = setTimeout(
      () =>
        requestData('players', { includeDb: true, search: searchQuery, page: dbPage, limit: DB_PAGE_SIZE }).catch(
          () => {},
        ),
      searchQuery ? 300 : 0,
    );
    return () => clearTimeout(timer);
  }, [activeSubTab, searchQuery, dbPage, requestData]);

  const filteredPlayers = useMemo(() => {
    let baseList: Player[] = [];

    const onlineMap = new Map<string, Player>();
    players.forEach((p) => {
      if (p.CitizenId) onlineMap.set(p.CitizenId, p);
      else if (p.License) onlineMap.set(p.License, p);
    });

    if (activeSubTab === 'online') {
      baseList = players.map((p) => ({ ...p, isOnline: true }));
    } else if (activeSubTab === 'disconnected') {
      baseList = disconnectedPlayers.map((p) => ({ ...p, isOnline: false }));
    } else if (activeSubTab === 'all') {
      baseList = dbPlayers.map((dbP) => {
        const onlinePlayer = onlineMap.get(dbP.CitizenId ?? '') || onlineMap.get(dbP.License);
        return {
          ...dbP,
          isOnline: !!onlinePlayer,
          ServerId: onlinePlayer ? onlinePlayer.ServerId : dbP.ServerId,
        };
      });

      baseList.sort((a, b) => {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return (a.Name || '').localeCompare(b.Name || '');
      });
    }

    if (activeSubTab !== 'all') {
      if (sort === 'name') baseList.sort((a, b) => (a.Name || '').localeCompare(b.Name || ''));
      else if (sort === 'ping') baseList.sort((a, b) => (b.Ping ?? 0) - (a.Ping ?? 0));
      else baseList.sort((a, b) => Number(a.ServerId) - Number(b.ServerId));
    }

    if (pinnedOnly) baseList = baseList.filter((p) => pinnedTargets[p.CitizenId || p.License]);

    // The server already searched the "All" list.
    if (!searchQuery || activeSubTab === 'all') return baseList;

    const query = searchQuery.toLowerCase();
    return baseList.filter((p) => {
      const playerKey = p.CitizenId || p.License;
      const note = playerNotes[playerKey] || '';
      return (
        String(p.ServerId) === query ||
        [p.Name, p.CharName, p.Steam, p.License, p.CitizenId, p.Discord, note].some((value) =>
          (value || '').toLowerCase().includes(query),
        )
      );
    });
  }, [players, dbPlayers, disconnectedPlayers, searchQuery, playerNotes, activeSubTab, sort, pinnedOnly, pinnedTargets]);

  const selectedPlayer = useMemo(() => {
    if (!selectedPlayerKey) return null;
    return filteredPlayers.find((p) => (p.CitizenId || p.License) === selectedPlayerKey) || null;
  }, [filteredPlayers, selectedPlayerKey]);

  const copyToClipboard = (text: string, e: React.MouseEvent) => {
    e.stopPropagation();
    copyTextToClipboard(text);
  };

  const isLarge = menuSize === 'Large';

  return (
    <div className="flex flex-col h-full w-full relative overflow-hidden">
      <div className="p-6 pb-2">
        <PlayerListHeader players={players} activeSubTab={activeSubTab} setActiveSubTab={setActiveSubTab} />
        <div className="flex items-center gap-2 mb-4">
          <SearchField
            className="flex-1"
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder={t('ui.pages.players.search_placeholder')}
          />
          {activeSubTab !== 'all' && (
            <SortSelect
              value={sort}
              onChange={setSort}
              options={[
                { id: 'id', label: t('ui.pages.players.sort_id') },
                { id: 'name', label: t('ui.pages.players.sort_name') },
                { id: 'ping', label: t('ui.pages.players.sort_ping') },
              ]}
            />
          )}
          <button
            onClick={() => setPinnedOnly((value) => !value)}
            className={cn(
              'flex items-center gap-2 px-3 py-2 rounded-lg border text-xs font-barlow transition-colors',
              pinnedOnly
                ? 'bg-accent/15 border-accent/40 text-accent'
                : 'bg-black/30 border-white/5 text-white/50 hover:text-white hover:border-white/10',
            )}
          >
            <i className="fa-solid fa-thumbtack text-[11px]"></i>
            {isLarge && t('ui.pages.players.pinned_only')}
          </button>
        </div>
        <CurrentTargetBanner currentTarget={currentTarget} onClear={() => setCurrentTarget(null)} />
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar">
        <div className="space-y-2">
          {filteredPlayers.map((player, index) => (
            <PlayerRow
              key={`${player.CitizenId || player.License}-${player.ServerId}-${index}`}
              player={player}
              index={index}
              t={t}
              pinnedTargets={pinnedTargets}
              togglePinnedTarget={togglePinnedTarget}
              currentTarget={currentTarget}
              setCurrentTarget={setCurrentTarget}
              isLarge={isLarge}
              copyToClipboard={copyToClipboard}
              activeSubTab={activeSubTab}
              onOpenDetails={(key) => setSelectedPlayerKey(key)}
              hasFullProfilePerm={!!pages.FullProfile}
              hasRevivePerm={!!pages.Revive}
              hasKillPerm={!!pages.Kill}
              playerNameFormat={playerNameFormat}
              licenseType={licenseType}
            />
          ))}
          {filteredPlayers.length === 0 && (
            <div className="flex flex-col items-center justify-center py-20 text-muted">
              <i className="fa-solid fa-user-slash text-4xl mb-4 opacity-20"></i>
              <p className="font-rajdhani font-bold uppercase tracking-widest">
                {searchQuery || pinnedOnly ? t('ui.pages.players.no_results') : t('ui.pages.players.no_players')}
              </p>
            </div>
          )}
        </div>
        {activeSubTab === 'all' && dbPlayersTotal > DB_PAGE_SIZE && (
          <Pagination
            className="mt-4"
            currentPage={dbPage}
            totalItems={dbPlayersTotal}
            itemsPerPage={DB_PAGE_SIZE}
            onPageChange={setDbPage}
            label={t('ui.pages.players.players_label')}
          />
        )}
      </div>

      {/* Full-Page Player Details View */}
      {selectedPlayer && (
        <div className="absolute inset-0 bg-bg-primary rounded-r-lg z-50 flex flex-col animate-slide-in-right">
          <PlayerDetailsDrawer
            player={selectedPlayer}
            onClose={() => setSelectedPlayerKey(null)}
            t={t}
            pinnedTargets={pinnedTargets}
            togglePinnedTarget={togglePinnedTarget}
            currentTarget={currentTarget}
            setCurrentTarget={setCurrentTarget}
            playerNotes={playerNotes}
            setPlayerNote={setPlayerNote}
            copyToClipboard={copyToClipboard}
            isLarge={isLarge}
            playerNameFormat={playerNameFormat}
            licenseType={licenseType}
          />
        </div>
      )}
    </div>
  );
};

export default PlayerListPage;
