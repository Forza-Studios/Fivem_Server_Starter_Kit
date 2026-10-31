import React from 'react';
import { useAdminMenu } from '../providers/AdminMenuContext';
import { PageName } from '../types';
import { fetchNui } from '../utils/fetchNui';

interface SidebarItem {
  icon: string;
  tooltip: string;
  action: PageName | 'DevMode' | 'PinnedTargets' | 'ToggleMenu' | 'ToggleSize';
  lower?: boolean;
}

const upperItems: SidebarItem[] = [
  { icon: 'fa-solid fa-hat-wizard', tooltip: 'ui.tabs.commands', action: 'Commands' },
  { icon: 'fa-solid fa-list-ul', tooltip: 'ui.tabs.players', action: 'PlayerList' },
  { icon: 'fa-solid fa-map-location-dot', tooltip: 'ui.tabs.monitoring', action: 'Monitoring' },
  { icon: 'fa-solid fa-gavel', tooltip: 'ui.tabs.bans', action: 'Bans' },
  { icon: 'fa-solid fa-book-open', tooltip: 'ui.tabs.logs', action: 'PlayerLogs' },
  { icon: 'fa-solid fa-user-shield', tooltip: 'ui.tabs.chats', action: 'StaffChat' },
  { icon: 'fa-solid fa-flag', tooltip: 'ui.tabs.reports', action: 'Reports' },
  { icon: 'fa-solid fa-shield-halved', tooltip: 'ui.tabs.access', action: 'AccessControl' },
  { icon: 'fa-solid fa-database', tooltip: 'ui.tabs.database', action: 'Database' },
  { icon: 'fa-solid fa-cogs', tooltip: 'ui.tabs.options', action: 'Options' },
  { icon: 'fa-solid fa-server', tooltip: 'ui.tabs.txadmin', action: 'TxAdmin' },
];

const lowerItems: SidebarItem[] = [
  { icon: 'fa-solid fa-cubes', tooltip: 'ui.tabs.resources', action: 'Resources', lower: true },
  { icon: 'fa-solid fa-terminal', tooltip: 'info.menu_debug', action: 'DevMode', lower: true },
  { icon: 'fa-solid fa-clipboard-list', tooltip: 'ui.pages.players.favorites', action: 'PinnedTargets', lower: true },
  { icon: 'fa-solid fa-expand-alt', tooltip: 'info.keymapping_desc', action: 'ToggleSize', lower: true },
  { icon: 'fa-solid fa-xmark', tooltip: 'info.close_menu', action: 'ToggleMenu', lower: true },
];

const Sidebar: React.FC = () => {
  const {
    t,
    selectedPage,
    setSelectedPage,
    closeMenu,
    pages,
    enabledItems,
    changeSize,
    menuSize,
    options,
    pinnedVisible,
    setPinnedVisible,
  } = useAdminMenu();

  const handleClick = (item: SidebarItem) => {
    if (item.lower) {
      // Action items
      if (item.action === 'DevMode') {
        // The client confirms the new state with a setItemEnabled message.
        fetchNui('toggleDevMode', { enabled: !enabledItems.DevMode }).catch(() => {});
      } else if (item.action === 'Resources') {
        if (selectedPage !== 'Resources') {
          setSelectedPage('Resources');
        }
      } else if (item.action === 'PinnedTargets') {
        setPinnedVisible(!pinnedVisible);
      } else if (item.action === 'ToggleMenu') {
        closeMenu();
      } else if (item.action === 'ToggleSize') {
        changeSize();
      }
    } else {
      // Page navigation
      const page = item.action as PageName;
      if (selectedPage !== page) {
        setSelectedPage(page);
      }
    }
  };

  const isPageVisible = (action: string | undefined): boolean => {
    if (!action) return true;
    // pages is a Record<string, boolean> where unauthorized pages are undefined
    return pages[action] === true;
  };

  return (
    <div className="w-full h-full bg-black/20 border-r border-white/5 flex flex-col justify-between py-6 z-50 rounded-l-lg">
      <div className={`flex flex-col gap-2 ${menuSize === 'Large' ? 'px-4' : 'items-center'}`}>
        {upperItems.map(
          (item) =>
            isPageVisible(item.action) && (
              <div
                key={item.action}
                className={`group relative h-10 rounded-xl flex items-center cursor-pointer transition-all duration-300 ${
                  menuSize === 'Large' ? 'w-full px-3 justify-start' : 'w-10 justify-center'
                } ${
                  selectedPage === item.action
                    ? 'bg-accent text-white'
                    : 'text-white/40 hover:bg-white/10 hover:text-white'
                }`}
                onClick={() => handleClick(item)}
              >
                <i
                  className={`${item.icon} text-lg transition-colors duration-300 ${menuSize === 'Large' ? 'w-6 text-center' : ''}`}
                ></i>

                {menuSize === 'Large' && (
                  <span className="ml-3 font-rajdhani font-bold tracking-wider uppercase text-sm whitespace-nowrap overflow-hidden text-ellipsis opacity-100 transition-opacity duration-300">
                    {t(item.tooltip)}
                  </span>
                )}

                {/* Tooltip */}
                {menuSize !== 'Large' && options.Tooltips && (
                  <div className="absolute right-full flex items-center opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-300 z-50 pointer-events-none translate-x-[10px] group-hover:translate-x-0">
                    <div className="px-3 py-1.5 bg-black/90 border border-white/10 text-white text-[11px] font-rajdhani font-bold tracking-widest uppercase rounded-l relative whitespace-nowrap">
                      {t(item.tooltip)}
                      <div className="absolute right-0 top-0 bottom-0 w-[2px] bg-accent"></div>
                    </div>
                    <div className="w-4 h-[1px] bg-white/30"></div>
                  </div>
                )}
              </div>
            ),
        )}
      </div>

      <div className={`flex flex-col gap-2 ${menuSize === 'Large' ? 'px-4' : 'items-center'}`}>
        {lowerItems.map((item) => {
          if (item.action === 'Resources' && !isPageVisible('Resources')) return null;
          if (item.action === 'DevMode' && !isPageVisible('DevMode')) return null;
          if (item.action === 'ToggleSize' && !options.Resizer) return null;

          const isEnabled = item.action === 'DevMode' && enabledItems.DevMode;
          const isSelected = item.action === 'Resources' && selectedPage === 'Resources';
          const dynamicIcon =
            item.action === 'ToggleSize'
              ? menuSize === 'Large'
                ? 'fa-solid fa-compress-alt'
                : 'fa-solid fa-expand-alt'
              : item.icon;

          return (
            <div
              key={item.action}
              className={`group relative h-10 rounded-xl flex items-center cursor-pointer transition-all duration-300 ${
                menuSize === 'Large' ? 'w-full px-3 justify-start' : 'w-10 justify-center'
              } ${
                isSelected
                  ? 'bg-accent text-white'
                  : isEnabled
                    ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                    : item.action === 'ToggleMenu'
                      ? 'text-white/40 hover:bg-red-500/20 hover:text-red-400'
                      : 'text-white/40 hover:bg-white/10 hover:text-white'
              }`}
              onClick={() => handleClick(item)}
            >
              <i
                className={`${dynamicIcon} text-lg transition-colors duration-300 ${menuSize === 'Large' ? 'w-6 text-center' : ''}`}
              ></i>

              {menuSize === 'Large' && (
                <span className="ml-3 font-rajdhani font-bold tracking-wider uppercase text-sm whitespace-nowrap overflow-hidden text-ellipsis opacity-100 transition-opacity duration-300">
                  {t(item.tooltip)}
                </span>
              )}

              {/* Tooltip */}
              {menuSize !== 'Large' && options.Tooltips && (
                <div className="absolute right-full flex items-center opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-300 z-50 pointer-events-none translate-x-[10px] group-hover:translate-x-0">
                  <div className="px-3 py-1.5 bg-black/90 border border-white/10 text-white text-[11px] font-rajdhani font-bold tracking-widest uppercase rounded-l relative whitespace-nowrap">
                    {t(item.tooltip)}
                    <div className="absolute right-0 top-0 bottom-0 w-[2px] bg-accent"></div>
                  </div>
                  <div className="w-4 h-[1px] bg-white/30"></div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default Sidebar;
