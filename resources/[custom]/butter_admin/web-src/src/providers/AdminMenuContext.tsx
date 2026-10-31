import React, { createContext, useContext, useState, useCallback, useRef, useEffect, useMemo } from 'react';
import {
  CommandCategory,
  Player,
  BannedPlayer,
  LogEntry,
  Report,
  ChatMessage,
  MenuOptions,
  PageName,
  MenuSize,
  AdminMenuOpenData,
  Rank,
  AdminUser,
  Resource,
  PermissionCategory,
  DiscordRole,
  Character,
  Garage,
  PlayerVehicle,
  Property,
  EconomyStats,
  Job,
  Gang,
  DirectMessage,
  DropdownState,
  PlayersResponse,
  LogsResponse,
  VehiclesResponse,
  VehicleStateCounts,
  PropertiesResponse,
  CurrentTarget,
  Translate,
} from '../types';
import { fetchNui } from '../utils/fetchNui';
import { setDebugEnabled } from '../utils/debug';
import { useNuiEvent } from '../hooks/useNuiEvent';
import {
  applyCustomThemeVars,
  clearCustomThemeVars,
  getSavedCustomThemes,
} from '../components/pages/OptionsPage/CustomThemeEditor';
import { applyFont, getSavedFont, applyFontScale, getFontScale } from '../utils/fonts';

/** Lua sends empty tables as {} or [], and keyed tables as objects; this always yields an array. */
export function toArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[];
  if (value && typeof value === 'object') return Object.values(value) as T[];
  return [];
}

/** An object, or {} for anything else (Lua sends empty tables as []). */
export function toRecord<T = unknown>(value: unknown): Record<string, T> {
  if (value && typeof value === 'object' && !Array.isArray(value)) return value as Record<string, T>;
  return {};
}

export type DataRequest =
  'bans' | 'logs' | 'players' | 'garages' | 'vehicles' | 'properties' | 'economy' | 'jobs' | 'gangs';

interface AdminMenuContextValue {
  opened: boolean;
  menuSize: MenuSize;
  selectedPage: PageName;
  commands: CommandCategory[];
  players: Player[];
  bans: BannedPlayer[];
  logs: LogEntry[];
  logsTotal: number;
  favoritedItems: Record<string, boolean>;
  pinnedTargets: Record<string, boolean>;
  enabledItems: Record<string, boolean>;
  options: MenuOptions;
  currentTarget: CurrentTarget | null;
  myName: string;
  myId: number | null;
  pages: Record<string, boolean>;
  playerNameFormat: string;
  licenseType: string;
  admins: AdminUser[];
  ranks: Rank[];
  resources: Resource[];
  dbPlayers: Player[];
  disconnectedPlayers: Player[];
  availablePermissions: PermissionCategory[];
  playerNotes: Record<string, string>;
  banNotes: Record<string, string>;
  theme: string;
  font: string;
  pinnedVisible: boolean;
  discordRoles: DiscordRole[];
  discordLogsEnabled: boolean;
  characters: Character[];
  dmHistories: Record<number, DirectMessage[]>;
  garages: Garage[];
  vehicles: PlayerVehicle[];
  properties: Property[];
  economy: EconomyStats | null;
  jobs: Job[];
  gangs: Gang[];
  dbPlayersTotal: number;
  vehiclesTotal: number;
  vehicleStateCounts: VehicleStateCounts;
  propertiesTotal: number;
  t: Translate;

  playerReportMode: boolean;
  playerDMMode: boolean;
  lastAdminId: number | null;

  setSelectedPage: (page: PageName) => void;
  setCurrentTarget: (target: CurrentTarget | null) => void;
  setOpened: (opened: boolean) => void;
  setTheme: (theme: string) => void;
  setFont: (font: string) => void;
  setPinnedVisible: (visible: boolean) => void;
  setPlayerDMMode: (visible: boolean) => void;
  setLastAdminId: (id: number | null) => void;
  setRanks: React.Dispatch<React.SetStateAction<Rank[]>>;
  setAdmins: React.Dispatch<React.SetStateAction<AdminUser[]>>;
  setOptions: React.Dispatch<React.SetStateAction<MenuOptions>>;
  setVehicles: React.Dispatch<React.SetStateAction<PlayerVehicle[]>>;
  setBans: React.Dispatch<React.SetStateAction<BannedPlayer[]>>;
  setPlayerReportMode: React.Dispatch<React.SetStateAction<boolean>>;
  setActiveReport: React.Dispatch<React.SetStateAction<Report | null>>;
  setDbPlayers: React.Dispatch<React.SetStateAction<Player[]>>;
  setDiscordRoles: React.Dispatch<React.SetStateAction<DiscordRole[]>>;
  setDiscordLogsEnabled: React.Dispatch<React.SetStateAction<boolean>>;
  setCharacters: React.Dispatch<React.SetStateAction<Character[]>>;
  setAvailablePermissions: React.Dispatch<React.SetStateAction<PermissionCategory[]>>;
  addDM: (targetId: number, message: DirectMessage) => void;

  checkmarkVisible: boolean;
  crossmarkVisible: boolean;
  dropdown: DropdownState | null;
  setDropdown: React.Dispatch<React.SetStateAction<DropdownState | null>>;

  openMenu: (data: AdminMenuOpenData) => void;
  closeMenu: () => void;
  updateMenu: (data: AdminMenuOpenData) => void;
  updatePlayerReport: (data: { ReportData: Report }) => void;
  requestData: (name: DataRequest, params?: Record<string, unknown>) => Promise<void>;
  toggleFavorite: (id: string, toggle: boolean) => void;
  togglePinnedTarget: (identifier: string, toggle: boolean) => void;
  showCheckmark: (timeout?: number) => void;
  showCrossmark: (timeout?: number) => void;
  changeSize: (forceSize?: MenuSize) => void;
  refreshResources: () => void;
  setPlayerNote: (identifier: string, note: string) => void;
  setBanNote: (banId: string, note: string) => void;
}

const AdminMenuContext = createContext<AdminMenuContextValue | null>(null);

/**
 * Reports and staff chat change on every message, so they live in their own
 * context: a new message re-renders the chat views, not every consumer of the
 * large menu context.
 */
interface ChatContextValue {
  reports: Report[];
  staffchat: ChatMessage[];
  activeReport: Report | null;
}

const ChatContext = createContext<ChatContextValue | null>(null);

const DEFAULT_OPTIONS: MenuOptions = {
  LargeDefault: false,
  BindOpen: false,
  Tooltips: false,
  Resizer: false,
  ReportsMuted: false,
};

export const AdminMenuProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [opened, setOpened] = useState(false);
  const [menuSize, setMenuSize] = useState<MenuSize>('Small');
  const [selectedPage, setSelectedPage] = useState<PageName>('Commands');
  const [commands, setCommands] = useState<CommandCategory[]>([]);
  const [playerNameFormat, setPlayerNameFormat] = useState('Both');
  const [licenseType, setLicenseType] = useState('PrimaryId');
  const [players, setPlayers] = useState<Player[]>([]);
  const [bans, setBans] = useState<BannedPlayer[]>([]);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [logsTotal, setLogsTotal] = useState(0);
  const [reports, setReports] = useState<Report[]>([]);
  const [staffchat, setStaffchat] = useState<ChatMessage[]>([]);
  const [favoritedItems, setFavoritedItems] = useState<Record<string, boolean>>({});
  const [pinnedTargets, setPinnedTargets] = useState<Record<string, boolean>>({});
  const [enabledItems, setEnabledItems] = useState<Record<string, boolean>>({});
  // Tooltips is a per-client choice kept in localStorage, not in the game's KVP.
  const [options, setOptions] = useState<MenuOptions>(() => ({
    ...DEFAULT_OPTIONS,
    Tooltips: localStorage.getItem('adminMenuTooltips') === 'true',
  }));
  const [currentTarget, setCurrentTarget] = useState<CurrentTarget | null>(null);
  const [myName, setMyName] = useState('');
  const [myId, setMyId] = useState<number | null>(null);
  const [pages, setPages] = useState<Record<string, boolean>>({});
  const [checkmarkVisible, setCheckmarkVisible] = useState(false);
  const [crossmarkVisible, setCrossmarkVisible] = useState(false);
  const [dropdown, setDropdown] = useState<DropdownState | null>(null);
  const [playerReportMode, setPlayerReportMode] = useState(false);
  const [playerDMMode, setPlayerDMMode] = useState(false);
  const [activeReport, setActiveReport] = useState<Report | null>(null);
  const [lastAdminId, setLastAdminId] = useState<number | null>(null);
  const [ranks, setRanks] = useState<Rank[]>([]);
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [resources, setResources] = useState<Resource[]>([]);
  const [dbPlayers, setDbPlayers] = useState<Player[]>([]);
  const [disconnectedPlayers, setDisconnectedPlayers] = useState<Player[]>([]);
  const [playerNotes, setPlayerNotes] = useState<Record<string, string>>({});
  const [banNotes, setBanNotes] = useState<Record<string, string>>({});
  const [availablePermissions, setAvailablePermissions] = useState<PermissionCategory[]>([]);
  const [pinnedVisible, setPinnedVisible] = useState(false);
  const [theme, setTheme] = useState<string>(() => localStorage.getItem('adminMenuTheme') || 'Dark');
  const [font, setFont] = useState<string>(() => getSavedFont());
  const [discordRoles, setDiscordRoles] = useState<DiscordRole[]>([]);
  const [discordLogsEnabled, setDiscordLogsEnabled] = useState(true);
  const [characters, setCharacters] = useState<Character[]>([]);
  const [dmHistories, setDmHistories] = useState<Record<number, DirectMessage[]>>({});
  const [locales, setLocales] = useState<Record<string, unknown>>({});
  const [garages, setGarages] = useState<Garage[]>([]);
  const [vehicles, setVehicles] = useState<PlayerVehicle[]>([]);
  const [properties, setProperties] = useState<Property[]>([]);
  const [economy, setEconomy] = useState<EconomyStats | null>(null);
  const [jobs, setJobs] = useState<Job[]>([]);
  const [gangs, setGangs] = useState<Gang[]>([]);
  const [dbPlayersTotal, setDbPlayersTotal] = useState(0);
  const [vehiclesTotal, setVehiclesTotal] = useState(0);
  const [vehicleStateCounts, setVehicleStateCounts] = useState<VehicleStateCounts>({});
  const [propertiesTotal, setPropertiesTotal] = useState(0);

  useEffect(() => {
    localStorage.setItem('adminMenuTooltips', String(options.Tooltips));
  }, [options.Tooltips]);

  useEffect(() => {
    localStorage.setItem('adminMenuTheme', theme);
    document.documentElement.setAttribute('data-theme', theme);

    const custom = theme.startsWith('custom_') ? getSavedCustomThemes().find((saved) => saved.id === theme) : undefined;
    if (custom) applyCustomThemeVars(custom.bg, custom.accent, custom.sidebar);
    else clearCustomThemeVars();
  }, [theme]);

  useEffect(() => {
    localStorage.setItem('adminMenuFont', font);
    applyFont(font);
  }, [font]);

  // The font-size slider updates this live; the saved value applies on mount.
  useEffect(() => {
    applyFontScale(getFontScale());
  }, []);

  useEffect(() => {
    if (options.ReportsMuted !== undefined)
      fetchNui('setReportsMuted', { muted: options.ReportsMuted }).catch(() => {});
  }, [options.ReportsMuted]);

  const addDM = useCallback((targetId: number, message: DirectMessage) => {
    setDmHistories((previous) => ({ ...previous, [targetId]: [...(previous[targetId] || []), message] }));
  }, []);

  const t = useCallback(
    (path: string, ...args: unknown[]) => {
      let value: unknown = locales;
      for (const key of path.split('.')) {
        if (!value || typeof value !== 'object' || !(key in value)) return path;
        value = (value as Record<string, unknown>)[key];
      }
      if (typeof value !== 'string') return path;
      return args.reduce<string>((text, arg) => text.replace('%s', String(arg)), value);
    },
    [locales],
  );

  const checkmarkTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const crossmarkTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const showCheckmark = useCallback((timeout = 2000) => {
    setCheckmarkVisible(true);
    clearTimeout(checkmarkTimer.current);
    checkmarkTimer.current = setTimeout(() => setCheckmarkVisible(false), timeout);
  }, []);

  const showCrossmark = useCallback((timeout = 2000) => {
    setCrossmarkVisible(true);
    clearTimeout(crossmarkTimer.current);
    crossmarkTimer.current = setTimeout(() => setCrossmarkVisible(false), timeout);
  }, []);

  const changeSize = useCallback((forceSize?: MenuSize) => {
    setMenuSize((previous) => forceSize ?? (previous === 'Small' ? 'Large' : 'Small'));
  }, []);

  const applyData = useCallback((data: AdminMenuOpenData) => {
    if (data.Debug !== undefined) setDebugEnabled(!!data.Debug);
    if (data.Favorited) setFavoritedItems(toRecord<boolean>(data.Favorited));
    if (data.PinnedPlayers) setPinnedTargets(toRecord<boolean>(data.PinnedPlayers));
    if (data.MenuOptions) {
      const menuOptions = data.MenuOptions;
      setOptions((previous) => ({ ...previous, ...menuOptions, Tooltips: previous.Tooltips }));
      if (menuOptions.Theme) setTheme(menuOptions.Theme);
      if (menuOptions.CustomThemes)
        localStorage.setItem('adminMenuCustomThemes', JSON.stringify(menuOptions.CustomThemes));
      if (menuOptions.Font) setFont(menuOptions.Font);
    }
    if (data.Commands) setCommands(toArray(data.Commands));
    if (data.Reports) setReports(toArray(data.Reports));
    if (data.Staffchat) setStaffchat(toArray(data.Staffchat));
    if (data.Name || data.MyName) setMyName(data.Name || data.MyName || '');
    if (data.MyId) setMyId(data.MyId);
    if (data.Pages) setPages(toRecord<boolean>(data.Pages));
    if (data.Ranks) setRanks(toArray(data.Ranks));
    if (data.Admins) setAdmins(toArray(data.Admins));
    if (data.Resources) setResources(toArray(data.Resources));
    if (data.EnabledItems) setEnabledItems(toRecord<boolean>(data.EnabledItems));
    if (data.AvailablePermissions) setAvailablePermissions(toArray(data.AvailablePermissions));
    if (data.OnlinePlayers) {
      // Keyed by server ID so a player can never be listed twice.
      const unique = new Map(toArray<Player>(data.OnlinePlayers).map((player) => [player.ServerId, player]));
      setPlayers([...unique.values()]);
    }
    if (data.DisconnectedPlayers) setDisconnectedPlayers(toArray(data.DisconnectedPlayers));
    if (data.DiscordRoles) setDiscordRoles(toArray(data.DiscordRoles));
    if (data.DiscordLogsEnabled !== undefined) setDiscordLogsEnabled(!!data.DiscordLogsEnabled);
    if (data.Characters) setCharacters(toArray(data.Characters));
    if (data.Locales) setLocales(toRecord(data.Locales));
    if (data.PlayerNotes) setPlayerNotes(toRecord<string>(data.PlayerNotes));
    if (data.PlayerName) setPlayerNameFormat(data.PlayerName);
    if (data.LicenseType) setLicenseType(data.LicenseType);
    // Development mock data only; in-game these come through requestData.
    if (data.Bans) setBans(toArray(data.Bans));
    if (data.Logs) setLogs(toArray(data.Logs));
    if (data.DbPlayers) setDbPlayers(toArray(data.DbPlayers));
    if (data.DbPlayersTotal !== undefined) setDbPlayersTotal(Number(data.DbPlayersTotal));
  }, []);

  const openMenu = useCallback(
    (data: AdminMenuOpenData) => {
      applyData(data);
      setPlayerReportMode(false);
      setPlayerDMMode(false);
      setActiveReport(null);
      setOpened(true);
      setMenuSize(data.MenuOptions?.LargeDefault ? 'Large' : 'Small');
    },
    [applyData],
  );

  const openPlayerReport = useCallback(
    (data: AdminMenuOpenData) => {
      applyData(data);
      setPlayerDMMode(false);
      setPlayerReportMode(true);
      setActiveReport(data.ReportData ?? null);
      setOpened(true);
    },
    [applyData],
  );

  const closeMenu = useCallback(() => {
    fetchNui(playerReportMode ? 'closePlayerReport' : 'closeMenu').catch(() => {});
    setOpened(false);
    setPlayerReportMode(false);
    setPlayerDMMode(false);
    setActiveReport(null);
    setDropdown(null);
  }, [playerReportMode]);

  const updateChats = useCallback((data: { Staffchat?: ChatMessage[]; Reports?: Report[] }) => {
    if (data.Staffchat) setStaffchat(toArray(data.Staffchat));
    if (!data.Reports) return;

    const nextReports = toArray<Report>(data.Reports);
    setReports(nextReports);
    setActiveReport((previous) =>
      previous ? (nextReports.find((report) => report.Id === previous.Id) ?? null) : null,
    );
  }, []);

  const updateReportTyping = useCallback((data: { ReportId: number; TypingAdmins: string[] }) => {
    const typingAdmins = toArray<string>(data.TypingAdmins);
    setReports((previous) =>
      previous.map((report) => (report.Id === data.ReportId ? { ...report, TypingAdmins: typingAdmins } : report)),
    );
    setActiveReport((previous) =>
      previous && previous.Id === data.ReportId ? { ...previous, TypingAdmins: typingAdmins } : previous,
    );
  }, []);

  // Data sync only: it must not pull a player who moved to the admin menu back to the report screen.
  const updatePlayerReport = useCallback((data: { ReportData: Report }) => {
    setActiveReport(data.ReportData);
  }, []);

  const setItemEnabled = useCallback((data: { Name: string; State: boolean }) => {
    if (typeof data.Name === 'string') setEnabledItems((previous) => ({ ...previous, [data.Name]: !!data.State }));
  }, []);

  const toggleFavorite = useCallback((id: string, toggle: boolean) => {
    setFavoritedItems((previous) => ({ ...previous, [id]: toggle }));
    fetchNui('setPreference', { type: 'favorites', key: id, value: toggle }).catch(() => {});
  }, []);

  const togglePinnedTarget = useCallback((identifier: string, toggle: boolean) => {
    setPinnedTargets((previous) => ({ ...previous, [identifier]: toggle }));
    fetchNui('setPreference', { type: 'pinned', key: identifier, value: toggle }).catch(() => {});
  }, []);

  const refreshResources = useCallback(() => {
    fetchNui<Resource[]>('fetchResources')
      .then((list) => setResources(toArray(list)))
      .catch(() => {});
  }, []);

  const setPlayerNote = useCallback((identifier: string, note: string) => {
    setPlayerNotes((previous) => ({ ...previous, [identifier]: note }));
  }, []);

  const setBanNote = useCallback((banId: string, note: string) => {
    setBanNotes((previous) => ({ ...previous, [banId]: note }));
  }, []);

  /** Loads a dataset for a page and stores it in the shared state. */
  const requestData = useCallback(async (name: DataRequest, params?: Record<string, unknown>) => {
    switch (name) {
      case 'bans':
        setBans(toArray(await fetchNui('fetchBans')));
        break;
      case 'logs': {
        const result = await fetchNui<LogsResponse | false>('fetchLogs', params);
        if (!result) return;
        setLogs(toArray(result.Logs));
        setLogsTotal(Number(result.TotalCount) || 0);
        break;
      }
      case 'players': {
        const result = await fetchNui<PlayersResponse | false>('fetchPlayers', params);
        if (!result) return;
        setPlayers(toArray(result.Online));
        setDbPlayers(toArray(result.All));
        setDisconnectedPlayers(toArray(result.Disconnected));
        setDbPlayersTotal(Number(result.TotalCount) || 0);
        break;
      }
      case 'garages':
        setGarages(toArray(await fetchNui('fetchGarages')));
        break;
      case 'vehicles': {
        const result = await fetchNui<VehiclesResponse | false>('fetchVehicles', params);
        if (!result) return;
        setVehicles(toArray(result.Vehicles));
        setVehiclesTotal(Number(result.TotalCount) || 0);
        setVehicleStateCounts(result.StateCounts ?? {});
        break;
      }
      case 'properties': {
        const result = await fetchNui<PropertiesResponse | false>('fetchProperties', params);
        if (!result) return;
        setProperties(toArray(result.Properties));
        setPropertiesTotal(Number(result.TotalCount) || 0);
        break;
      }
      case 'economy':
        setEconomy((await fetchNui<EconomyStats | false>('fetchEconomy')) || null);
        break;
      case 'jobs':
        setJobs(toArray(await fetchNui('fetchJobs')));
        break;
      case 'gangs':
        setGangs(toArray(await fetchNui('fetchGangs')));
        break;
    }
  }, []);

  useNuiEvent<AdminMenuOpenData>('openMenu', openMenu);
  useNuiEvent<AdminMenuOpenData>('openPlayerReport', openPlayerReport);
  useNuiEvent<AdminMenuOpenData>('updateMenu', applyData);
  useNuiEvent('updateChats', updateChats);
  useNuiEvent('setItemEnabled', setItemEnabled);
  useNuiEvent('updatePlayerReport', updatePlayerReport);
  useNuiEvent('reportTyping', updateReportTyping);

  const contextValue = useMemo(
    () => ({
      opened,
      menuSize,
      selectedPage,
      commands,
      players,
      bans,
      logs,
      logsTotal,
      favoritedItems,
      pinnedTargets,
      enabledItems,
      options,
      currentTarget,
      myName,
      myId,
      pages,
      playerNameFormat,
      licenseType,
      ranks,
      admins,
      resources,
      dbPlayers,
      disconnectedPlayers,
      garages,
      vehicles,
      properties,
      economy,
      jobs,
      gangs,
      availablePermissions,
      playerNotes,
      banNotes,
      theme,
      font,
      pinnedVisible,
      discordRoles,
      discordLogsEnabled,
      characters,
      dbPlayersTotal,
      vehiclesTotal,
      vehicleStateCounts,
      propertiesTotal,
      playerReportMode,
      playerDMMode,
      lastAdminId,
      dmHistories,
      t,
      checkmarkVisible,
      crossmarkVisible,
      dropdown,
      setDropdown,
      setSelectedPage,
      setCurrentTarget,
      setOpened,
      setTheme,
      setFont,
      setPinnedVisible,
      setPlayerReportMode,
      setPlayerDMMode,
      setLastAdminId,
      setRanks,
      setAdmins,
      setOptions,
      setDbPlayers,
      setVehicles,
      setDiscordRoles,
      setDiscordLogsEnabled,
      setCharacters,
      setAvailablePermissions,
      setBans,
      setActiveReport,
      openMenu,
      closeMenu,
      updateMenu: applyData,
      updatePlayerReport,
      requestData,
      toggleFavorite,
      togglePinnedTarget,
      showCheckmark,
      showCrossmark,
      changeSize,
      refreshResources,
      setPlayerNote,
      setBanNote,
      addDM,
    }),
    [
      opened,
      menuSize,
      selectedPage,
      commands,
      players,
      bans,
      logs,
      logsTotal,
      favoritedItems,
      pinnedTargets,
      enabledItems,
      options,
      currentTarget,
      myName,
      myId,
      pages,
      playerNameFormat,
      licenseType,
      ranks,
      admins,
      resources,
      dbPlayers,
      disconnectedPlayers,
      garages,
      vehicles,
      properties,
      economy,
      jobs,
      gangs,
      availablePermissions,
      playerNotes,
      banNotes,
      theme,
      font,
      pinnedVisible,
      discordRoles,
      discordLogsEnabled,
      characters,
      dbPlayersTotal,
      vehiclesTotal,
      vehicleStateCounts,
      propertiesTotal,
      playerReportMode,
      playerDMMode,
      lastAdminId,
      dmHistories,
      t,
      checkmarkVisible,
      crossmarkVisible,
      dropdown,
      openMenu,
      closeMenu,
      applyData,
      updatePlayerReport,
      requestData,
      toggleFavorite,
      togglePinnedTarget,
      showCheckmark,
      showCrossmark,
      changeSize,
      refreshResources,
      setPlayerNote,
      setBanNote,
      addDM,
    ],
  );

  const chatValue = useMemo(() => ({ reports, staffchat, activeReport }), [reports, staffchat, activeReport]);

  return (
    <AdminMenuContext.Provider value={contextValue}>
      <ChatContext.Provider value={chatValue}>{children}</ChatContext.Provider>
    </AdminMenuContext.Provider>
  );
};

export const useAdminMenu = () => {
  const context = useContext(AdminMenuContext);
  if (!context) throw new Error('useAdminMenu must be used within AdminMenuProvider');
  return context;
};

/** Reports, staff chat and the player's open report (see ChatContext). */
export const useChats = () => {
  const context = useContext(ChatContext);
  if (!context) throw new Error('useChats must be used within AdminMenuProvider');
  return context;
};
