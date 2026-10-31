// Browser development only: answers NUI callbacks the way the client would.
import { DropdownChoice, Player, PlayerProfile, Resource } from '../types';
import {
  MOCK_DB_PLAYERS_ALL,
  MOCK_VEHICLES_ALL,
  MOCK_PROPERTIES_ALL,
  MOCK_GARAGES_ALL,
  generateMockEconomy,
  generateMockJobs,
  generateMockGangs,
  getMockInventoriesByType,
  getMockInventoryItems,
  getOnlineMockPlayers,
  paginateByPage,
  paginateByOffset,
  filterProperties,
} from './mockDatabase';
import {
  MOCK_ADMINS,
  MOCK_AVAILABLE_PERMISSIONS,
  MOCK_BANS,
  MOCK_CHARACTERS,
  MOCK_DISCORD_ROLES,
  MOCK_ITEMS,
  MOCK_LOGS,
  MOCK_PLAYERS,
  MOCK_RANKS,
} from './mockData';

type Payload = Record<string, unknown> | undefined;

const MOCK_RESOURCES: Resource[] = [
  { Name: 'ox_lib', State: 'started' },
  { Name: 'oxmysql', State: 'started' },
  { Name: 'qbx_core', State: 'started' },
  { Name: 'ox_inventory', State: 'started' },
  { Name: 'qb-core', State: 'stopped' },
  { Name: 'chat', State: 'started' },
  { Name: 'spawnmanager', State: 'started' },
  { Name: 'sessionmanager', State: 'started' },
  { Name: 'hardcap', State: 'started' },
  { Name: 'baseevents', State: 'started' },
  { Name: 'mapmanager', State: 'started' },
  { Name: 'butter_admin', State: 'started' },
];

const readNumber = (data: Payload, key: string, fallback: number) => Number(data?.[key]) || fallback;
const readString = (data: Payload, key: string, fallback = '') => String(data?.[key] ?? fallback);

function matchesSearch(text: string, query: string): boolean {
  if (!query) return true;
  return text.toLowerCase().includes(query.toLowerCase());
}

function matchesPlayer(player: Player, query: string): boolean {
  return [player.Name, player.CitizenId, player.License, player.Steam].some((value) =>
    matchesSearch(value ?? '', query),
  );
}

function buildProfile(id: string): PlayerProfile | false {
  const player = [...MOCK_PLAYERS, ...MOCK_DB_PLAYERS_ALL].find(
    (entry) => entry.CitizenId === id || entry.License === id || String(entry.ServerId) === id,
  );
  if (!player) return false;

  return {
    ...player,
    CharName: player.Name,
    Discord: player.Discord ?? 'discord:123456789012345678',
    HardwareId: player.HardwareId ?? 'license2:1234567890abcdef',
    IP: player.IP ?? '127.0.0.1',
    isOnline: player.isOnline ?? player.ServerId > 0,
    Health: 175,
    Armor: 50,
    Ping: 42,
    Radio: 0,
    Coords: { x: 215.76, y: -810.12, z: 30.73 },
    Note: '',
    Details: {
      dob: '1995-05-18',
      bloodgroup: 'O+',
      phone: '555-0199',
      job: typeof player.job === 'string' ? `${player.job} (0)` : 'Unemployed (0)',
      gang: typeof player.gang === 'string' ? `${player.gang} (0)` : 'None (0)',
      money: { cash: 5000, bank: 150000, crypto: 100 },
      inventory: [
        { name: 'water_bottle', label: 'Water Bottle', count: 5, slot: 1 },
        { name: 'sandwich', label: 'Sandwich', count: 3, slot: 2 },
        { name: 'phone', label: 'Phone', count: 1, slot: 3 },
        { name: 'lockpick', label: 'Lockpick', count: 2, slot: 4 },
      ],
      vehicles: MOCK_VEHICLES_ALL.slice(0, 2),
      properties: [{ id: 1, label: 'Sunset Boulevard Villa', address: 'Sunset Blvd 104', type: 'Residential' }],
    },
  };
}

function buildChoices(provider: string): DropdownChoice[] {
  switch (provider) {
    case 'items':
      return MOCK_ITEMS.map((item) => ({ Text: item.label, Source: item.name }));
    case 'jobs':
      return generateMockJobs().map((job) => ({ Text: job.label, Source: job.name }));
    case 'gangs':
      return generateMockGangs().map((gang) => ({ Text: gang.label, Source: gang.name }));
    case 'moneyTypes':
      return ['cash', 'bank', 'crypto'].map((type) => ({ Text: type, Source: type }));
    case 'bans':
      return MOCK_BANS.map((ban) => ({ Text: `${ban.Name} - ${ban.Reason}`, Source: ban.BanId ?? null }));
    default:
      return [];
  }
}

export function handleMockNui(eventName: string, data?: Payload): unknown {
  switch (eventName) {
    case 'fetchPlayers': {
      const status = readString(data, 'status', 'all');
      const { items, total } = paginateByPage(
        MOCK_DB_PLAYERS_ALL.filter((player) => status === 'all' || (status === 'online') === !!player.isOnline),
        readNumber(data, 'page', 1),
        readNumber(data, 'limit', 24),
        matchesPlayer,
        readString(data, 'search'),
      );
      return { Online: getOnlineMockPlayers(), All: data?.includeDb ? items : [], TotalCount: total, Disconnected: [] };
    }

    case 'fetchPlayerProfile':
      return buildProfile(readString(data, 'id'));

    case 'fetchVehicles': {
      const state = readString(data, 'state', 'all');
      const { items, total } = paginateByPage(
        MOCK_VEHICLES_ALL.filter((vehicle) => state === 'all' || vehicle.state === state),
        readNumber(data, 'page', 1),
        readNumber(data, 'limit', 20),
        (vehicle, query) =>
          [vehicle.plate, vehicle.model, vehicle.owner ?? '', vehicle.garage ?? ''].some((value) =>
            matchesSearch(value, query),
          ),
        readString(data, 'search'),
      );
      const StateCounts = { Stored: 0, Out: 0, Impounded: 0 };
      for (const vehicle of MOCK_VEHICLES_ALL) {
        if (vehicle.state in StateCounts) StateCounts[vehicle.state as keyof typeof StateCounts]++;
      }
      return { Vehicles: items, TotalCount: total, StateCounts };
    }

    case 'fetchProperties': {
      const filtered = filterProperties(
        MOCK_PROPERTIES_ALL,
        readString(data, 'search'),
        readString(data, 'filter', 'all'),
        readString(data, 'sort'),
      );
      const limit = readNumber(data, 'limit', 20);
      const offset = (readNumber(data, 'page', 1) - 1) * limit;
      return { Properties: filtered.slice(offset, offset + limit), TotalCount: filtered.length };
    }

    case 'fetchGarages':
      return MOCK_GARAGES_ALL;

    case 'fetchEconomy':
      return generateMockEconomy();

    case 'fetchJobs':
      return generateMockJobs();

    case 'fetchGangs':
      return generateMockGangs();

    case 'fetchFactionMembers': {
      const name = readString(data, 'name');
      const key = data?.type === 'gangs' ? 'gang' : 'job';
      return MOCK_DB_PLAYERS_ALL.filter((player) => player[key] === name);
    }

    case 'fetchInventories': {
      const { items, total } = paginateByOffset(
        getMockInventoriesByType(readString(data, 'type', 'player')),
        readNumber(data, 'offset', 0),
        readNumber(data, 'limit', 20),
        (inventory, query) =>
          [inventory.label, inventory.id, inventory.owner ?? ''].some((value) => matchesSearch(value, query)),
        readString(data, 'search'),
      );
      return { inventories: items, totalCount: total };
    }

    case 'fetchInventoryItems':
      return getMockInventoryItems(readString(data, 'invId'));

    case 'fetchBans':
      return MOCK_BANS;

    case 'fetchLogs':
      return { Logs: MOCK_LOGS, TotalCount: MOCK_LOGS.length };

    case 'fetchAccessControl':
      return {
        Ranks: MOCK_RANKS,
        Admins: MOCK_ADMINS,
        AvailablePermissions: MOCK_AVAILABLE_PERMISSIONS,
        DiscordRoles: MOCK_DISCORD_ROLES,
        Characters: MOCK_CHARACTERS,
        DiscordLogsEnabled: true,
      };

    case 'fetchResources':
      return MOCK_RESOURCES;

    case 'fetchDashboardSessions':
      return [];

    case 'getChoices':
      return buildChoices(readString(data, 'provider'));

    case 'vehicleAction':
    case 'propertyAction':
    case 'inventoryAction':
    case 'updateAlignment':
      return true;

    default:
      return undefined;
  }
}
