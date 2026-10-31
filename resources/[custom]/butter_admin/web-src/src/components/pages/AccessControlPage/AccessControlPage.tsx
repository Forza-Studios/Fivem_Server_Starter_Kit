import React, { useState, useEffect } from 'react';
import { SearchField } from '../../ui/SearchField';
import { useAdminMenu, toArray } from '../../../providers/AdminMenuContext';
import { SubTabs } from '../../ui/SubTabs';
import { Select } from '../../ui/Select';
import { Rank, AdminUser, DiscordRole, Character, PermissionCategory } from '../../../types';

interface AccessControlData {
  Ranks?: Rank[];
  Admins?: AdminUser[];
  AvailablePermissions?: PermissionCategory[];
  DiscordRoles?: DiscordRole[];
  Characters?: Character[];
  DiscordLogsEnabled?: boolean;
}
import { fetchNui } from '../../../utils/fetchNui';
import { copyTextToClipboard, openExternalUrl } from '../../../utils/misc';
import { dropdownPositionFrom } from '../../../utils/dropdownPosition';
import { DateTimePicker } from '../../ui/DateTimePicker';

const AccessControlPage: React.FC = () => {
  const {
    t,
    ranks,
    setRanks,
    admins,
    setAdmins,
    setDiscordRoles,
    setCharacters,
    setDbPlayers,
    setAvailablePermissions,
    menuSize,
    availablePermissions,
    discordRoles,
    characters,
    players,
    dbPlayers,
    setDropdown,
    showCheckmark,
    discordLogsEnabled,
    setDiscordLogsEnabled,
  } = useAdminMenu();
  const [duplicateAdminError, setDuplicateAdminError] = useState(false);
  const [activeTab, setActiveTab] = useState<'Permissions' | 'Admins'>('Admins');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const handleToggleDiscordLogs = () => {
    const next = !discordLogsEnabled;
    setDiscordLogsEnabled(next);
    fetchNui('setDiscordLogs', { enabled: next });
  };

  const getSteamProfileLink = (steamHex: string) => {
    if (!steamHex) return '';
    try {
      const cleanHex = steamHex.replace('steam:', '').trim();
      const steamID64 = BigInt(`0x${cleanHex}`).toString();
      return `https://steamcommunity.com/profiles/${steamID64}`;
    } catch (e) {
      return '';
    }
  };

  const formatSteamIdentifier = (input: string) => {
    let clean = input.trim();
    // Check if it's a steam profiles URL
    const profileMatch = clean.match(/steamcommunity\.com\/profiles\/(\d+)/i);
    if (profileMatch && profileMatch[1]) {
      clean = profileMatch[1];
    }
    // Check if it's a decimal SteamID64
    if (/^\d+$/.test(clean)) {
      try {
        const hex = BigInt(clean).toString(16);
        return `steam:${hex}`;
      } catch (e) {
        return clean;
      }
    }
    // If it's already a hex (with or without steam: prefix)
    const cleanHex = clean.replace('steam:', '');
    if (/^[0-9a-fA-F]+$/.test(cleanHex)) {
      if (!clean.startsWith('steam:')) {
        return `steam:${clean.toLowerCase()}`;
      }
      return clean.toLowerCase();
    }
    return clean;
  };

  const resolveAdminDetails = (admin: AdminUser) => {
    // Include `characters` as well: on live broadcasts the payload refreshes
    // `characters` but not `dbPlayers`, so relying on dbPlayers alone leaves
    // newly-added admins showing as "Unknown Player" until the page reopens.
    const searchLists = [...players, ...dbPlayers, ...characters];

    // Clean prefixes helper for comparison
    const cleanId = (id?: string) => {
      if (!id) return '';
      return id
        .replace(/^(discord|steam|license|citizenid):/, '')
        .toLowerCase()
        .trim();
    };

    const targetClean = cleanId(admin.Identifier);

    let foundPlayer = searchLists.find(
      (p) =>
        (p.License && cleanId(p.License) === targetClean) ||
        (p.Steam && cleanId(p.Steam) === targetClean) ||
        (p.Discord && cleanId(p.Discord) === targetClean) ||
        (p.CitizenId && cleanId(p.CitizenId) === targetClean) ||
        (p.ServerId && String(p.ServerId) === targetClean),
    );

    if (!foundPlayer) {
      foundPlayer = searchLists.find(
        (p) =>
          (admin.Steam && p.Steam && cleanId(p.Steam) === cleanId(admin.Steam)) ||
          (admin.Discord && p.Discord && cleanId(p.Discord) === cleanId(admin.Discord)) ||
          (admin.CharacterId && p.CitizenId && cleanId(p.CitizenId) === cleanId(admin.CharacterId)),
      );
    }

    const isOnline = players.some(
      (p) =>
        (p.License && cleanId(p.License) === targetClean) ||
        (p.Steam && cleanId(p.Steam) === targetClean) ||
        (p.Discord && cleanId(p.Discord) === targetClean) ||
        (p.CitizenId && cleanId(p.CitizenId) === targetClean) ||
        (foundPlayer &&
          ((p.License && cleanId(p.License) === cleanId(foundPlayer.License)) ||
            (p.Steam && cleanId(p.Steam) === cleanId(foundPlayer.Steam)) ||
            (p.Discord && cleanId(p.Discord) === cleanId(foundPlayer.Discord)))),
    );

    // Only resolve the identifier type that matches how the admin was added.
    // e.g. a steam: admin should NOT inherit foundPlayer's Discord, and vice-versa.
    const identifierType = admin.Identifier.startsWith('discord:')
      ? 'discord'
      : admin.Identifier.startsWith('steam:')
        ? 'steam'
        : admin.Identifier.startsWith('license:')
          ? 'license'
          : admin.Identifier.startsWith('citizenid:')
            ? 'citizenid'
            : admin.Identifier.startsWith('role:')
              ? 'role'
              : 'other';

    let resolvedDiscord =
      admin.Discord || (identifierType === 'discord' || identifierType === 'other' ? foundPlayer?.Discord : '') || '';
    let resolvedSteam =
      admin.Steam || (identifierType === 'steam' || identifierType === 'other' ? foundPlayer?.Steam : '') || '';
    let resolvedLicense =
      (identifierType === 'license' || identifierType === 'other' ? foundPlayer?.License : '') || '';

    if (identifierType === 'discord') resolvedDiscord = admin.Identifier;
    else if (identifierType === 'steam') resolvedSteam = admin.Identifier;
    else if (identifierType === 'license') resolvedLicense = admin.Identifier;

    const cleanDiscord = resolvedDiscord.replace('discord:', '');
    const cleanSteam = resolvedSteam.replace('steam:', '');
    const cleanLicense = resolvedLicense.replace('license:', '');

    let displayName = 'Unknown Player';
    if (admin.Identifier.startsWith('role:')) {
      const roleId = admin.Identifier.replace('role:', '');
      const discordRole = discordRoles.find((r) => r.id === roleId);
      displayName = discordRole?.name ? `Role: ${discordRole.name}` : `Discord Role: ${roleId}`;
    } else if (foundPlayer) {
      displayName = foundPlayer.Name;
    } else if (admin.DisplayName) {
      displayName = admin.DisplayName;
    } else {
      displayName = admin.Identifier.length > 20 ? `${admin.Identifier.substring(0, 18)}...` : admin.Identifier;
    }

    return {
      player: foundPlayer,
      isOnline,
      displayName,
      discordId: cleanDiscord,
      steamHex: cleanSteam,
      licenseHex: cleanLicense,
      citizenId: admin.CharacterId || foundPlayer?.CitizenId || '',
    };
  };

  const formatDutyTime = (totalSeconds?: number) => {
    const s = Math.max(0, Math.floor(totalSeconds || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m`;
    return `${s}s`;
  };

  const handleCopy = (text: string, id: string) => {
    copyTextToClipboard(text);
    setCopiedId(id);
    showCheckmark();
    setTimeout(() => setCopiedId(null), 1500);
  };

  useEffect(() => {
    fetchNui<AccessControlData | false>('fetchAccessControl').then((data) => {
      if (!data) return;
      if (data.Admins) setAdmins(toArray(data.Admins));
      if (data.Ranks) setRanks(toArray(data.Ranks));
      if (data.DiscordRoles) setDiscordRoles(toArray(data.DiscordRoles));
      if (data.AvailablePermissions) setAvailablePermissions(toArray(data.AvailablePermissions));
      if (data.DiscordLogsEnabled !== undefined) setDiscordLogsEnabled(!!data.DiscordLogsEnabled);
      if (data.Characters) {
        const characterList = toArray<Character>(data.Characters);
        setCharacters(characterList);
        // Characters carry identifiers, so they double as the database player list here.
        setDbPlayers(characterList);
      }
    });
  }, []);

  const isLargeMode = menuSize === 'Large';

  // Focus states for search dropdowns
  const [isPlayerSearchFocused, setIsPlayerSearchFocused] = useState(false);
  const [isRoleSearchFocused, setIsRoleSearchFocused] = useState(false);

  // Permissions Tab State
  const [selectedRank, setSelectedRank] = useState<Rank | null>(null);
  const [isEditingPermissions, setIsEditingPermissions] = useState(false);
  const [isAddRankModalOpen, setIsAddRankModalOpen] = useState(false);
  const [rankToEdit, setRankToEdit] = useState<Rank | null>(null);
  const [rankToDelete, setRankToDelete] = useState<Rank | null>(null);
  const [rankForm, setRankForm] = useState<Partial<Rank>>({
    Id: '',
    Name: '',
  });
  const [copiedPermissions, setCopiedPermissions] = useState<string[] | null>(null);

  // Admins Tab State
  const [searchQuery, setSearchQuery] = useState('');
  const [rankFilter, setRankFilter] = useState('all');
  const [adminStatus, setAdminStatus] = useState<'all' | 'online' | 'temporary'>('all');
  const [permSearch, setPermSearch] = useState('');
  const [grantedOnly, setGrantedOnly] = useState(false);
  const [adminToEdit, setAdminToEdit] = useState<AdminUser | null>(null);
  const [adminToDelete, setAdminToDelete] = useState<AdminUser | null>(null);
  const [isAddAdminModalOpen, setIsAddAdminModalOpen] = useState(false);

  // Edit/Add Admin Form State
  const [adminForm, setAdminForm] = useState<Partial<AdminUser>>({
    Identifier: '',
    RankId: '',
    IsTemp: false,
    Steam: '',
    Discord: '',
    DiscordRoles: [],
    CharacterId: '',
  });

  const [idType, setIdType] = useState<'LICENSE' | 'STEAM' | 'DISCORD' | 'DISCORD ROLE' | 'CHARACTER'>('LICENSE');

  useEffect(() => {
    setDuplicateAdminError(false);
  }, [adminForm.Identifier]);

  const allPermissionIds = availablePermissions.flatMap((cat) => cat.permissions.map((p) => p.id));

  const handleOpenAddRank = () => {
    setRankForm({ Id: '', Name: '' });
    setIsAddRankModalOpen(true);
  };

  const handleOpenEditRank = (rank: Rank) => {
    setRankForm({ ...rank });
    setRankToEdit(rank);
  };

  const handleSaveRank = () => {
    const dataToSave = rankToEdit
      ? ({ ...selectedRank, ...rankForm } as Rank)
      : {
          Id: rankForm.Id || `rank_${Date.now()}`,
          Name: rankForm.Name || 'New Rank',
          Permissions: [],
        };

    fetchNui('saveRank', dataToSave);
    setIsAddRankModalOpen(false);
    setRankToEdit(null);
  };

  const handleDeleteRank = () => {
    if (!rankToDelete) return;
    fetchNui('deleteRank', { id: rankToDelete.Id });
    setRankToDelete(null);
  };

  const handleTogglePermission = (rankId: string, permission: string) => {
    setRanks((prev) =>
      prev.map((rank) => {
        if (rank.Id === rankId) {
          const hasPerm = rank.Permissions.includes(permission);
          const newPermissions = hasPerm
            ? rank.Permissions.filter((p) => p !== permission)
            : [...rank.Permissions, permission];

          const updatedRank = { ...rank, Permissions: newPermissions };

          // Save to DB immediately
          fetchNui('saveRank', updatedRank);

          if (selectedRank?.Id === rankId) {
            setSelectedRank(updatedRank);
          }

          return updatedRank;
        }
        return rank;
      }),
    );
  };

  const handleOpenAddAdmin = () => {
    const now = new Date();
    const defaultExpiry = {
      day: now.getDate() + 1, // Default 1 day
      month: now.getMonth() + 1,
      year: now.getFullYear(),
      hour: now.getHours(),
      min: now.getMinutes(),
    };
    setAdminForm({
      Identifier: '',
      RankId: ranks[0]?.Id || '',
      IsTemp: false,
      Expires: defaultExpiry,
      Steam: '',
      Discord: '',
      DiscordRoles: [],
      CharacterId: '',
      Webhook: '',
      WebhookEvents: ['all'],
    });
    setIdType('LICENSE');
    setDuplicateAdminError(false);
    setIsAddAdminModalOpen(true);
  };

  const handleOpenEditAdmin = (admin: AdminUser) => {
    // Reflect the admin's real identifier type in the modal so the "Type" chip is
    // accurate and the save path never re-prefixes a non-license identifier.
    const id = admin.Identifier || '';
    setIdType(
      id.startsWith('steam:')
        ? 'STEAM'
        : id.startsWith('discord:')
          ? 'DISCORD'
          : id.startsWith('license:')
            ? 'LICENSE'
            : id.startsWith('role:')
              ? 'DISCORD ROLE'
              : 'CHARACTER',
    );

    let expiry = admin.Expires;
    if (typeof expiry === 'number') {
      const d = new Date(expiry * 1000);
      expiry = {
        day: d.getDate(),
        month: d.getMonth() + 1,
        year: d.getFullYear(),
        hour: d.getHours(),
        min: d.getMinutes(),
      };
    }

    setAdminForm({
      ...admin,
      Expires: expiry,
      Steam: admin.Steam || '',
      Discord: admin.Discord || '',
      DiscordRoles: admin.DiscordRoles || [],
      CharacterId: admin.CharacterId || '',
      Webhook: admin.Webhook || '',
      WebhookEvents: admin.WebhookEvents || ['all'],
    });
    setAdminToEdit(admin);
    setDuplicateAdminError(false);
  };

  const handleSaveAdmin = () => {
    let finalForm = { ...adminForm };

    if (adminToEdit) {
      // Editing an existing admin: keep the original identifier verbatim so the
      // DB update targets the correct row (keyed on identifier) instead of
      // re-prefixing it and inserting a duplicate. The identifier isn't meant to
      // change on edit, only the rank/expiry/webhook do.
      finalForm.Identifier = adminToEdit.Identifier;
    } else if (idType === 'STEAM' && finalForm.Identifier) {
      finalForm.Identifier = formatSteamIdentifier(finalForm.Identifier);
    } else if (idType === 'DISCORD' && finalForm.Identifier) {
      const clean = finalForm.Identifier.replace('discord:', '').trim();
      if (!finalForm.Identifier.startsWith('discord:')) {
        finalForm.Identifier = `discord:${clean}`;
      }
    } else if (idType === 'LICENSE' && finalForm.Identifier) {
      const clean = finalForm.Identifier.replace('license:', '').trim();
      if (!finalForm.Identifier.startsWith('license:')) {
        finalForm.Identifier = `license:${clean}`;
      }
    }

    let adminName = adminForm.Identifier;
    if (idType === 'DISCORD ROLE') {
      const role = discordRoles.find((r) => `role:${r.id}` === finalForm.Identifier);
      if (role) adminName = role.name;
    } else {
      const player = dbPlayers.find(
        (p) =>
          p.CitizenId === finalForm.Identifier ||
          p.Steam === finalForm.Identifier ||
          p.License === finalForm.Identifier,
      );
      if (player && player.Name) adminName = player.Name;
    }
    finalForm.Name = adminName;

    // Adding (not editing): an identifier that's already an admin must go through
    // the edit flow instead of silently re-adding/overwriting it here.
    const isDuplicate = (identifier?: string) =>
      !adminToEdit && !!identifier && admins.some((a) => a.Identifier === identifier);

    if (!adminToEdit && idType === 'DISCORD ROLE' && finalForm.DiscordRoles && finalForm.DiscordRoles.length > 0) {
      if (finalForm.DiscordRoles.every((roleId) => isDuplicate(`role:${roleId}`))) {
        setDuplicateAdminError(true);
        return;
      }
      // Bulk add multiple discord roles as separate admin entries
      finalForm.DiscordRoles.forEach((roleId) => {
        const identifier = `role:${roleId}`;
        if (isDuplicate(identifier)) return;
        const roleName = discordRoles.find((r) => r.id === roleId)?.name || roleId;
        fetchNui('saveAdmin', { ...finalForm, Identifier: identifier, Name: roleName });
      });
    } else if (isDuplicate(finalForm.Identifier)) {
      setDuplicateAdminError(true);
      return;
    } else {
      fetchNui('saveAdmin', finalForm);
    }
    const now = new Date();
    const defaultExpiry = {
      day: now.getDate() + 1,
      month: now.getMonth() + 1,
      year: now.getFullYear(),
      hour: now.getHours(),
      min: now.getMinutes(),
    };
    setAdminForm({
      Identifier: '',
      RankId: ranks[0]?.Id || '',
      DiscordRoles: [],
      IsTemp: false,
      Expires: defaultExpiry,
      Webhook: '',
      WebhookEvents: ['all'],
    });
    setIsAddAdminModalOpen(false);
    setAdminToEdit(null);
  };

  const handleDeleteAdmin = () => {
    if (!adminToDelete) return;
    fetchNui('deleteAdmin', { identifier: adminToDelete.Identifier });
    setAdminToDelete(null);
  };

  const filteredAdmins = admins.filter((admin) => {
    if (rankFilter !== 'all' && admin.RankId !== rankFilter) return false;
    if (adminStatus === 'temporary' && !admin.IsTemp) return false;
    const details = resolveAdminDetails(admin);
    if (adminStatus === 'online' && !details.isOnline) return false;

    const query = searchQuery.toLowerCase();
    if (!query) return true;
    const rankName = ranks.find((rank) => rank.Id === admin.RankId)?.Name;
    return [admin.Identifier, admin.Name, admin.DisplayName, admin.CharacterId, details.displayName, details.discordId, details.steamHex, rankName].some(
      (value) => typeof value === 'string' && value.toLowerCase().includes(query),
    );
  });

  const permQuery = permSearch.toLowerCase();
  const visiblePermissionCategories = availablePermissions
    .map((category) => ({
      ...category,
      permissions: category.permissions.filter((perm) => {
        if (grantedOnly && !selectedRank?.Permissions.includes(perm.id)) return false;
        return !permQuery || perm.label.toLowerCase().includes(permQuery) || perm.id.toLowerCase().includes(permQuery);
      }),
    }))
    .filter((category) => category.permissions.length > 0);

  const filteredRanks = ranks.filter((rank) => rank.Name.toLowerCase().includes(searchQuery.toLowerCase()));

  if (!isLargeMode) {
    return (
      <div className="flex flex-col h-full w-full items-center justify-center text-muted p-4">
        <div className="w-16 h-16 rounded-2xl bg-bg-secondary/60 border border-border/60 flex items-center justify-center mb-5">
          <i className="fa-solid fa-shield-halved text-3xl text-accent/70"></i>
        </div>
        <p className="text-lg font-semibold text-primary text-center max-w-xs">
          {t('ui.pages.access.large_mode_opt').split('Large Mode')[0]}
          <span className="text-accent">Large Mode</span>
          {t('ui.pages.access.large_mode_opt').split('Large Mode')[1]}
        </p>
        <p className="text-sm mt-2 text-muted text-center max-w-xs">{t('ui.pages.access.large_mode_desc')}</p>
      </div>
    );
  }

  // Live summary metrics for the header stat bar
  const onlineCount = admins.reduce((n, a) => n + (resolveAdminDetails(a).isOnline ? 1 : 0), 0);
  const tempCount = admins.filter((a) => a.IsTemp).length;
  const stats = [
    {
      icon: 'fa-solid fa-user-shield',
      label: t('ui.pages.access.tabs.admins'),
      value: admins.length,
      tone: 'text-accent',
    },
    { icon: 'fa-solid fa-signal', label: 'Online', value: onlineCount, tone: 'text-success' },
    {
      icon: 'fa-solid fa-layer-group',
      label: t('ui.pages.access.tabs.permissions'),
      value: ranks.length,
      tone: 'text-accent',
    },
    { icon: 'fa-regular fa-clock', label: 'Temporary', value: tempCount, tone: 'text-warning' },
  ];

  const rankTone = (rank?: Rank | null): { color: string; label: string; icon: string } => {
    const nl = (rank?.Name || '').toLowerCase();
    if (nl.includes('god') || nl.includes('owner') || nl.includes('dev'))
      return { color: 'rgb(234,179,8)', label: 'Leadership', icon: 'fa-crown' };
    if (nl.includes('admin') || nl.includes('super'))
      return { color: 'rgb(99,102,241)', label: 'Administration', icon: 'fa-user-shield' };
    if (nl.includes('mod') || nl.includes('support'))
      return { color: 'rgb(52,211,153)', label: 'Moderation', icon: 'fa-user-gear' };
    return { color: 'rgb(var(--accent))', label: 'Staff', icon: 'fa-shield-halved' };
  };

  return (
    <div className="flex flex-col h-full w-full text-primary">
      <div className="px-6 pt-6 pb-4 flex-shrink-0 border-b border-border/50">
        <div className="flex items-start justify-between gap-4 flex-wrap mb-5">
          <div className="flex items-center gap-3.5">
            <div className="w-11 h-11 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center text-accent">
              <i className="fa-solid fa-shield-halved text-xl"></i>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-primary leading-tight">
                {t('ui.pages.access.ranks.access_control')}
              </h2>
              <p className="text-sm text-muted mt-0.5">{t('ui.pages.access.ranks.ranks_management_subtitle')}</p>
            </div>
          </div>

          {/* Live stat row */}
          <div className="flex items-stretch gap-2.5">
            {stats.map((s) => (
              <div
                key={s.label}
                className="flex items-center gap-3 bg-bg-secondary/40 border border-border/50 rounded-xl px-4 py-2.5 min-w-[104px]"
              >
                <i className={`${s.icon} ${s.tone} text-base`}></i>
                <div className="flex flex-col leading-none">
                  <span className="text-primary font-semibold text-lg">{s.value}</span>
                  <span className="text-[11px] text-muted mt-1">{s.label}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Sub Tabs */}
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <SubTabs
            tabs={[
              {
                id: 'Admins',
                label: t('ui.pages.access.tabs.admins'),
                icon: 'fa-solid fa-user-shield',
                count: admins.length,
              },
              {
                id: 'Permissions',
                label: t('ui.pages.access.tabs.permissions'),
                icon: 'fa-solid fa-key',
                count: ranks.length,
              },
            ]}
            activeTab={activeTab}
            onChange={setActiveTab}
          />

          {/* Discord Logs Toggle */}
          <div className="flex items-center gap-3 bg-bg-secondary/40 border border-border/50 rounded-xl px-4 py-2.5">
            <i className={`fa-brands fa-discord text-base ${discordLogsEnabled ? 'text-accent' : 'text-muted'}`}></i>
            <span className="text-sm text-primary font-medium whitespace-nowrap">
              {t('ui.pages.access.discord_logs')}
            </span>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                className="sr-only peer"
                checked={discordLogsEnabled}
                onChange={handleToggleDiscordLogs}
              />
              <div className="w-11 h-6 bg-black/40 border border-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent peer-checked:border-accent"></div>
            </label>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-hidden p-6">
        {activeTab === 'Permissions' ? (
          <div className="h-full flex gap-6">
            {/* Ranks list */}
            <div className="w-[38%] max-w-[360px] flex flex-col gap-3">
              <div className="relative flex-shrink-0">
                <i className="fa-solid fa-magnifying-glass absolute left-3.5 top-1/2 -translate-y-1/2 text-muted text-sm"></i>
                <input
                  type="text"
                  placeholder={t('ui.pages.access.ranks.search')}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-bg-secondary/50 border border-border/50 rounded-xl pl-10 pr-4 py-2.5 text-primary text-sm focus:outline-none focus:border-accent/60 focus:bg-bg-secondary/70 transition-all placeholder:text-muted/70"
                />
              </div>

              <button
                onClick={handleOpenAddRank}
                className="w-full flex-shrink-0 bg-accent hover:bg-accent/90 text-white px-4 py-2.5 rounded-xl font-medium transition-colors flex items-center justify-center gap-2"
              >
                <i className="fa-solid fa-plus text-sm"></i>
                {t('ui.pages.access.ranks.add_new')}
              </button>

              <div className="flex-1 overflow-y-auto custom-scrollbar flex flex-col gap-2 pr-1">
                {filteredRanks.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-14 text-muted">
                    <i className="fa-solid fa-shield-halved text-3xl mb-3 opacity-40"></i>
                    <p className="text-sm">{t('ui.pages.access.ranks.no_results')}</p>
                  </div>
                ) : (
                  filteredRanks.map((rank) => {
                    const isSelected = selectedRank?.Id === rank.Id;
                    const hasAll = rank.Permissions.includes('all');
                    const permCount = hasAll ? allPermissionIds.length : rank.Permissions.length;
                    const totalPerms = allPermissionIds.length || 1;
                    const fill = hasAll ? 100 : Math.min(100, Math.round((permCount / totalPerms) * 100));
                    const tone = rankTone(rank);
                    return (
                      <div
                        key={rank.Id}
                        onClick={() => {
                          setSelectedRank(rank);
                          setIsEditingPermissions(false);
                        }}
                        style={
                          isSelected
                            ? {
                                borderColor: `color-mix(in srgb, ${tone.color} 45%, transparent)`,
                                backgroundColor: `color-mix(in srgb, ${tone.color} 8%, transparent)`,
                              }
                            : undefined
                        }
                        className={`p-3.5 rounded-xl cursor-pointer transition-colors border flex flex-col gap-3 group ${isSelected ? '' : 'bg-bg-secondary/30 border-border/50 hover:bg-bg-secondary/50 hover:border-border'}`}
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className="w-10 h-10 shrink-0 rounded-xl flex items-center justify-center text-base"
                            style={{
                              backgroundColor: `color-mix(in srgb, ${tone.color} 14%, transparent)`,
                              color: tone.color,
                            }}
                          >
                            <i className={`fa-solid ${tone.icon}`}></i>
                          </div>

                          <div className="flex flex-col flex-1 min-w-0 gap-0.5">
                            <div
                              className={`font-semibold text-[15px] leading-tight truncate ${isSelected ? 'text-primary' : 'text-primary/90 group-hover:text-primary'}`}
                            >
                              {rank.Name}
                            </div>
                            <span className="text-[11px] leading-none" style={{ color: tone.color }}>
                              {tone.label}
                            </span>
                          </div>

                          {/* Permission count (hidden on hover to reveal actions) */}
                          <div className="shrink-0 group-hover:hidden">
                            {hasAll ? (
                              <span className="text-[11px] font-medium text-success bg-success/10 px-2 py-1 rounded-md">
                                Full
                              </span>
                            ) : permCount === 0 ? (
                              <span className="text-[11px] font-medium text-danger/90 bg-danger/10 px-2 py-1 rounded-md">
                                {t('ui.pages.access.ranks.no_access')}
                              </span>
                            ) : (
                              <span className="text-[11px] font-mono text-muted bg-bg-secondary/70 border border-border/50 px-2 py-1 rounded-md">
                                {permCount}/{totalPerms}
                              </span>
                            )}
                          </div>

                          {/* Hover actions */}
                          <div className="hidden group-hover:flex items-center gap-1 shrink-0">
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setSelectedRank(rank);
                                handleOpenEditRank(rank);
                              }}
                              className="w-7 h-7 rounded-lg flex items-center justify-center text-muted hover:text-primary hover:bg-bg-secondary transition-colors"
                            >
                              <i className="fa-solid fa-pen text-[11px]"></i>
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setRankToDelete(rank);
                              }}
                              className="w-7 h-7 rounded-lg flex items-center justify-center text-muted hover:text-danger hover:bg-danger/10 transition-colors"
                            >
                              <i className="fa-solid fa-trash text-[11px]"></i>
                            </button>
                          </div>
                        </div>

                        {/* Progress track */}
                        <div className="flex items-center gap-2.5">
                          <div className="flex-1 h-1.5 rounded-full bg-border/50 overflow-hidden">
                            <div
                              className="h-full rounded-full transition-all duration-500"
                              style={{ width: `${fill}%`, backgroundColor: hasAll ? 'rgb(52,211,153)' : tone.color }}
                            ></div>
                          </div>
                          <span className="text-[11px] font-mono text-muted shrink-0 w-9 text-right">{fill}%</span>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>

            {/* Permissions editor */}
            <div className="flex-1 bg-bg-secondary/30 border border-border/50 rounded-2xl p-6 flex flex-col">
              {selectedRank ? (
                <>
                  <div className="flex items-center justify-between gap-4 mb-6 flex-wrap">
                    <div className="flex items-center gap-3 min-w-0">
                      <h2 className="text-xl font-semibold text-primary flex items-center gap-2.5 truncate">
                        <i className="fa-solid fa-shield-halved text-accent"></i>
                        {selectedRank.Name}
                        <button
                          onClick={() => handleOpenEditRank(selectedRank)}
                          className="text-muted hover:text-primary transition-colors text-base ml-1"
                          title={t('ui.pages.access.ranks.edit_title')}
                        >
                          <i className="fa-solid fa-pen"></i>
                        </button>
                      </h2>
                      {selectedRank.Permissions.includes('all') ? (
                        <span className="text-[11px] font-medium text-success bg-success/10 px-2.5 py-1 rounded-full shrink-0">
                          Full access
                        </span>
                      ) : (
                        <span className="text-[11px] font-mono text-accent bg-accent/10 px-2.5 py-1 rounded-full shrink-0">
                          {selectedRank.Permissions.length}/{allPermissionIds.length}
                        </span>
                      )}
                    </div>
                    <div className="flex gap-2">
                      {!isEditingPermissions ? (
                        <>
                          <button
                            onClick={() => setIsEditingPermissions(true)}
                            className="text-sm font-medium bg-accent/15 hover:bg-accent/25 text-accent px-3.5 py-2 rounded-lg transition-colors flex items-center gap-2"
                          >
                            <i className="fa-solid fa-pen"></i> {t('ui.pages.access.management.edit_perms')}
                          </button>
                          <button
                            onClick={() => setCopiedPermissions([...selectedRank.Permissions])}
                            className="text-sm font-medium bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary px-3.5 py-2 rounded-lg transition-colors flex items-center gap-2"
                            title="Copy Configuration"
                          >
                            <i className="fa-solid fa-copy"></i> Copy
                          </button>
                          {copiedPermissions && (
                            <button
                              onClick={() => {
                                const updatedRank = { ...selectedRank, Permissions: [...copiedPermissions] };
                                fetchNui('saveRank', updatedRank);
                                setSelectedRank(updatedRank);
                                setRanks((prev) => prev.map((r) => (r.Id === selectedRank.Id ? updatedRank : r)));
                              }}
                              className="text-sm font-medium bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary px-3.5 py-2 rounded-lg transition-colors flex items-center gap-2"
                              title={t('ui.pages.access.ranks.paste_title')}
                            >
                              <i className="fa-solid fa-paste"></i> {t('ui.pages.access.ranks.paste')}
                            </button>
                          )}
                          <button
                            onClick={() => setRankToDelete(selectedRank)}
                            className="text-sm font-medium bg-danger/10 hover:bg-danger/20 text-danger px-3.5 py-2 rounded-lg transition-colors flex items-center gap-2"
                          >
                            <i className="fa-solid fa-trash"></i> {t('common.delete')}
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => {
                              allPermissionIds.forEach((perm) => {
                                if (!selectedRank.Permissions.includes(perm)) {
                                  handleTogglePermission(selectedRank.Id, perm);
                                }
                              });
                            }}
                            className="text-sm font-medium bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary px-3 py-2 rounded-lg transition-colors"
                          >
                            {t('ui.pages.access.management.select_all')}
                          </button>
                          <button
                            onClick={() => {
                              allPermissionIds.forEach((perm) => {
                                if (selectedRank.Permissions.includes(perm)) {
                                  handleTogglePermission(selectedRank.Id, perm);
                                }
                              });
                            }}
                            className="text-sm font-medium bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary px-3 py-2 rounded-lg transition-colors"
                          >
                            {t('ui.pages.access.management.deselect_all')}
                          </button>
                          <button
                            onClick={() => setIsEditingPermissions(false)}
                            className="text-sm font-medium bg-success/15 hover:bg-success/25 text-success px-3.5 py-2 rounded-lg transition-colors flex items-center gap-2 ml-1"
                          >
                            <i className="fa-solid fa-check"></i> {t('ui.pages.access.management.done')}
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2 mb-4">
                    <SearchField
                      className="flex-1"
                      value={permSearch}
                      onChange={setPermSearch}
                      placeholder={t('ui.pages.access.ranks.search_permissions')}
                    />
                    <button
                      onClick={() => setGrantedOnly((value) => !value)}
                      className={`px-3 py-2 rounded-lg border text-xs transition-colors ${
                        grantedOnly
                          ? 'bg-accent/15 border-accent/40 text-accent'
                          : 'bg-black/30 border-white/5 text-white/50 hover:text-white hover:border-white/10'
                      }`}
                    >
                      {t('ui.pages.access.ranks.granted_only')}
                    </button>
                  </div>
                  <div className="flex-1 overflow-y-auto custom-scrollbar pr-3 flex flex-col gap-6">
                    {visiblePermissionCategories.length === 0 && (
                      <p className="py-10 text-center text-sm text-muted">{t('ui.pages.access.ranks.no_permissions_match')}</p>
                    )}
                    {visiblePermissionCategories.map((category) => {
                      const catIds = category.permissions.map((p) => p.id);
                      const catGranted = catIds.filter((id) => selectedRank.Permissions.includes(id)).length;
                      return (
                        <div key={category.title} className="flex flex-col gap-3">
                          <div className="flex items-center justify-between border-b border-border/50 pb-2">
                            <h3 className="text-muted font-medium text-sm">{category.title}</h3>
                            <span
                              className={`text-[11px] font-mono font-medium px-2 py-0.5 rounded ${catGranted > 0 ? 'text-accent bg-accent/10' : 'text-muted/60'}`}
                            >
                              {catGranted}/{catIds.length}
                            </span>
                          </div>
                          <div className="grid grid-cols-2 gap-2.5">
                            {category.permissions.map((perm) => {
                              const hasPerm = selectedRank.Permissions.includes(perm.id);
                              return (
                                <div
                                  key={perm.id}
                                  onClick={() =>
                                    isEditingPermissions && handleTogglePermission(selectedRank.Id, perm.id)
                                  }
                                  className={`px-3.5 py-3 rounded-xl border transition-colors flex items-center justify-between gap-2 group ${
                                    hasPerm
                                      ? 'bg-accent/[0.08] border-accent/25'
                                      : 'bg-bg-secondary/40 border-border/50'
                                  } ${isEditingPermissions ? 'cursor-pointer hover:border-border' : 'opacity-70'}`}
                                >
                                  <div className="flex flex-col min-w-0">
                                    <span className={`text-sm truncate ${hasPerm ? 'text-primary' : 'text-muted'}`}>
                                      {perm.label}
                                    </span>
                                    <span className="font-mono text-[11px] text-muted/60 truncate">{perm.id}</span>
                                  </div>
                                  <div
                                    className={`w-9 h-5 rounded-full relative transition-colors flex items-center shrink-0 ${hasPerm ? (isEditingPermissions ? 'bg-accent' : 'bg-accent/50') : 'bg-border'} ${isEditingPermissions && !hasPerm ? 'group-hover:bg-border/70' : ''}`}
                                  >
                                    <div
                                      className={`absolute w-4 h-4 rounded-full bg-white transition-transform ${hasPerm ? 'translate-x-[18px]' : 'translate-x-[2px]'}`}
                                    ></div>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </>
              ) : (
                <div className="h-full flex flex-col items-center justify-center text-muted">
                  <i className="fa-solid fa-hand-pointer text-4xl mb-4 opacity-50"></i>
                  <p className="text-lg">{t('ui.pages.access.ranks.select_prompt')}</p>
                </div>
              )}
            </div>
          </div>
        ) : (
          <div className="h-full flex flex-col gap-5">
            {/* Admins search & add */}
            <div className="flex gap-3 shrink-0">
              <div className="relative flex-1">
                <i className="fa-solid fa-magnifying-glass absolute left-3.5 top-1/2 -translate-y-1/2 text-muted text-sm"></i>
                <input
                  type="text"
                  placeholder={t('ui.pages.access.management.search')}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-bg-secondary/50 border border-border/50 rounded-xl pl-10 pr-4 py-2.5 text-primary text-sm focus:outline-none focus:border-accent/60 focus:bg-bg-secondary/70 transition-all placeholder:text-muted/70"
                />
              </div>
              <Select
                value={rankFilter}
                onChange={setRankFilter}
                triggerClassName="bg-bg-secondary/50 border border-border/50 rounded-xl px-3 py-2.5 text-sm text-primary whitespace-nowrap focus:border-accent/60"
                options={[
                  { id: 'all', label: t('ui.pages.access.management.all_ranks') },
                  ...ranks.map((rank) => ({ id: rank.Id, label: rank.Name })),
                ]}
              />
              <SubTabs
                tabs={[
                  { id: 'all', label: t('ui.pages.access.management.filter_all') },
                  { id: 'online', label: t('ui.pages.access.management.filter_online') },
                  { id: 'temporary', label: t('ui.pages.access.management.filter_temporary') },
                ]}
                activeTab={adminStatus}
                onChange={setAdminStatus}
                tabClassName="py-1.5"
              />
              <button
                onClick={handleOpenAddAdmin}
                className="bg-accent hover:bg-accent/90 text-white px-4 py-2.5 rounded-xl font-medium transition-colors flex items-center gap-2"
              >
                <i className="fa-solid fa-user-plus"></i>
                {t('ui.pages.access.management.add')}
              </button>
            </div>

            {/* Admins list */}
            <div className="flex-1 overflow-y-auto custom-scrollbar pr-1">
              {filteredAdmins.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16 text-muted">
                  <div className="w-16 h-16 rounded-2xl bg-bg-secondary/50 border border-border/50 flex items-center justify-center mb-4">
                    <i className="fa-solid fa-user-shield text-2xl opacity-40"></i>
                  </div>
                  <p className="text-base">{t('ui.pages.access.management.no_results')}</p>
                  <button
                    onClick={handleOpenAddAdmin}
                    className="mt-4 text-sm font-medium text-accent hover:text-accent/80 flex items-center gap-2 transition-colors"
                  >
                    <i className="fa-solid fa-user-plus"></i>
                    {t('ui.pages.access.management.add')}
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 xl:grid-cols-2 gap-3.5 pb-4">
                  {filteredAdmins.map((admin) => {
                    const rank = ranks.find((r) => r.Id === admin.RankId);
                    const { isOnline, displayName, discordId, steamHex } = resolveAdminDetails(admin);
                    const steamProfileLink = getSteamProfileLink(steamHex);

                    const roleId = admin.Identifier.startsWith('role:') ? admin.Identifier.replace('role:', '') : null;
                    const discordRole = roleId ? discordRoles.find((r) => r.id === roleId) : null;
                    const roleColor =
                      discordRole && discordRole.color && discordRole.color > 0
                        ? `#${discordRole.color.toString(16).padStart(6, '0')}`
                        : null;

                    const tone = rankTone(rank);
                    const accentColor = roleColor || tone.color;

                    return (
                      <div
                        key={admin.Identifier}
                        className="bg-bg-secondary/30 border border-border/50 rounded-2xl p-5 flex flex-col gap-4 hover:bg-bg-secondary/50 hover:border-border transition-colors group"
                      >
                        {/* Header row */}
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-center gap-3 min-w-0">
                            {/* Avatar */}
                            <div
                              className="w-12 h-12 rounded-xl flex items-center justify-center font-semibold text-lg relative shrink-0"
                              style={{
                                backgroundColor: `color-mix(in srgb, ${accentColor} 14%, transparent)`,
                                color: accentColor,
                              }}
                            >
                              {admin.AvatarUrl ? (
                                <img
                                  src={admin.AvatarUrl}
                                  alt={displayName}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : admin.Identifier.startsWith('role:') ? (
                                <i className="fa-brands fa-discord text-lg"></i>
                              ) : (
                                displayName.charAt(0).toUpperCase()
                              )}
                              {!admin.Identifier.startsWith('role:') && (
                                <span
                                  className={`absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-bg-primary ${isOnline ? 'bg-success' : 'bg-muted/50'}`}
                                  title={isOnline ? 'Online' : 'Offline'}
                                ></span>
                              )}
                            </div>

                            {/* Name & rank */}
                            <div className="min-w-0 flex flex-col gap-1">
                              <span
                                className="text-primary font-semibold text-[15px] leading-tight truncate"
                                title={displayName}
                              >
                                {displayName}
                              </span>
                              <div className="flex items-center gap-2">
                                <span
                                  className="px-2 py-0.5 rounded-md text-[11px] font-medium"
                                  style={{
                                    backgroundColor: `color-mix(in srgb, ${accentColor} 12%, transparent)`,
                                    color: accentColor,
                                  }}
                                >
                                  {rank?.Name || t('ui.pages.access.management.unknown_rank')}
                                </span>
                                {isOnline && !admin.Identifier.startsWith('role:') && (
                                  <span className="text-[11px] font-medium text-success bg-success/10 px-2 py-0.5 rounded-md">
                                    Online
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>

                          {/* Actions */}
                          <div className="flex gap-1.5 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
                            <button
                              onClick={() => handleOpenEditAdmin(admin)}
                              className="w-8 h-8 rounded-lg bg-bg-secondary/70 hover:bg-accent/15 text-muted hover:text-accent transition-colors flex items-center justify-center"
                              title={t('ui.pages.access.management.edit_title')}
                            >
                              <i className="fa-solid fa-pen text-xs"></i>
                            </button>
                            <button
                              onClick={() => setAdminToDelete(admin)}
                              className="w-8 h-8 rounded-lg bg-bg-secondary/70 hover:bg-danger/15 text-muted hover:text-danger transition-colors flex items-center justify-center"
                              title={t('ui.pages.access.management.revoke_title')}
                            >
                              <i className="fa-solid fa-trash text-xs"></i>
                            </button>
                          </div>
                        </div>

                        {/* Identity chips */}
                        <div className="flex flex-col gap-1.5">
                          {/* Discord */}
                          {discordId &&
                          discordId !== 'Not Linked' &&
                          discordId !== 'unknown' &&
                          discordId.trim() !== '' ? (
                            <div
                              onClick={() => handleCopy(discordId, `${admin.Identifier}-discord`)}
                              className="flex items-center justify-between bg-bg-secondary/40 hover:bg-[#5865F2]/10 border border-border/50 hover:border-[#5865F2]/40 p-2.5 rounded-xl cursor-pointer transition-colors group/chip"
                              title={t('ui.pages.access.management.copy_discord')}
                            >
                              <span className="flex items-center gap-2.5 min-w-0">
                                <div className="w-6 h-6 rounded-md bg-[#5865F2]/12 flex items-center justify-center text-[#5865F2] shrink-0">
                                  <i className="fa-brands fa-discord text-xs"></i>
                                </div>
                                <span className="text-xs text-muted group-hover/chip:text-primary transition-colors truncate">
                                  {discordId}
                                </span>
                              </span>
                              <div className="flex items-center gap-1.5 shrink-0">
                                <span className="text-[11px] text-muted/70">Discord</span>
                                <i
                                  className={`text-[11px] transition-colors ${copiedId === `${admin.Identifier}-discord` ? 'fa-solid fa-check text-success' : 'fa-regular fa-copy text-muted/70 group-hover/chip:text-[#5865F2]'}`}
                                ></i>
                              </div>
                            </div>
                          ) : null}

                          {/* Steam */}
                          {steamHex && steamHex !== 'Not Linked' && steamHex !== 'unknown' && steamHex.trim() !== '' ? (
                            <div className="flex items-center justify-between bg-bg-secondary/40 hover:border-[#66c0f4]/40 border border-border/50 p-2.5 rounded-xl transition-colors group/chip">
                              <div
                                onClick={() => handleCopy(steamHex, `${admin.Identifier}-steam`)}
                                className="flex items-center gap-2.5 min-w-0 flex-1 cursor-pointer"
                                title={t('ui.pages.access.management.copy_steam')}
                              >
                                <div className="w-6 h-6 rounded-md bg-[#66c0f4]/12 flex items-center justify-center text-[#66c0f4] shrink-0">
                                  <i className="fa-brands fa-steam text-xs"></i>
                                </div>
                                <span className="text-xs text-muted group-hover/chip:text-primary transition-colors truncate">
                                  {steamHex}
                                </span>
                              </div>
                              <div className="flex items-center gap-2 shrink-0">
                                {steamProfileLink && (
                                  <button
                                    onClick={() => openExternalUrl(steamProfileLink)}
                                    className="w-5 h-5 rounded hover:bg-[#66c0f4]/20 text-[#66c0f4]/70 hover:text-[#66c0f4] flex items-center justify-center transition-colors"
                                    title={t('ui.pages.access.management.open_steam')}
                                  >
                                    <i className="fa-solid fa-arrow-up-right-from-square text-[10px]"></i>
                                  </button>
                                )}
                                <div
                                  onClick={() => handleCopy(steamHex, `${admin.Identifier}-steam`)}
                                  className="flex items-center gap-1.5 cursor-pointer"
                                >
                                  <span className="text-[11px] text-muted/70">Steam</span>
                                  <i
                                    className={`text-[11px] transition-colors ${copiedId === `${admin.Identifier}-steam` ? 'fa-solid fa-check text-success' : 'fa-regular fa-copy text-muted/70 group-hover/chip:text-[#66c0f4]'}`}
                                  ></i>
                                </div>
                              </div>
                            </div>
                          ) : null}

                          {/* Identifier */}
                          <div
                            onClick={() => handleCopy(admin.Identifier, `${admin.Identifier}-ident`)}
                            className="flex items-center justify-between bg-bg-secondary/40 hover:bg-accent/[0.06] border border-border/50 hover:border-accent/30 p-2.5 rounded-xl cursor-pointer transition-colors group/chip"
                            title={t('ui.pages.access.management.copy_identifier')}
                          >
                            <span className="flex items-center gap-2.5 min-w-0">
                              <div className="w-6 h-6 rounded-md bg-accent/12 flex items-center justify-center text-accent shrink-0">
                                <i
                                  className={`fa-solid ${admin.Identifier.startsWith('role:') ? 'fa-users-gear' : 'fa-key'} text-[11px]`}
                                ></i>
                              </div>
                              <span className="font-mono text-[11px] text-muted group-hover/chip:text-primary transition-colors truncate">
                                {admin.Identifier}
                              </span>
                            </span>
                            <div className="flex items-center gap-1.5 shrink-0">
                              <span className="text-[11px] text-muted/70">Identifier</span>
                              <i
                                className={`text-[11px] transition-colors ${copiedId === `${admin.Identifier}-ident` ? 'fa-solid fa-check text-success' : 'fa-regular fa-copy text-muted/70 group-hover/chip:text-accent'}`}
                              ></i>
                            </div>
                          </div>

                          {/* Duty hours */}
                          {!admin.Identifier.startsWith('role:') && (
                            <div className="flex items-center justify-between bg-bg-secondary/40 border border-border/50 p-2.5 rounded-xl">
                              <span className="flex items-center gap-2.5 min-w-0">
                                <div className="w-6 h-6 rounded-md bg-emerald-500/12 flex items-center justify-center text-emerald-400 shrink-0">
                                  <i className="fa-regular fa-clock text-[11px]"></i>
                                </div>
                                <span className="text-xs text-muted truncate">{formatDutyTime(admin.DutySeconds)}</span>
                              </span>
                              <span className="text-[11px] text-muted/70 shrink-0">Duty Time</span>
                            </div>
                          )}

                          {/* Expiration */}
                          {admin.IsTemp && admin.Expires && (
                            <div className="bg-warning/[0.07] border border-warning/20 rounded-xl p-2.5 flex items-center justify-between">
                              <div className="flex items-center gap-2 text-warning text-xs font-medium">
                                <i className="fa-regular fa-clock"></i>
                                <span>{t('ui.pages.access.management.temp_staff_access')}</span>
                              </div>
                              <span className="text-[11px] font-mono text-warning/90 bg-warning/10 px-2 py-0.5 rounded-md">
                                {(function () {
                                  const exp = admin.Expires;
                                  if (typeof exp === 'number') {
                                    const d = new Date(exp * 1000);
                                    return `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
                                  }
                                  if (exp && exp.day) {
                                    return `${exp.day.toString().padStart(2, '0')}/${exp.month.toString().padStart(2, '0')}/${exp.year}`;
                                  }
                                  return 'Unknown';
                                })()}
                              </span>
                            </div>
                          )}
                        </div>

                        {/* Granted permissions preview */}
                        {rank && (
                          <div className="mt-auto pt-3.5 border-t border-border/40">
                            <span className="text-[11px] font-medium text-muted mb-2 flex items-center gap-1.5">
                              <i className="fa-solid fa-key text-[10px] text-accent/60"></i>
                              {t('ui.pages.access.ranks.granted_permissions')}
                            </span>
                            <div className="flex flex-wrap gap-1">
                              {rank.Permissions.includes('all') ? (
                                <span className="bg-success/10 text-success text-[11px] font-medium px-2 py-0.5 rounded-md">
                                  Full access (*)
                                </span>
                              ) : rank.Permissions.length === 0 ? (
                                <span className="bg-danger/10 text-danger text-[11px] font-medium px-2 py-0.5 rounded-md">
                                  {t('ui.pages.access.ranks.no_access')}
                                </span>
                              ) : (
                                <>
                                  {rank.Permissions.slice(0, 4).map((perm) => (
                                    <span
                                      key={perm}
                                      className="bg-accent/[0.08] text-accent text-[11px] px-1.5 py-0.5 rounded-md truncate max-w-[130px]"
                                      title={perm}
                                    >
                                      {perm}
                                    </span>
                                  ))}
                                  {rank.Permissions.length > 4 && (
                                    <span
                                      className="bg-bg-secondary/70 text-muted border border-border/50 text-[11px] px-1.5 py-0.5 rounded-md cursor-help"
                                      title={rank.Permissions.slice(4).join(', ')}
                                    >
                                      +{rank.Permissions.length - 4} more
                                    </span>
                                  )}
                                </>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {(isAddRankModalOpen || rankToEdit) && (
        <div className="absolute inset-0 bg-black/70 z-50 flex items-center justify-center p-6">
          <div className="bg-bg-primary border border-border rounded-2xl w-full max-w-md overflow-hidden flex flex-col">
            {/* Header */}
            <div className="px-6 py-5 border-b border-border/60 flex items-center justify-between shrink-0">
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center text-accent">
                  <i className={`fa-solid ${rankToEdit ? 'fa-pen' : 'fa-plus'} text-base`}></i>
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-primary leading-none">
                    {rankToEdit ? t('ui.pages.access.ranks.modify') : t('ui.pages.access.ranks.register')}
                  </h2>
                  <p className="text-sm text-muted mt-1.5">{t('ui.pages.access.ranks.authority_config')}</p>
                </div>
              </div>
              <button
                onClick={() => {
                  setIsAddRankModalOpen(false);
                  setRankToEdit(null);
                }}
                className="w-8 h-8 rounded-lg hover:bg-bg-secondary text-muted hover:text-primary transition-colors flex items-center justify-center"
              >
                <i className="fa-solid fa-xmark text-sm"></i>
              </button>
            </div>

            {/* Body */}
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-muted mb-2">
                  {t('ui.pages.access.ranks.id_label')}
                </label>
                <div className="relative">
                  <i className="fa-solid fa-hashtag absolute left-4 top-1/2 -translate-y-1/2 text-muted text-sm"></i>
                  <input
                    type="text"
                    value={rankForm.Id || ''}
                    onChange={(e) => setRankForm({ ...rankForm, Id: e.target.value })}
                    disabled={!!rankToEdit}
                    className="w-full bg-bg-secondary/50 border border-border/60 rounded-xl pl-11 pr-4 py-3 text-primary font-mono text-sm focus:outline-none focus:border-accent transition-colors placeholder:text-muted/50 disabled:opacity-50"
                    placeholder={t('ui.pages.access.ranks.id_placeholder')}
                  />
                </div>
                {!rankToEdit && <p className="text-[11px] text-muted mt-2">{t('ui.pages.access.ranks.id_note')}</p>}
              </div>

              <div>
                <label className="block text-sm font-medium text-muted mb-2">
                  {t('ui.pages.access.ranks.name_label')}
                </label>
                <div className="relative">
                  <i className="fa-solid fa-signature absolute left-4 top-1/2 -translate-y-1/2 text-muted text-sm"></i>
                  <input
                    type="text"
                    value={rankForm.Name || ''}
                    onChange={(e) => setRankForm({ ...rankForm, Name: e.target.value })}
                    className="w-full bg-bg-secondary/50 border border-border/60 rounded-xl pl-11 pr-4 py-3 text-primary text-base focus:outline-none focus:border-accent transition-colors placeholder:text-muted/50"
                    placeholder={t('ui.pages.access.ranks.name_placeholder')}
                  />
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="px-6 py-5 border-t border-border/60 flex gap-3 shrink-0">
              <button
                onClick={() => {
                  setIsAddRankModalOpen(false);
                  setRankToEdit(null);
                }}
                className="flex-1 py-3 rounded-xl bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary font-medium text-sm transition-colors"
              >
                {t('ui.pages.access.ranks.discard')}
              </button>
              <button
                onClick={handleSaveRank}
                disabled={!rankForm.Id || !rankForm.Name}
                className="flex-[2] py-3 rounded-xl bg-accent hover:bg-accent/90 text-white font-medium text-sm transition-colors disabled:opacity-30 flex items-center justify-center gap-2"
              >
                <i className="fa-solid fa-check"></i>
                {t('ui.pages.access.ranks.commit')}
              </button>
            </div>
          </div>
        </div>
      )}

      {rankToDelete && (
        <div className="absolute inset-0 bg-black/70 z-50 flex items-center justify-center p-6">
          <div className="bg-bg-primary border border-danger/30 rounded-2xl w-full max-w-md overflow-hidden flex flex-col">
            <div className="px-6 py-5 border-b border-border/60 flex items-start justify-between shrink-0">
              <div className="flex items-center gap-3.5">
                <div className="w-11 h-11 rounded-xl bg-danger/12 border border-danger/25 flex items-center justify-center text-danger shrink-0">
                  <i className="fa-solid fa-triangle-exclamation text-lg"></i>
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-primary leading-none">
                    {t('ui.pages.access.ranks.delete_rank_title')}
                  </h2>
                  <p className="text-sm text-danger mt-1.5">{t('ui.pages.access.ranks.irreversible_action')}</p>
                </div>
              </div>
              <button
                onClick={() => setRankToDelete(null)}
                className="w-8 h-8 rounded-lg hover:bg-bg-secondary text-muted hover:text-primary transition-colors flex items-center justify-center"
              >
                <i className="fa-solid fa-xmark text-sm"></i>
              </button>
            </div>

            <div className="p-6 text-center">
              <p className="text-muted leading-relaxed text-sm">
                You are about to delete the{' '}
                <span className="text-primary font-medium px-2 py-0.5 rounded-md bg-bg-secondary/70">
                  {rankToDelete.Name}
                </span>{' '}
                rank.
                <br />
                <br />
                This immediately revokes access for all assigned staff members and cannot be undone.
              </p>
            </div>

            <div className="px-6 py-5 border-t border-border/60 flex gap-3 shrink-0">
              <button
                onClick={() => setRankToDelete(null)}
                className="flex-1 py-3 rounded-xl bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary font-medium text-sm transition-colors"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={handleDeleteRank}
                className="flex-[2] py-3 rounded-xl bg-danger hover:bg-danger/90 text-white font-medium text-sm transition-colors flex items-center justify-center gap-2"
              >
                <i className="fa-solid fa-trash-can"></i>
                {t('ui.pages.access.management.purge_title')}
              </button>
            </div>
          </div>
        </div>
      )}

      {(isAddAdminModalOpen || adminToEdit) && (
        <div className="absolute inset-0 bg-black/70 z-50 flex items-center justify-center p-6">
          <div className="bg-bg-primary border border-border rounded-2xl w-full max-w-[520px] flex flex-col overflow-hidden">
            {/* Header */}
            <div className="px-6 py-5 flex items-center justify-between shrink-0 border-b border-border/60">
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center text-accent">
                  <i className={`fa-solid ${adminToEdit ? 'fa-user-pen' : 'fa-user-plus'} text-base`}></i>
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-primary leading-none">
                    {adminToEdit
                      ? t('ui.pages.access.management.edit_title')
                      : t('ui.pages.access.management.add_title')}
                  </h2>
                  <p className="text-sm text-muted mt-1.5">{t('ui.pages.access.management.auth_subtitle')}</p>
                </div>
              </div>
              <button
                onClick={() => {
                  setIsAddAdminModalOpen(false);
                  setAdminToEdit(null);
                }}
                className="w-8 h-8 rounded-lg hover:bg-bg-secondary text-muted hover:text-primary transition-colors flex items-center justify-center"
              >
                <i className="fa-solid fa-xmark text-sm"></i>
              </button>
            </div>

            <div className="p-6 space-y-5">
              {/* Identification */}
              <div className="flex gap-3">
                <div className="w-1/3 flex flex-col relative">
                  <label className="text-sm font-medium text-muted mb-2">{t('ui.pages.access.management.type')}</label>
                  <button
                    onClick={(e) => {
                      const position = dropdownPositionFrom(e.currentTarget);
                      setDropdown((prev) => {
                        if (prev && prev.id === 'method-selector') return null;
                        return {
                          id: 'method-selector',
                          name: t('ui.pages.access.management.id_method'),
                          options: [
                            {
                              Text: t('ui.pages.access.management.methods.license'),
                              Callback: () => {
                                setIdType('LICENSE');
                                setAdminForm((p) => ({ ...p, Identifier: '', CharacterId: '', DiscordRoles: [] }));
                              },
                            },
                            {
                              Text: t('ui.pages.access.management.methods.steam'),
                              Callback: () => {
                                setIdType('STEAM');
                                setAdminForm((p) => ({ ...p, Identifier: '', CharacterId: '', DiscordRoles: [] }));
                              },
                            },
                            {
                              Text: t('ui.pages.access.management.methods.discord'),
                              Callback: () => {
                                setIdType('DISCORD');
                                setAdminForm((p) => ({ ...p, Identifier: '', CharacterId: '', DiscordRoles: [] }));
                              },
                            },
                            {
                              Text: t('ui.pages.access.management.methods.discord_role'),
                              Callback: () => {
                                setIdType('DISCORD ROLE');
                                setAdminForm((p) => ({ ...p, Identifier: '', CharacterId: '', DiscordRoles: [] }));
                              },
                            },
                            {
                              Text: t('ui.pages.access.management.methods.player'),
                              Callback: () => {
                                setIdType('CHARACTER');
                                setAdminForm((p) => ({ ...p, Identifier: '', CharacterId: '', DiscordRoles: [] }));
                              },
                            },
                          ],
                          position,
                          hasSearch: false,
                        };
                      });
                    }}
                    className="w-full bg-bg-secondary/50 border border-border/60 hover:border-border rounded-xl px-3 py-2.5 text-primary text-sm font-medium flex items-center justify-between transition-colors"
                  >
                    <span className="flex items-center gap-2 truncate">
                      <i
                        className={`${idType === 'STEAM' ? 'fa-brands fa-steam' : idType === 'DISCORD' ? 'fa-brands fa-discord' : idType === 'DISCORD ROLE' ? 'fa-solid fa-users-gear' : idType === 'CHARACTER' ? 'fa-solid fa-user-tag' : 'fa-solid fa-address-card'} text-accent/80 text-xs`}
                      ></i>
                      <span className="truncate">
                        {idType === 'DISCORD ROLE'
                          ? t('ui.pages.access.management.methods.discord_role')
                          : idType === 'CHARACTER'
                            ? t('ui.pages.access.management.methods.player')
                            : idType === 'DISCORD'
                              ? t('ui.pages.access.management.methods.discord')
                              : idType.charAt(0) + idType.slice(1).toLowerCase()}
                      </span>
                    </span>
                    <i className="fa-solid fa-chevron-down text-[10px] text-muted shrink-0"></i>
                  </button>
                </div>

                <div className="w-2/3 flex flex-col">
                  <label className="text-sm font-medium text-muted mb-2 flex justify-between">
                    {t('ui.pages.access.management.identifier')}
                    {(idType === 'CHARACTER' || idType === 'DISCORD ROLE') && (
                      <span className="text-muted/70 font-normal">
                        {t('ui.pages.access.management.search_to_select')}
                      </span>
                    )}
                  </label>

                  {idType === 'CHARACTER' ? (
                    <div className="relative">
                      <i className="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-muted text-xs"></i>
                      <input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        onFocus={() => setIsPlayerSearchFocused(true)}
                        onBlur={() => setTimeout(() => setIsPlayerSearchFocused(false), 200)}
                        placeholder={t('ui.pages.access.management.search_player')}
                        className="w-full bg-bg-secondary/50 border border-border/60 rounded-xl pl-9 pr-3 py-2.5 text-primary text-sm focus:outline-none focus:border-accent/60 transition-colors placeholder:text-muted/60"
                      />
                      {(searchQuery || isPlayerSearchFocused) && (
                        <div className="absolute top-full left-0 right-0 mt-1 max-h-40 overflow-y-auto custom-scrollbar bg-bg-secondary border border-border rounded-xl z-20">
                          {(dbPlayers.length > 0 ? dbPlayers : players)
                            .filter(
                              (p) =>
                                p.Name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                                (p.CitizenId && p.CitizenId.toLowerCase().includes(searchQuery.toLowerCase())),
                            )
                            .slice(0, 50)
                            .map((p) => {
                              const isSelected =
                                adminForm.CharacterId === p.CitizenId || adminForm.Identifier === p.License;
                              return (
                                <div
                                  key={p.CitizenId || p.ServerId}
                                  className={`w-full p-2.5 text-sm flex items-center justify-between border-b border-border/40 last:border-0 hover:bg-bg-primary/50 ${isSelected ? 'bg-accent/8' : ''}`}
                                >
                                  <div className="flex flex-col min-w-0 pr-2">
                                    <span
                                      className={`font-medium truncate ${isSelected ? 'text-accent' : 'text-primary'}`}
                                    >
                                      {p.Name}
                                    </span>
                                    <span className="text-[11px] font-mono text-muted truncate">
                                      CID: {p.CitizenId || 'Unknown'}
                                    </span>
                                  </div>
                                  <div className="flex gap-1 shrink-0">
                                    {p.CitizenId && (
                                      <button
                                        onClick={() => {
                                          setAdminForm({
                                            ...adminForm,
                                            Identifier: p.CitizenId,
                                            CharacterId: p.CitizenId,
                                          });
                                          setSearchQuery('');
                                        }}
                                        className="px-2 py-1 bg-success/10 hover:bg-success/20 rounded-md text-[11px] font-medium text-success transition-colors"
                                        title={t('ui.pages.access.management.add_by_cid')}
                                      >
                                        CID
                                      </button>
                                    )}
                                    {p.License && (
                                      <button
                                        onClick={() => {
                                          setAdminForm({
                                            ...adminForm,
                                            Identifier: p.License,
                                            CharacterId: p.CitizenId || '',
                                          });
                                          setSearchQuery('');
                                        }}
                                        className="px-2 py-1 bg-bg-primary/70 hover:bg-bg-primary rounded-md text-[11px] font-medium text-muted transition-colors"
                                        title={t('ui.pages.access.management.add_by_license')}
                                      >
                                        Lic
                                      </button>
                                    )}
                                  </div>
                                </div>
                              );
                            })}
                        </div>
                      )}
                      {adminForm.Identifier && !searchQuery && (
                        <div className="absolute inset-y-0 right-3 flex items-center pointer-events-none">
                          <span className="text-[11px] bg-accent/15 text-accent px-1.5 py-0.5 rounded font-mono font-medium">
                            Set ✓
                          </span>
                        </div>
                      )}
                    </div>
                  ) : idType === 'DISCORD ROLE' ? (
                    <div className="relative flex flex-col gap-2">
                      <div className="relative">
                        <i className="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-muted text-xs"></i>
                        <input
                          type="text"
                          value={searchQuery}
                          onChange={(e) => setSearchQuery(e.target.value)}
                          onFocus={() => setIsRoleSearchFocused(true)}
                          onBlur={() => setTimeout(() => setIsRoleSearchFocused(false), 200)}
                          placeholder={t('ui.pages.access.management.search_role')}
                          className="w-full bg-bg-secondary/50 border border-border/60 rounded-xl pl-9 pr-3 py-2.5 text-primary text-sm focus:outline-none focus:border-accent/60 transition-colors placeholder:text-muted/60"
                        />
                        {(searchQuery || isRoleSearchFocused) && (
                          <div className="absolute top-full left-0 right-0 mt-1 max-h-48 overflow-y-auto custom-scrollbar bg-bg-secondary border border-border rounded-xl z-20 p-1">
                            {discordRoles.length === 0 ? (
                              <div className="p-3 text-center text-muted text-xs">
                                <i className="fa-brands fa-discord text-xl mb-1 text-warning opacity-70"></i>
                                <p className="font-medium">{t('ui.pages.access.management.no_discord_roles')}</p>
                                <p className="mt-1 opacity-70">
                                  Discord Bot Token & Guild ID are not configured or Discord API is offline.
                                </p>
                              </div>
                            ) : (
                              discordRoles
                                .filter((r) => r.name.toLowerCase().includes(searchQuery.toLowerCase()))
                                .slice(0, 50)
                                .map((r) => {
                                  const isSelected = adminForm.DiscordRoles?.includes(r.id);
                                  const roleColor = r.color
                                    ? `#${r.color.toString(16).padStart(6, '0')}`
                                    : 'rgb(var(--accent))';
                                  return (
                                    <button
                                      key={r.id}
                                      onClick={() => {
                                        const currentRoles = adminForm.DiscordRoles || [];
                                        const alreadyIn = currentRoles.includes(r.id);
                                        const newRoles = alreadyIn
                                          ? currentRoles.filter((id) => id !== r.id)
                                          : [...currentRoles, r.id];

                                        setAdminForm({
                                          ...adminForm,
                                          Identifier: newRoles.length > 0 ? `role:${newRoles[0]}` : '',
                                          DiscordRoles: newRoles,
                                        });
                                        setSearchQuery('');
                                      }}
                                      className={`w-full text-left p-2 rounded-lg text-sm flex items-center justify-between hover:bg-bg-primary/50 transition-colors mb-0.5 ${isSelected ? 'bg-accent/10' : ''}`}
                                    >
                                      <span className="flex items-center gap-2">
                                        <div
                                          className="w-3 h-3 rounded-full"
                                          style={{ backgroundColor: roleColor }}
                                        ></div>
                                        <span className={isSelected ? 'text-accent font-medium' : 'text-primary'}>
                                          {r.name}
                                        </span>
                                      </span>
                                      {isSelected && <i className="fa-solid fa-check text-[11px] text-accent"></i>}
                                    </button>
                                  );
                                })
                            )}

                            {/* Manual add fallback */}
                            {searchQuery.trim() && (
                              <button
                                onClick={() => {
                                  const cleanQuery = searchQuery.trim();
                                  const currentRoles = adminForm.DiscordRoles || [];
                                  const alreadyIn = currentRoles.includes(cleanQuery);
                                  const newRoles = alreadyIn
                                    ? currentRoles.filter((id) => id !== cleanQuery)
                                    : [...currentRoles, cleanQuery];

                                  setAdminForm({
                                    ...adminForm,
                                    Identifier: newRoles.length > 0 ? `role:${newRoles[0]}` : '',
                                    DiscordRoles: newRoles,
                                  });
                                  setSearchQuery('');
                                }}
                                className="w-full text-left p-2 rounded-lg text-xs bg-accent/10 hover:bg-accent/20 text-accent transition-colors flex items-center justify-between mt-1"
                              >
                                <span className="flex items-center gap-2 font-medium">
                                  <i className="fa-solid fa-plus text-xs"></i>
                                  <span>
                                    {t('ui.pages.access.management.use_custom_role_id')}{' '}
                                    <strong className="font-mono text-primary ml-1">{searchQuery}</strong>
                                  </span>
                                </span>
                                <i className="fa-solid fa-chevron-right text-[10px]"></i>
                              </button>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Selected role chips */}
                      {adminForm.DiscordRoles && adminForm.DiscordRoles.length > 0 && (
                        <div className="flex flex-wrap gap-1.5 p-2 bg-bg-secondary/40 rounded-xl border border-border/50">
                          {adminForm.DiscordRoles.map((roleId) => {
                            const role = discordRoles.find((r) => r.id === roleId);
                            const roleColor = role?.color
                              ? `#${role.color.toString(16).padStart(6, '0')}`
                              : 'rgb(var(--accent))';
                            return (
                              <div
                                key={roleId}
                                className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-bg-primary/50 border border-border/50 text-[11px] font-medium text-primary"
                                style={{ borderLeft: `3px solid ${roleColor}` }}
                              >
                                {role?.name || roleId}
                                <button
                                  onClick={() =>
                                    setAdminForm((prev) => ({
                                      ...prev,
                                      DiscordRoles: prev.DiscordRoles?.filter((id) => id !== roleId),
                                    }))
                                  }
                                  className="text-muted hover:text-danger transition-colors"
                                >
                                  <i className="fa-solid fa-xmark"></i>
                                </button>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="flex flex-col gap-1 w-full">
                      <input
                        type="text"
                        value={adminForm.Identifier || ''}
                        onChange={(e) => setAdminForm({ ...adminForm, Identifier: e.target.value })}
                        onBlur={(e) => {
                          let val = e.target.value;
                          if (idType === 'STEAM') {
                            val = formatSteamIdentifier(val);
                            setAdminForm((prev) => ({ ...prev, Identifier: val }));
                          }
                        }}
                        className="w-full bg-bg-secondary/50 border border-border/60 hover:border-border rounded-xl px-3 py-2.5 text-primary font-mono text-sm focus:outline-none focus:border-accent transition-colors placeholder:text-muted/50"
                        placeholder={`Enter ${idType.toLowerCase()}...`}
                      />
                      {idType === 'STEAM' && (
                        <div className="text-[11px] text-muted leading-tight mt-1 flex flex-col gap-0.5">
                          <span>• Accepts SteamID64 (e.g. 76561199066607211), profiles URL, or Steam Hex.</span>
                          <span className="text-warning/80">
                            • Custom /id/ vanity URLs must be converted to SteamID64 first.
                          </span>
                        </div>
                      )}
                      {idType === 'DISCORD' && (
                        <div className="text-[11px] text-muted leading-tight mt-1">
                          <span>• Enter raw Discord User ID (e.g. 767828210139834159).</span>
                        </div>
                      )}
                      {idType === 'LICENSE' && (
                        <div className="text-[11px] text-muted leading-tight mt-1">
                          <span>• Enter raw FiveM License (e.g. license:abc123xyz...).</span>
                        </div>
                      )}
                    </div>
                  )}
                  {adminForm.Identifier && (idType === 'CHARACTER' || idType === 'DISCORD ROLE') && (
                    <div className="mt-1.5 text-[11px] font-mono text-accent/80 truncate w-full flex items-center gap-1.5">
                      <span className="text-muted">{t('ui.pages.access.management.selected')}</span>
                      <span className="text-primary font-medium">
                        {idType === 'DISCORD ROLE'
                          ? adminForm.DiscordRoles && adminForm.DiscordRoles.length > 1
                            ? `${adminForm.DiscordRoles.length} Roles Selected (${discordRoles.find((r) => r.id === adminForm.DiscordRoles?.[0])?.name}...)`
                            : discordRoles.find((r) => `role:${r.id}` === adminForm.Identifier)?.name ||
                              adminForm.Identifier
                          : dbPlayers.find(
                              (p) =>
                                p.CitizenId === adminForm.Identifier ||
                                p.Steam === adminForm.Identifier ||
                                p.License === adminForm.Identifier,
                            )?.Name || adminForm.Identifier}
                      </span>
                    </div>
                  )}
                </div>
              </div>

              {/* Rank */}
              <div className="flex flex-col relative z-0">
                <label className="text-sm font-medium text-muted mb-2">
                  {t('ui.pages.access.management.authority_level')}
                </label>
                <button
                  onClick={(e) => {
                    const position = dropdownPositionFrom(e.currentTarget);
                    setDropdown((prev) => {
                      if (prev && prev.id === 'rank-selector') return null;
                      return {
                        id: 'rank-selector',
                        name: 'Select Rank',
                        options: ranks.map((r) => ({
                          Text: `${r.Name} (${r.Permissions.length} perms)`,
                          Callback: () => setAdminForm((p) => ({ ...p, RankId: r.Id })),
                        })),
                        position,
                        hasSearch: false,
                      };
                    });
                  }}
                  className="w-full bg-bg-secondary/50 border border-border/60 hover:border-accent/50 rounded-xl px-4 py-3 text-primary text-sm font-medium flex items-center justify-between transition-colors"
                >
                  <span className="flex items-center gap-3">
                    <div className="w-6 h-6 rounded-md bg-accent text-white flex items-center justify-center shrink-0">
                      <i className="fa-solid fa-shield-halved text-[10px]"></i>
                    </div>
                    {ranks.find((r) => r.Id === adminForm.RankId)?.Name || 'Select a rank...'}
                  </span>
                  <div className="flex items-center gap-2">
                    {adminForm.RankId && (
                      <span className="text-[11px] font-mono text-accent bg-accent/10 px-1.5 py-0.5 rounded">
                        {ranks.find((r) => r.Id === adminForm.RankId)?.Permissions.length} perms
                      </span>
                    )}
                    <i className="fa-solid fa-chevron-down text-[10px] text-muted ml-1"></i>
                  </div>
                </button>
              </div>

              {/* Webhook */}
              <div className="flex flex-col relative z-0">
                <label className="text-sm font-medium text-muted mb-2 flex items-center justify-between">
                  <span>Discord Webhook</span>
                  <span className="text-[10px] bg-bg-secondary px-1.5 py-0.5 rounded text-muted">Optional</span>
                </label>
                <input
                  type="text"
                  value={adminForm.Webhook || ''}
                  onChange={(e) => setAdminForm({ ...adminForm, Webhook: e.target.value })}
                  className="w-full bg-bg-secondary/50 border border-border/60 hover:border-border rounded-xl px-4 py-3 text-primary text-sm focus:outline-none focus:border-accent transition-colors placeholder:text-muted/50"
                  placeholder="Leave empty to auto-generate..."
                />
                <div className="mt-3">
                  <label className="text-[11px] font-medium text-muted mb-1.5 block">Events to Log</label>
                  <div className="flex flex-wrap gap-1.5">
                    {['all', 'ban', 'kick', 'unban', 'report', 'duty', 'adminlog', 'exploit', 'warn'].map((ev) => {
                      const isSelected = (adminForm.WebhookEvents || ['all']).includes(ev);
                      return (
                        <button
                          key={ev}
                          onClick={() => {
                            let current = adminForm.WebhookEvents || ['all'];
                            if (ev === 'all') current = ['all'];
                            else {
                              current = current.filter((e) => e !== 'all');
                              if (current.includes(ev)) current = current.filter((e) => e !== ev);
                              else current = [...current, ev];
                              if (current.length === 0) current = ['all'];
                            }
                            setAdminForm({ ...adminForm, WebhookEvents: current });
                          }}
                          className={`px-2 py-1 rounded-md text-[11px] font-medium transition-colors ${isSelected ? 'bg-accent/15 text-accent border border-accent/30' : 'bg-bg-secondary border border-border/50 text-muted hover:text-primary'}`}
                        >
                          {ev.charAt(0).toUpperCase() + ev.slice(1)}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Expiration */}
              <div className="flex flex-col">
                <div className="flex items-center justify-between mb-3 border-t border-border/50 pt-4">
                  <label className="text-sm font-medium text-muted">
                    {t('ui.pages.access.management.access_expiration')}
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      const now = new Date();
                      const newIsTemp = !adminForm.IsTemp;
                      const nextForm = { ...adminForm, IsTemp: newIsTemp };
                      if (newIsTemp && !adminForm.Expires) {
                        nextForm.Expires = {
                          day: now.getDate() + 1,
                          month: now.getMonth() + 1,
                          year: now.getFullYear(),
                          hour: now.getHours(),
                          min: now.getMinutes(),
                        };
                      }
                      setAdminForm(nextForm);
                    }}
                    className={`flex items-center gap-1.5 text-xs font-medium transition-colors ${adminForm.IsTemp ? 'text-warning' : 'text-muted hover:text-primary'}`}
                  >
                    <i
                      className={`fa-solid ${adminForm.IsTemp ? 'fa-toggle-on text-base' : 'fa-toggle-off text-base'} transition-all`}
                    ></i>
                    <span className="leading-none">{t('ui.pages.access.management.temp_status')}</span>
                  </button>
                </div>

                {adminForm.IsTemp ? (
                  <div className="bg-warning/[0.06] border border-warning/20 rounded-xl p-4">
                    <DateTimePicker
                      value={
                        typeof adminForm.Expires === 'number'
                          ? (function () {
                              const d = new Date(adminForm.Expires * 1000);
                              return {
                                day: d.getDate(),
                                month: d.getMonth() + 1,
                                year: d.getFullYear(),
                                hour: d.getHours(),
                                min: d.getMinutes(),
                              };
                            })()
                          : adminForm.Expires
                      }
                      onChange={(val) => setAdminForm({ ...adminForm, Expires: val })}
                    />
                    <div className="mt-3 flex items-center gap-2 text-[11px] text-warning/80 font-medium">
                      <i className="fa-solid fa-circle-exclamation"></i>
                      <span>{t('ui.pages.access.management.temp_status_desc')}</span>
                    </div>
                  </div>
                ) : (
                  <div className="bg-bg-secondary/40 border border-border/50 rounded-xl py-3 px-4 flex items-center gap-3">
                    <i className="fa-solid fa-infinity text-accent/60 text-base"></i>
                    <span className="text-xs text-accent/80 font-medium">
                      {t('ui.pages.access.management.perm_registry_active')}
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Footer */}
            <div className="p-6 border-t border-border/60 flex flex-col gap-3 shrink-0">
              {duplicateAdminError && (
                <div className="flex items-center gap-2 text-[11px] text-danger font-medium bg-danger/10 border border-danger/30 rounded-lg py-2 px-3">
                  <i className="fa-solid fa-triangle-exclamation"></i>
                  <span>{t('ui.pages.access.management.already_admin')}</span>
                </div>
              )}
              <div className="flex gap-3">
                <button
                  onClick={() => {
                    setIsAddAdminModalOpen(false);
                    setAdminToEdit(null);
                    setDropdown(null);
                  }}
                  className="flex-1 py-3 rounded-xl bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary font-medium text-sm transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveAdmin}
                  disabled={!adminForm.Identifier || !adminForm.RankId}
                  className="flex-[2] py-3 rounded-xl bg-accent hover:bg-accent/90 text-white font-medium text-sm transition-colors disabled:opacity-30 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  <i className={`fa-solid ${adminToEdit ? 'fa-check' : 'fa-user-shield'} text-xs`}></i>
                  Confirm
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {adminToDelete && (
        <div className="absolute inset-0 bg-black/70 z-50 flex items-center justify-center p-6">
          <div className="bg-bg-primary border border-danger/30 rounded-2xl w-full max-w-md p-6">
            <div className="w-14 h-14 rounded-2xl bg-danger/12 border border-danger/25 flex items-center justify-center text-danger text-2xl mx-auto mb-5">
              <i className="fa-solid fa-triangle-exclamation"></i>
            </div>
            <h2 className="text-xl font-semibold text-primary mb-3 text-center leading-tight">Revoke access</h2>
            <p className="text-muted text-center mb-7 text-sm leading-relaxed">
              This removes all administrative privileges from{' '}
              <span className="text-danger font-mono bg-danger/12 px-2 py-0.5 rounded-md font-medium">
                {adminToDelete.Identifier}
              </span>{' '}
              across the system.
            </p>

            <div className="flex gap-3">
              <button
                onClick={() => setAdminToDelete(null)}
                className="flex-1 py-3 rounded-xl font-medium text-sm bg-bg-secondary/70 hover:bg-bg-secondary text-muted hover:text-primary transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteAdmin}
                className="flex-1 py-3 rounded-xl font-medium text-sm bg-danger hover:bg-danger/90 text-white flex items-center justify-center gap-2 transition-colors"
              >
                <i className="fa-solid fa-trash-can text-sm"></i>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AccessControlPage;
