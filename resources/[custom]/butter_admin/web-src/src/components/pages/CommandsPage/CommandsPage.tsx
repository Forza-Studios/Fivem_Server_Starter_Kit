import React, { useState, useMemo, useRef, useEffect } from 'react';
import { useAdminMenu, toArray } from '../../../providers/AdminMenuContext';
import { Command, CommandCategory, CommandOption, DropdownChoice, DropdownPosition } from '../../../types';
import { fetchNui } from '../../../utils/fetchNui';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import Dropdown from '../../ui/Dropdown';
import { SubTabs } from '../../ui/SubTabs';
import { SearchField } from '../../ui/SearchField';
import { cn } from '../../../utils/cn';
import { dropdownPositionFrom } from '../../../utils/dropdownPosition';
import { formatPlayerListText } from '../../../utils/misc';

const CATEGORIES = ['All', 'Player', 'Utility', 'User', 'Fun'];

interface PlayerInfoData {
  ServerId?: number;
  CitizenId: string;
  Name: string;
  Job: string;
  JobGrade?: string;
  Gang: string;
  GangGrade?: string | null;
  Cash: number;
  Bank: number;
}

const fmtMoney = (n: number) => (Number(n) || 0).toLocaleString('en-US');

const getCommandStyle = (index: number, isExpanded: boolean, isActive?: boolean) => {
  let style = {
    bg: index % 2 === 0 ? 'bg-accent/5' : 'bg-accent/15',
    border: 'border-accent/20',
    hover: 'hover:border-accent/40 hover:bg-accent/20',
    text: 'text-primary',
    glow: '',
    icon: 'text-accent',
    btnBg: 'bg-accent/20',
    btnHover: 'hover:bg-accent/30',
    btnText: 'text-accent',
    btnBorder: 'border-accent/30',
  };

  if (isActive) {
    style = {
      bg: index % 2 === 0 ? 'bg-emerald-500/10' : 'bg-emerald-500/15',
      border: 'border-emerald-500/30',
      hover: 'hover:border-emerald-500/50 hover:bg-emerald-500/20',
      text: 'text-emerald-400 font-bold',
      glow: '',
      icon: 'text-emerald-400',
      btnBg: 'bg-emerald-500/25',
      btnHover: 'hover:bg-emerald-500/35',
      btnText: 'text-emerald-400',
      btnBorder: 'border-emerald-500/30',
    };
  } else if (isExpanded) {
    style.border = 'border-accent/40';
    style.bg = index % 2 === 0 ? 'bg-accent/5' : 'bg-accent/15';
  }

  return style;
};

const CHOICES_TIMEOUT = 20000; // ms

/** What a picked choice stored for an option: a player's server ID or a choice value. */
interface OptionData {
  PlayerId?: string | number;
  Value?: string | number;
}

type InputValue = string | number | boolean;

const hasValue = <T,>(value: T | null | undefined): value is T => value !== undefined && value !== null;

const CommandsPage: React.FC = () => {
  const {
    t,
    commands,
    favoritedItems,
    currentTarget,
    setCurrentTarget,
    players,
    toggleFavorite,
    menuSize,
    enabledItems,
    opened,
    playerNameFormat,
    licenseType,
  } = useAdminMenu();
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [searchText, setSearchText] = useState('');
  const [pinnedOnly, setPinnedOnly] = useState(false);
  const [expandedItems, setExpandedItems] = useState<Record<string, boolean>>({});
  const [inputValues, setInputValues] = useState<Record<string, Record<string, InputValue>>>({});
  const [inputData, setInputData] = useState<Record<string, Record<string, OptionData | null>>>({});
  const [confirmExecuteId, setConfirmExecuteId] = useState<string | null>(null);
  const [playerInfo, setPlayerInfo] = useState<PlayerInfoData | null>(null);
  // Choice lists are not shipped in the menu payload (they can run to thousands
  // of entries). They are pulled per provider when a dropdown using them is
  // opened; lists flagged ChoicesCache are then kept for the session.
  const choiceCache = useRef<Record<string, DropdownChoice[]>>({});
  // `${itemId}:${optionId}` of a dropdown whose list is still being fetched.
  const pendingDropdownKey = useRef<string | null>(null);
  const [dropdown, setDropdown] = useState<{
    options: DropdownChoice[];
    position: DropdownPosition;
    hasSearch: boolean;
    itemId: string;
    optionId: string;
    optionName?: string;
  } | null>(null);
  // Text typed into a choice field itself (it doubles as the dropdown's search box).
  const [dropdownSearch, setDropdownSearch] = useState('');

  // A loading dropdown that was closed or replaced must not be reopened when its
  // fetch finally resolves.
  useEffect(() => {
    const key = dropdown ? `${dropdown.itemId}:${dropdown.optionId}` : null;
    if (pendingDropdownKey.current && pendingDropdownKey.current !== key) {
      pendingDropdownKey.current = null;
    }
  }, [dropdown]);

  // Player Info results show inline under the command.
  useNuiEvent<PlayerInfoData>('showPlayerInfo', (data) => {
    setPlayerInfo(data);
    setExpandedItems({ playerinfo: true });
  });

  // The dropdown is anchored to a one-time snapshot of the input's
  // getBoundingClientRect(). When the menu resizes (Small <-> Large) the input
  // moves and the zoom changes, leaving the dropdown detached at stale coords.
  // Close it so it re-anchors correctly on the next open.
  useEffect(() => {
    setDropdown(null);
    if (!opened) {
      setExpandedItems({});
    }
  }, [menuSize, opened]);

  // Collect and sort all items
  const allItems = useMemo(() => {
    if (commands.length === 0) return [];
    const cmds = toArray<CommandCategory>(commands);
    let items: Command[] = [];

    if (selectedCategory === 'All') {
      cmds.forEach((cat) => {
        toArray<Command>(cat.Items).forEach((item) => items.push(item));
      });
    } else {
      cmds.forEach((cat) => {
        if (cat.Name === selectedCategory) {
          toArray<Command>(cat.Items).forEach((item) => items.push(item));
        }
      });
    }

    items.sort((a, b) => a.Name.localeCompare(b.Name));

    // Put favorited items first
    const favorited = items.filter((i) => favoritedItems[i.Id]);
    const nonFavorited = items.filter((i) => !favoritedItems[i.Id]);
    return [...favorited, ...nonFavorited];
  }, [commands, selectedCategory, favoritedItems]);

  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = { All: 0 };
    for (const cat of toArray<CommandCategory>(commands)) {
      const size = toArray<Command>(cat.Items).length;
      counts[cat.Name] = (counts[cat.Name] ?? 0) + size;
      counts.All += size;
    }
    return counts;
  }, [commands]);

  const filteredItems = useMemo(() => {
    const query = searchText.toLowerCase();
    return allItems.filter((item) => {
      if (pinnedOnly && !favoritedItems[item.Id]) return false;
      return !query || item.Name.toLowerCase().includes(query) || item.Id.toLowerCase().includes(query);
    });
  }, [allItems, searchText, pinnedOnly, favoritedItems]);

  const convertPlayerList = (): DropdownChoice[] => {
    return players.map((p) => ({
      Icon: undefined,
      Text: `[${p.ServerId}] ${formatPlayerListText(p, playerNameFormat, licenseType)}`,
      Source: p.ServerId,
    }));
  };

  const handleItemClick = (item: Command, e: React.MouseEvent) => {
    if ((e.target as HTMLElement).closest('.admin-menu-item-favorited')) return;
    if ((e.target as HTMLElement).closest('.admin-menu-item-options')) return;

    const opts = toArray<CommandOption>(item.Options);
    if (opts.length > 0 && item.Collapse) {
      setExpandedItems((prev) => {
        if (prev[item.Id]) return {};
        return { [item.Id]: true };
      });
      setDropdown(null);

      // Auto-fill player if target is set
      if (!expandedItems[item.Id] && currentTarget && opts[0]) {
        const firstOpt = opts[0];
        if (firstOpt.Name === 'Player') {
          setInputValues((prev) => ({
            ...prev,
            [item.Id]: { ...prev[item.Id], [firstOpt.Id]: currentTarget.Text },
          }));
          setInputData((prev) => ({
            ...prev,
            [item.Id]: { ...prev[item.Id], [firstOpt.Id]: { PlayerId: currentTarget.Source } },
          }));
        }
      }
    } else if (!item.Collapse) {
      fetchNui('runCommand', { id: item.Id, result: item.StaticResult ?? {} }).catch(() => {});
    }
  };

  const handleExecute = (item: Command) => {
    const result: Record<string, InputValue> = {};
    toArray<CommandOption>(item.Options).forEach((opt) => {
      const data = inputData[item.Id]?.[opt.Id];
      // Choice values can be 0 (a job grade), so check for presence, not truthiness.
      if (hasValue(data?.PlayerId)) {
        result[opt.Id] = opt.PlayerList ? Number(data.PlayerId) : data.PlayerId;
      } else if (hasValue(data?.Value)) {
        result[opt.Id] = data.Value;
      } else {
        const value = inputValues[item.Id]?.[opt.Id];
        result[opt.Id] = value ?? (opt.Type.toLowerCase() === 'checkbox' ? false : '');
      }
    });
    fetchNui('runCommand', { id: item.Id, result }).catch(() => {});
  };

  const openDropdown = async (item: Command, option: CommandOption, inputEl: HTMLInputElement) => {
    // Toggle shut before any async work, so a second click on an open dropdown
    // closes it instead of being reopened by a late-resolving fetch.
    if (dropdown && dropdown.itemId === item.Id && dropdown.optionId === option.Id) {
      setDropdown(null);
      return;
    }

    let choices = toArray<DropdownChoice>(option.Choices);
    // Measured now: the input can re-render while a list loads, and a detached
    // element measures as 0x0 (an invisible dropdown).
    const position = dropdownPositionFrom(inputEl);

    // Deferred choice list: ask the client for it when it is needed.
    const provider = option.ChoicesProvider;
    if (provider && choices.length === 0) {
      const cached = option.ChoicesCache ? choiceCache.current[provider] : undefined;
      if (cached) {
        choices = cached;
      } else {
        // Show the list straight away while the data loads, so the click has
        // visible feedback instead of looking like nothing happened.
        const key = `${item.Id}:${option.Id}`;
        pendingDropdownKey.current = key;
        setDropdown({
          options: [{ Text: 'Loading...', Source: null }],
          position,
          hasSearch: false,
          itemId: item.Id,
          optionId: option.Id,
          optionName: option.Name,
        });

        // Never wait forever: an unanswered request would leave this dropdown
        // stuck on "Loading..." with no way to retry.
        let failed = false;
        const fetched = toArray<DropdownChoice>(
          await Promise.race([
            fetchNui<DropdownChoice[]>('getChoices', { provider }),
            new Promise<DropdownChoice[]>((resolve) =>
              setTimeout(() => {
                failed = true;
                resolve([]);
              }, CHOICES_TIMEOUT),
            ),
          ]).catch(() => {
            failed = true;
            return [] as DropdownChoice[];
          }),
        );

        // An empty list means the data behind the provider was not ready yet;
        // caching that would leave the dropdown permanently empty.
        if (fetched.length > 0 && option.ChoicesCache) choiceCache.current[provider] = fetched;

        // Closed (or another dropdown opened) while loading: don't reopen it.
        if (pendingDropdownKey.current !== key) return;
        pendingDropdownKey.current = null;
        choices = failed ? [{ Text: 'Error loading data', Source: null }] : fetched;
      }
    }

    // Dynamic filtering for Rank choices based on selected Job/Gang
    if (option.Id === 'rank') {
      const parentOption = toArray<CommandOption>(item.Options).find((opt) => opt.Id === 'job' || opt.Id === 'gang');

      if (parentOption) {
        const parentData = inputData[item.Id]?.[parentOption.Id];
        const selectedParent = parentData?.Value;

        if (selectedParent) {
          // Filter choices by the Label which contains ' [jobId]'
          choices = choices.filter((c) => c.Label === ` [${selectedParent}]`);

          // If filtered results exist, simplify the text to remove redundant job/gang prefix
          if (choices.length > 0) {
            choices = choices.map((c) => ({
              ...c,
              Text: c.Text.split(' - ').slice(1).join(' - ') || c.Text,
            }));
          }
        } else {
          choices = [{ Text: `Select ${parentOption.Name} first`, Source: null }];
        }
      }
    }

    const isInputChoice = option.Type.toLowerCase() === 'input-choice';

    if (option.PlayerList) choices = convertPlayerList();

    // Add callbacks
    const choicesWithCallbacks = choices.map((c) => ({
      ...c,
      Callback: () => {
        if (c.Text === 'Loading...' || c.Text === 'Error loading data') return;

        const isParent = option.Id === 'job' || option.Id === 'gang';

        setInputValues((prev) => ({
          ...prev,
          [item.Id]: {
            ...prev[item.Id],
            [option.Id]: c.Text,
            ...(isParent ? { rank: '' } : {}),
          },
        }));

        if (hasValue(c.Source)) {
          const source = c.Source;
          if (option.PlayerList) {
            setCurrentTarget({ Text: c.Text, Source: source });
            setInputData((prev) => ({
              ...prev,
              [item.Id]: {
                ...prev[item.Id],
                [option.Id]: { PlayerId: source },
                ...(isParent ? { rank: null } : {}),
              },
            }));
          } else {
            setInputData((prev) => ({
              ...prev,
              [item.Id]: {
                ...prev[item.Id],
                [option.Id]: { Value: source },
                ...(isParent ? { rank: null } : {}),
              },
            }));
          }
        } else if (c.Text) {
          // Fallback for simple text choices
          setInputData((prev) => ({
            ...prev,
            [item.Id]: {
              ...prev[item.Id],
              [option.Id]: { Value: c.Text },
              ...(isParent ? { rank: null } : {}),
            },
          }));
        }
      },
    }));

    setDropdown({
      options: choicesWithCallbacks,
      position,
      hasSearch: isInputChoice,
      itemId: item.Id,
      optionId: option.Id,
      optionName: option.Name,
    });
  };

  const clearCurrentTarget = () => {
    setCurrentTarget(null);
  };

  return (
    <div className="flex flex-col h-full w-full relative">
      {/* Header and Search */}
      <div className="p-6 pb-2">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-terminal text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {t('ui.pages.commands.title')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
                {t('ui.pages.commands.subtitle')}
              </p>
            </div>
          </div>
        </div>

        <div className="border-b border-white/10 pb-4 mb-6">
          <SubTabs
            tabs={CATEGORIES.map((cat) => ({
              id: cat,
              label: cat,
              icon: cat === 'All' ? 'fa-solid fa-layer-group' : undefined,
              count: menuSize === 'Large' ? (categoryCounts[cat] ?? 0) : undefined,
            }))}
            activeTab={selectedCategory}
            onChange={(id) => {
              setSelectedCategory(id);
              setSearchText('');
            }}
          />
        </div>

        <div className="flex gap-2 relative mb-4">
          <SearchField
            className="flex-1"
            value={searchText}
            onChange={(value) => {
              setSearchText(value);
              setDropdown(null);
            }}
            placeholder={t('ui.pages.commands.filter')}
          />
          <button
            onClick={() => setPinnedOnly((value) => !value)}
            className={cn(
              'flex items-center gap-2 px-3 rounded-lg border text-xs font-barlow transition-colors',
              pinnedOnly
                ? 'bg-yellow-400/10 border-yellow-400/40 text-yellow-400'
                : 'bg-black/30 border-white/5 text-white/50 hover:text-white hover:border-white/10',
            )}
          >
            <i className={cn('fa-star text-[11px]', pinnedOnly ? 'fa-solid' : 'fa-regular')}></i>
            {t('ui.pages.commands.pinned_only')}
          </button>
        </div>

        {/* Current target */}
        {currentTarget && (
          <div
            className="mb-4 bg-accent/20 border border-accent/50 text-accent px-4 py-2 rounded-lg text-sm font-barlow flex justify-between items-center cursor-pointer hover:bg-accent/30 transition-colors animate-in fade-in slide-in-from-top-2 duration-300"
            onClick={clearCurrentTarget}
          >
            <span>
              <i className="fa-solid fa-crosshairs mr-2"></i> {t('ui.pages.players.current_target', currentTarget.Text)}
            </span>
            <i className="fa-solid fa-times"></i>
          </div>
        )}
      </div>

      {/* Command items */}
      <div className="flex-1 overflow-y-auto px-6 pb-6 space-y-2 custom-scrollbar" onScroll={() => setDropdown(null)}>
        {filteredItems.length === 0 && commands.length > 0 && (
          <div className="flex flex-col items-center justify-center py-16 text-muted">
            <i className="fa-solid fa-magnifying-glass text-3xl mb-3 opacity-20"></i>
            <p className="font-barlow text-sm">
              {pinnedOnly && !searchText ? t('ui.pages.commands.no_pinned') : t('ui.pages.commands.no_results')}
            </p>
          </div>
        )}
        {filteredItems.map((item, index) => {
          const isExpanded = expandedItems[item.Id];
          const hasOptions = toArray(item.Options).length > 0;
          const isActive = !!enabledItems[item.Id];
          const style = getCommandStyle(index, isExpanded, isActive);

          const isFavorited = !!favoritedItems[item.Id];

          return (
            <div
              key={item.Id}
              className={`rounded-lg overflow-hidden transition-all duration-300 border ${style.border} ${style.bg} ${style.hover} ${style.glow}`}
            >
              <div
                className="flex items-center p-3 cursor-pointer select-none"
                onClick={(e) => handleItemClick(item, e)}
              >
                {/* Pin */}
                <div
                  className="admin-menu-item-favorited w-12 flex justify-center items-center cursor-pointer group/pin"
                  onClick={(e) => {
                    e.stopPropagation();
                    toggleFavorite(item.Id, !favoritedItems[item.Id]);
                  }}
                >
                  <i
                    className={`fa-star transition-all duration-300 ${isFavorited ? 'fa-solid text-yellow-400 scale-110' : 'fa-regular text-white/30 group-hover/pin:text-white/60'}`}
                  ></i>
                </div>

                {/* Name */}
                <div
                  className={`flex-1 font-rajdhani font-semibold text-lg tracking-wide flex items-center gap-2 ${style.text}`}
                >
                  {item.Name}
                  {isActive && (
                    <span className="inline-flex items-center justify-center h-4 px-1.5 rounded bg-emerald-500/20 text-emerald-400 text-[8px] font-extrabold uppercase tracking-wider border border-emerald-500/20 leading-none">
                      Active
                    </span>
                  )}
                </div>

                {/* Arrow */}
                {hasOptions && (
                  <div className="w-8 flex justify-center items-center text-muted">
                    <i
                      className={`fas fa-chevron-down transition-transform duration-300 ${isExpanded ? `rotate-180 ${style.text}` : ''}`}
                    ></i>
                  </div>
                )}
              </div>

              {/* Options */}
              <div
                className={`grid transition-all duration-300 ease-in-out ${isExpanded ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}`}
              >
                <div className="overflow-hidden min-h-0">
                  <div className="p-4 pt-2 border-t border-white/5 bg-transparent admin-menu-item-options">
                    <div className={`grid grid-cols-1 ${menuSize === 'Large' ? 'md:grid-cols-2' : ''} gap-4 mb-4 mt-2`}>
                      {toArray<CommandOption>(item.Options).map((opt) => {
                        const optNameLower = (opt.Name || '').toLowerCase();
                        let colorClass = 'text-primary/80';
                        let labelColorClass = 'text-muted/90 font-semibold';

                        if (
                          optNameLower.includes('player') ||
                          optNameLower.includes('target') ||
                          optNameLower.includes('type') ||
                          optNameLower.includes('reason') ||
                          optNameLower.includes('amount') ||
                          optNameLower.includes('time') ||
                          optNameLower.includes('duration')
                        ) {
                          // Made text more solid and brighter for visibility
                          colorClass = 'text-white font-medium';
                          labelColorClass = 'text-white font-bold';
                        }

                        return (
                          <div key={opt.Id} className="flex flex-col">
                            <label
                              className={`text-[11px] font-rajdhani uppercase tracking-wider mb-1.5 pl-1 ${labelColorClass}`}
                            >
                              {opt.Name || 'Option'}
                            </label>
                            <div className="relative">
                              {opt.Type.toLowerCase() === 'checkbox' ? (
                                <div
                                  className="flex items-center gap-3 cursor-pointer group/cb select-none"
                                  onClick={() => {
                                    setInputValues((prev) => ({
                                      ...prev,
                                      [item.Id]: {
                                        ...prev[item.Id],
                                        [opt.Id]: !inputValues[item.Id]?.[opt.Id],
                                      },
                                    }));
                                  }}
                                >
                                  <div
                                    className={`w-10 h-5 rounded-full px-0.5 flex items-center transition-colors duration-300 border ${inputValues[item.Id]?.[opt.Id] ? 'justify-end bg-accent/25 border-accent/60' : 'justify-start bg-black/50 border-white/10 group-hover/cb:border-white/30'}`}
                                  >
                                    <div
                                      className={`w-4 h-4 rounded-full transition-colors duration-300 ${inputValues[item.Id]?.[opt.Id] ? 'bg-accent' : 'bg-white/50 group-hover/cb:bg-white/70'}`}
                                    ></div>
                                  </div>
                                  <span
                                    className={`text-xs font-rajdhani font-bold tracking-wider uppercase transition-colors ${inputValues[item.Id]?.[opt.Id] ? 'text-accent' : 'text-muted/60 group-hover/cb:text-muted/80'}`}
                                  >
                                    {inputValues[item.Id]?.[opt.Id] ? t('common.enabled') : t('common.disabled')}
                                  </span>
                                </div>
                              ) : (
                                <>
                                  {(() => {
                                    const optType = opt.Type.toLowerCase();
                                    const isInputChoice = optType === 'input-choice';
                                    const isChoice = isInputChoice || optType === 'text-choice';
                                    const isOpen =
                                      !!dropdown && dropdown.itemId === item.Id && dropdown.optionId === opt.Id;
                                    return (
                                      <input
                                        type={opt.InputType || 'text'}
                                        // An input-choice field IS the dropdown's search box: while its list is
                                        // open it shows what you're typing; otherwise it shows the picked value.
                                        value={
                                          isInputChoice && isOpen
                                            ? dropdownSearch
                                            : String(inputValues[item.Id]?.[opt.Id] ?? '')
                                        }
                                        className={`w-full bg-black/10 border border-white/10 rounded-md px-3 py-2 font-barlow text-sm focus:outline-none focus:border-white/30 transition-colors ${colorClass}`}
                                        placeholder={isInputChoice ? `Select ${opt.Name}` : ''}
                                        onChange={(e) => {
                                          if (isInputChoice) {
                                            setDropdownSearch(e.target.value);
                                            if (!isOpen) openDropdown(item, opt, e.target as HTMLInputElement);
                                          } else {
                                            setInputValues((prev) => ({
                                              ...prev,
                                              [item.Id]: { ...prev[item.Id], [opt.Id]: e.target.value },
                                            }));
                                          }
                                        }}
                                        onClick={(e) => {
                                          if (isInputChoice) {
                                            if (!isOpen) {
                                              setDropdownSearch('');
                                              openDropdown(item, opt, e.target as HTMLInputElement);
                                            }
                                          } else if (isChoice) {
                                            openDropdown(item, opt, e.target as HTMLInputElement);
                                          }
                                        }}
                                      />
                                    );
                                  })()}
                                  {(opt.Choices || opt.ChoicesProvider || opt.PlayerList) && (
                                    <i
                                      className={`fa-regular fa-chevron-down absolute right-3 top-1/2 transform -translate-y-1/2 pointer-events-none ${labelColorClass}`}
                                    ></i>
                                  )}
                                </>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                    {confirmExecuteId === item.Id ? (
                      <div className="flex gap-2">
                        <button
                          className="flex-1 py-2 bg-black/40 hover:bg-black/60 text-muted border border-border/50 rounded-md font-rajdhani font-bold tracking-wider uppercase transition-all duration-200"
                          onClick={(e) => {
                            e.stopPropagation();
                            setConfirmExecuteId(null);
                          }}
                        >
                          {t('common.cancel')}
                        </button>
                        <button
                          className="flex-1 py-2 bg-red-500/20 hover:bg-red-500/40 text-red-400 border border-red-500/50 rounded-md font-rajdhani font-bold tracking-wider uppercase transition-all duration-200"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleExecute(item);
                            setConfirmExecuteId(null);
                          }}
                        >
                          <i className="fa-solid fa-check mr-2"></i> {t('ui.pages.commands.confirm_unban')}
                        </button>
                      </div>
                    ) : (
                      <button
                        className={`w-full py-2 ${style.btnBg} ${style.btnHover} ${style.btnText} border ${style.btnBorder} rounded-md font-rajdhani font-bold tracking-wider uppercase transition-all duration-200`}
                        onClick={(e) => {
                          e.stopPropagation();
                          if (item.Id === 'unbanplayer') {
                            setConfirmExecuteId(item.Id);
                          } else {
                            handleExecute(item);
                          }
                        }}
                      >
                        {t('ui.pages.commands.execute', item.Name)}
                      </button>
                    )}

                    {/* Inline Player Info result */}
                    {item.Id === 'playerinfo' && playerInfo && (
                      <div className="mt-3 relative rounded-md border border-white/10 bg-black/40 p-3 pr-8 space-y-1.5 animate-in fade-in slide-in-from-top-2 duration-300">
                        <button
                          className="absolute top-2 right-2 w-6 h-6 flex items-center justify-center rounded text-muted hover:text-white hover:bg-white/10 transition-colors"
                          onClick={(e) => {
                            e.stopPropagation();
                            setPlayerInfo(null);
                          }}
                          title="Close"
                        >
                          <i className="fa-solid fa-times text-xs"></i>
                        </button>
                        <div className="text-sm font-barlow">
                          <span className="font-bold text-primary">Citizen ID: </span>
                          <span className="font-mono text-sky-400 bg-sky-400/10 px-1.5 py-0.5 rounded">
                            {playerInfo.CitizenId}
                          </span>
                        </div>
                        <div className="text-sm font-barlow">
                          <span className="font-bold text-primary">Name: </span>
                          <span className="text-primary/80">{playerInfo.Name}</span>
                        </div>
                        <div className="text-sm font-barlow">
                          <span className="font-bold text-primary">Job: </span>
                          <span className="text-primary/80">
                            {playerInfo.JobGrade ? `${playerInfo.Job} (${playerInfo.JobGrade})` : playerInfo.Job}
                          </span>
                        </div>
                        <div className="text-sm font-barlow">
                          <span className="font-bold text-primary">Gang: </span>
                          <span className="text-primary/80">
                            {playerInfo.GangGrade ? `${playerInfo.Gang} (${playerInfo.GangGrade})` : playerInfo.Gang}
                          </span>
                        </div>
                        <div className="text-sm font-barlow">
                          <span className="font-bold text-primary">Cash / Bank: </span>
                          <span className="text-emerald-400">
                            {fmtMoney(playerInfo.Cash)} / {fmtMoney(playerInfo.Bank)}
                          </span>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Dropdown, the trigger field itself is the search box, so this only lists
 the (already filtered) options; no separate search input inside it. */}
      {dropdown && (
        <Dropdown
          options={
            dropdown.hasSearch
              ? dropdown.options.filter((o) => {
                  const s = dropdownSearch.toLowerCase();
                  return o.Text.toLowerCase().includes(s) || (o.Label && o.Label.toLowerCase().includes(s));
                })
              : dropdown.options
          }
          hasSearch={false}
          position={dropdown.position}
          optionName={dropdown.optionName}
          onSelect={(choice) => {
            if (choice.Callback) choice.Callback(choice);
            setDropdownSearch('');
          }}
          onClose={() => {
            setDropdown(null);
            setDropdownSearch('');
          }}
        />
      )}
    </div>
  );
};

export default CommandsPage;
