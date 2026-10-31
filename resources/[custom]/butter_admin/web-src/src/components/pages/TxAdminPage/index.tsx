import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAdminMenu, toArray } from '../../../providers/AdminMenuContext';
import { fetchNui } from '../../../utils/fetchNui';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { SubTabs } from '../../ui/SubTabs';
import { SearchField } from '../../ui/SearchField';
import { SortSelect } from '../../ui/SortSelect';

interface ConsoleLine {
  id: number;
  ch: string;
  msg: string;
}
interface SessionEntry {
  id: number;
  name: string;
  charName?: string | null;
  ping: number;
  joinedAt: number;
  playSec: number;
}
interface EventEntry {
  id: number;
  kind: string;
  label: string;
  time: number;
}
interface ServerInfo {
  hostname: string;
  players: number;
  maxPlayers: number;
  uptimeMs: number;
  txVersion: string;
  txName: string;
  serverMode: string;
  fxVersion: string;
  nextRestart?: { minutes?: number } | null;
}

const MAX_LINES = 400;

type SessionSort = 'id' | 'name' | 'ping' | 'session';

interface DashboardSnapshot {
  info?: ServerInfo;
  console?: ConsoleLine[];
  events?: EventEntry[];
  canRunCommands?: boolean;
}

type DashboardPush =
  | ({ kind: 'snapshot' } & DashboardSnapshot)
  | { kind: 'console'; lines?: ConsoleLine[] }
  | { kind: 'event'; event?: EventEntry };

const kindStyles: Record<string, { icon: string; color: string }> = {
  restart: { icon: 'fa-solid fa-arrows-rotate', color: 'text-blue-400' },
  announcement: { icon: 'fa-solid fa-bullhorn', color: 'text-amber-400' },
  shutdown: { icon: 'fa-solid fa-power-off', color: 'text-red-400' },
  kick: { icon: 'fa-solid fa-user-slash', color: 'text-orange-400' },
  ban: { icon: 'fa-solid fa-gavel', color: 'text-red-500' },
  warn: { icon: 'fa-solid fa-triangle-exclamation', color: 'text-yellow-400' },
};

const formatDuration = (sec: number): string => {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m`;
  return `${sec}s`;
};

const pingColor = (ping: number): string => {
  if (ping <= 0) return 'text-muted';
  if (ping < 80) return 'text-green-400';
  if (ping < 150) return 'text-amber-400';
  return 'text-red-400';
};

const formatUptime = (ms: number): string => {
  const total = Math.floor(ms / 1000);
  const d = Math.floor(total / 86400);
  const h = Math.floor((total % 86400) / 3600);
  const m = Math.floor((total % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
};

const TxAdminPage: React.FC = () => {
  const { resources, refreshResources, menuSize, opened, t } = useAdminMenu();
  const isLarge = menuSize === 'Large';

  const [tab, setTab] = useState<'overview' | 'console' | 'players' | 'events'>('overview');
  const [sessions, setSessions] = useState<SessionEntry[]>([]);
  const [sessionSearch, setSessionSearch] = useState('');
  const [info, setInfo] = useState<ServerInfo | null>(null);
  const [baseUptime, setBaseUptime] = useState<{ ms: number; at: number } | null>(null);
  const [console, setConsole] = useState<ConsoleLine[]>([]);
  const [events, setEvents] = useState<EventEntry[]>([]);
  const [canRun, setCanRun] = useState(false);
  const [command, setCommand] = useState('');
  const [autoScroll, setAutoScroll] = useState(true);
  const [consoleFilter, setConsoleFilter] = useState('');
  const [eventKind, setEventKind] = useState('all');
  const [sessionSort, setSessionSort] = useState<SessionSort>('id');

  const consoleRef = useRef<HTMLDivElement>(null);

  const applySnapshot = useCallback((data: DashboardSnapshot) => {
    if (data.info) {
      setInfo(data.info);
      setBaseUptime({ ms: data.info.uptimeMs || 0, at: Date.now() });
    }
    if (data.console) setConsole(toArray<ConsoleLine>(data.console).slice(-MAX_LINES));
    if (data.events) setEvents(toArray(data.events));
  }, []);

  useEffect(() => {
    let mounted = true;
    fetchNui<DashboardSnapshot | false>('fetchDashboard')
      .then((data) => {
        if (!mounted || !data) return;
        applySnapshot(data);
        setCanRun(!!data.canRunCommands);
      })
      .catch(() => {});
    refreshResources();

    return () => {
      mounted = false;
    };
  }, [applySnapshot, refreshResources]);

  // The server only streams console lines to viewers, so the page unsubscribes while the menu is closed.
  useEffect(() => {
    if (!opened) return;
    fetchNui('subscribeDashboard', { enabled: true }).catch(() => {});
    return () => {
      fetchNui('subscribeDashboard', { enabled: false }).catch(() => {});
    };
  }, [opened]);

  useNuiEvent<DashboardPush>('dashboardPush', (push) => {
    if (push.kind === 'snapshot') applySnapshot(push);
    else if (push.kind === 'console' && push.lines) {
      const lines = toArray<ConsoleLine>(push.lines);
      setConsole((prev) => [...prev, ...lines].slice(-MAX_LINES));
    } else if (push.kind === 'event' && push.event) {
      const entry = push.event;
      setEvents((prev) => [...prev, entry].slice(-60));
    }
  });

  // Sessions are polled only while the Players tab is open.
  useEffect(() => {
    if (tab !== 'players') return;
    let active = true;
    const pull = () => {
      fetchNui<SessionEntry[]>('fetchDashboardSessions')
        .then((data) => {
          if (active) setSessions(toArray(data));
        })
        .catch(() => {});
    };
    pull();
    const id = setInterval(pull, 5000);
    return () => {
      active = false;
      clearInterval(id);
    };
  }, [tab]);

  // Re-renders every 30 seconds so the uptime keeps counting.
  const [, forceTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => forceTick((n) => n + 1), 30000);
    return () => clearInterval(id);
  }, []);
  const liveUptime = baseUptime ? baseUptime.ms + (Date.now() - baseUptime.at) : 0;

  useEffect(() => {
    if (autoScroll && consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight;
    }
  }, [console, autoScroll, tab]);

  const [pendingCommand, setPendingCommand] = useState<string | null>(null);

  const requestRunCommand = () => {
    const cmd = command.trim();
    if (!cmd) return;
    setPendingCommand(cmd);
  };

  const confirmRunCommand = () => {
    if (!pendingCommand) return;
    fetchNui('runConsoleCommand', { command: pendingCommand }).catch(() => {});
    setPendingCommand(null);
    setCommand('');
  };

  const startedCount = useMemo(() => (resources || []).filter((r) => r.State === 'started').length, [resources]);

  const filteredSessions = useMemo(() => {
    const q = sessionSearch.toLowerCase();
    const list = sessions.filter(
      (s) =>
        s.name.toLowerCase().includes(q) || (s.charName || '').toLowerCase().includes(q) || String(s.id).includes(q),
    );
    if (sessionSort === 'name') return list.sort((a, b) => (a.charName || a.name).localeCompare(b.charName || b.name));
    if (sessionSort === 'ping') return list.sort((a, b) => b.ping - a.ping);
    if (sessionSort === 'session') return list.sort((a, b) => b.playSec - a.playSec);
    return list.sort((a, b) => a.id - b.id);
  }, [sessions, sessionSearch, sessionSort]);

  const visibleConsole = useMemo(() => {
    const q = consoleFilter.toLowerCase();
    if (!q) return console;
    return console.filter((line) => line.msg.toLowerCase().includes(q) || line.ch.toLowerCase().includes(q));
  }, [console, consoleFilter]);

  const eventKinds = useMemo(() => [...new Set(events.map((ev) => ev.kind))].sort(), [events]);
  const visibleEvents = useMemo(
    () => [...events].reverse().filter((ev) => eventKind === 'all' || ev.kind === eventKind),
    [events, eventKind],
  );

  const StatCard = ({
    icon,
    label,
    value,
    accent,
  }: {
    icon: string;
    label: string;
    value: React.ReactNode;
    accent?: string;
  }) => (
    <div className="bg-black/20 border border-white/5 rounded-xl p-4 flex items-center gap-4">
      <div
        className={`w-11 h-11 rounded-xl flex items-center justify-center text-lg ${accent || 'bg-accent/10 text-accent'}`}
      >
        <i className={icon}></i>
      </div>
      <div className="min-w-0">
        <div className="text-[10px] uppercase tracking-[0.2em] font-black text-muted">{label}</div>
        <div className="text-primary font-rajdhani font-bold text-xl tracking-wide truncate">{value}</div>
      </div>
    </div>
  );

  return (
    <div className="flex flex-col h-full w-full">
      {/* Header */}
      <div className="p-6 pb-2">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <i className="fa-solid fa-server text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {info?.txName || t('ui.tabs.txadmin')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
                {info ? `${info.serverMode} · fx ${info.fxVersion}` : t('ui.pages.dashboard.subtitle')}
              </p>
            </div>
          </div>
          <button
            onClick={() => {
              // Re-subscribing makes the server send a fresh snapshot.
              fetchNui('subscribeDashboard', { enabled: true }).catch(() => {});
              refreshResources();
            }}
            className="bg-accent hover:bg-accent/80 text-white px-4 py-2 rounded-lg font-rajdhani font-bold tracking-wider uppercase transition-all duration-300 flex items-center gap-2 "
          >
            <i className="fa-solid fa-rotate"></i>
            {isLarge && t('ui.pages.resources.refresh_btn')}
          </button>
        </div>

        <div className="border-b border-white/10 pb-4 mb-4">
          <SubTabs
            tabs={[
              { id: 'overview', label: t('ui.pages.dashboard.tabs.overview'), icon: 'fa-solid fa-gauge-high' },
              { id: 'console', label: t('ui.pages.dashboard.tabs.console'), icon: 'fa-solid fa-terminal' },
              { id: 'players', label: t('ui.pages.dashboard.tabs.players'), icon: 'fa-solid fa-users' },
              { id: 'events', label: t('ui.pages.dashboard.tabs.events'), icon: 'fa-solid fa-bell' },
            ]}
            activeTab={tab}
            onChange={setTab}
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar">
        {tab === 'overview' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <StatCard
              icon="fa-solid fa-users"
              label={t('ui.pages.dashboard.players_online')}
              value={info ? `${info.players} / ${info.maxPlayers}` : '-'}
              accent="bg-green-500/10 text-green-400"
            />
            <StatCard
              icon="fa-solid fa-clock"
              label={t('ui.pages.dashboard.uptime')}
              value={info ? formatUptime(liveUptime) : '-'}
              accent="bg-blue-500/10 text-blue-400"
            />
            <StatCard
              icon="fa-solid fa-cubes"
              label={t('ui.pages.dashboard.resources_started')}
              value={resources ? `${startedCount} / ${resources.length}` : '-'}
            />
            <StatCard
              icon="fa-solid fa-arrows-rotate"
              label={t('ui.pages.dashboard.next_restart')}
              value={
                info?.nextRestart?.minutes != null
                  ? t('ui.pages.dashboard.restart_in', String(info.nextRestart.minutes))
                  : t('ui.pages.dashboard.not_scheduled')
              }
              accent="bg-amber-500/10 text-amber-400"
            />
            <div className="md:col-span-2">
              <StatCard icon="fa-solid fa-signal" label={t('ui.pages.dashboard.hostname')} value={info?.hostname || '-'} />
            </div>
            <div className="md:col-span-2 bg-black/20 border border-white/5 rounded-xl p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <i className="fa-brands fa-fort-awesome text-accent text-lg"></i>
                <span className="text-muted text-xs uppercase tracking-widest font-bold">txAdmin</span>
              </div>
              <span className="text-primary font-mono text-sm">v{info?.txVersion || 'n/a'}</span>
            </div>
          </div>
        )}

        {tab === 'console' && (
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between gap-3 mb-2">
              <SearchField
                className="flex-1 max-w-sm"
                value={consoleFilter}
                onChange={setConsoleFilter}
                placeholder={t('ui.pages.dashboard.filter_console')}
              />
              <p className="text-[10px] uppercase tracking-widest text-muted font-bold">
                <i className="fa-solid fa-circle-info mr-1"></i>
                {t('ui.pages.dashboard.console_note')}
              </p>
              <button
                onClick={() => setAutoScroll((v) => !v)}
                className={`text-[10px] uppercase tracking-widest font-black px-3 py-1.5 rounded-lg transition-all ${autoScroll ? 'bg-accent/20 text-accent' : 'bg-white/5 text-muted hover:text-primary'}`}
              >
                <i className="fa-solid fa-angles-down mr-1"></i>
                {t('ui.pages.dashboard.autoscroll')}
              </button>
            </div>
            <div
              ref={consoleRef}
              className="flex-1 min-h-[280px] max-h-[52vh] overflow-y-auto bg-black/50 border border-white/10 rounded-xl p-4 font-mono text-xs leading-relaxed custom-scrollbar"
            >
              {visibleConsole.length === 0 ? (
                <div className="text-muted/50 h-full flex items-center justify-center">
                  {consoleFilter ? t('ui.pages.dashboard.no_console_matches') : t('ui.pages.dashboard.waiting_console')}
                </div>
              ) : (
                visibleConsole.map((line) => (
                  <div
                    key={line.id}
                    className="whitespace-pre-wrap break-words text-white/80 hover:bg-white/5 px-1 -mx-1 rounded"
                  >
                    <span className="text-accent/60 mr-2 select-none">[{line.ch}]</span>
                    {line.msg}
                  </div>
                ))
              )}
            </div>
            {canRun && (
              <div className="mt-3">
                {pendingCommand === null ? (
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <i className="fa-solid fa-chevron-right absolute left-3 top-1/2 -translate-y-1/2 text-accent text-xs"></i>
                      <input
                        type="text"
                        value={command}
                        onChange={(e) => setCommand(e.target.value)}
                        onKeyDown={(e) => e.key === 'Enter' && requestRunCommand()}
                        placeholder={t('ui.pages.dashboard.command_placeholder')}
                        className="w-full bg-black/50 border border-white/10 rounded-xl py-2.5 pl-9 pr-4 text-primary font-mono text-sm focus:outline-none focus:border-accent/50 transition-all"
                      />
                    </div>
                    <button
                      onClick={requestRunCommand}
                      className="bg-accent hover:bg-accent/80 text-white px-5 rounded-xl font-rajdhani font-bold uppercase tracking-wider transition-all flex items-center gap-2"
                    >
                      <i className="fa-solid fa-paper-plane"></i>
                      {isLarge && t('ui.pages.dashboard.send')}
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 bg-red-500/10 border border-red-500/20 rounded-xl p-2.5 animate-in zoom-in-95 duration-200">
                    <i className="fa-solid fa-triangle-exclamation text-red-500 text-xs ml-1"></i>
                    <span className="flex-1 font-mono text-xs text-white truncate">
                      {t('ui.pages.dashboard.run_confirm')}{' '}
                      <span className="text-red-400 font-bold">{pendingCommand}</span>
                    </span>
                    <button
                      onClick={() => setPendingCommand(null)}
                      className="px-3 py-1.5 bg-white/10 text-white rounded-lg text-[10px] uppercase font-bold tracking-wider hover:bg-white/20 transition-all"
                    >
                      {t('common.cancel')}
                    </button>
                    <button
                      onClick={confirmRunCommand}
                      className="px-3 py-1.5 bg-red-600 text-white rounded-lg text-[10px] uppercase font-bold tracking-wider hover:bg-red-700 transition-all"
                    >
                      {t('ui.pages.dashboard.confirm')}
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {tab === 'players' && (
          <div>
            <div className="flex items-center justify-between mb-4 gap-3">
              <SearchField
                className="flex-1"
                value={sessionSearch}
                onChange={setSessionSearch}
                placeholder={t('ui.pages.dashboard.search_sessions')}
              />
              <SortSelect
                value={sessionSort}
                onChange={setSessionSort}
                options={[
                  { id: 'id', label: t('ui.pages.players.sort_id') },
                  { id: 'name', label: t('ui.pages.players.sort_name') },
                  { id: 'ping', label: t('ui.pages.players.sort_ping') },
                  { id: 'session', label: t('ui.pages.dashboard.sort_session') },
                ]}
              />
              <span className="text-[10px] uppercase tracking-widest text-muted font-black whitespace-nowrap">
                {t('ui.pages.dashboard.online_count', String(sessions.length))}
              </span>
            </div>
            <div className="grid grid-cols-1 gap-2">
              {filteredSessions.map((s) => (
                <div
                  key={s.id}
                  className="bg-black/20 border border-white/5 rounded-xl p-3.5 flex items-center justify-between hover:bg-white/5 transition-all"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-9 h-9 rounded-lg bg-accent/10 text-accent flex items-center justify-center font-rajdhani font-black text-sm shrink-0">
                      {s.id}
                    </div>
                    <div className="min-w-0">
                      <div className="text-primary font-rajdhani font-bold tracking-wide truncate">
                        {s.charName || s.name}
                      </div>
                      <div className="text-[10px] uppercase tracking-widest text-muted font-bold truncate">
                        {s.charName ? s.name : `ID ${s.id}`}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-5 shrink-0">
                    <div className="text-right">
                      <div className={`font-mono text-sm font-bold ${pingColor(s.ping)}`}>{s.ping}ms</div>
                      <div className="text-[9px] uppercase tracking-widest text-muted font-bold">
                        {t('ui.pages.dashboard.ping')}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-primary font-mono text-sm font-bold">{formatDuration(s.playSec)}</div>
                      <div className="text-[9px] uppercase tracking-widest text-muted font-bold">
                        {t('ui.pages.dashboard.session')}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
              {filteredSessions.length === 0 && (
                <div className="flex flex-col items-center justify-center py-16 text-muted">
                  <i className="fa-solid fa-user-slash text-4xl mb-4 opacity-20"></i>
                  <p className="font-rajdhani font-bold uppercase tracking-widest">
                    {sessionSearch ? t('ui.pages.players.no_results') : t('ui.pages.dashboard.no_players')}
                  </p>
                </div>
              )}
            </div>
          </div>
        )}

        {tab === 'events' && (
          <div className="grid grid-cols-1 gap-2">
            {eventKinds.length > 1 && (
              <SubTabs
                tabs={[
                  { id: 'all', label: t('ui.pages.dashboard.all_events') },
                  ...eventKinds.map((kind) => ({ id: kind, label: kind })),
                ]}
                activeTab={eventKind}
                onChange={setEventKind}
                className="mb-2"
                tabClassName="py-1.5"
              />
            )}
            {visibleEvents.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 text-muted">
                <i className="fa-solid fa-bell-slash text-4xl mb-4 opacity-20"></i>
                <p className="font-rajdhani font-bold uppercase tracking-widest">{t('ui.pages.dashboard.no_events')}</p>
                <p className="text-xs mt-1">{t('ui.pages.dashboard.no_events_desc')}</p>
              </div>
            ) : (
              visibleEvents.map((ev) => {
                const s = kindStyles[ev.kind] || { icon: 'fa-solid fa-circle-info', color: 'text-muted' };
                return (
                  <div
                    key={ev.id}
                    className="bg-black/20 border border-white/5 rounded-xl p-3.5 flex items-center gap-3"
                  >
                    <div className={`w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center ${s.color}`}>
                      <i className={`${s.icon} text-sm`}></i>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-primary font-barlow text-sm truncate">{ev.label}</div>
                      <div className="text-[10px] uppercase tracking-widest text-muted font-bold">{ev.kind}</div>
                    </div>
                    <div className="text-[10px] text-muted font-mono">
                      {new Date(ev.time * 1000).toLocaleTimeString()}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default TxAdminPage;
