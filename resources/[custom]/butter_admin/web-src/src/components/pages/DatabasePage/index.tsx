import React, { useState } from 'react';
import { Users, Warehouse, Car, Home, Wallet, Briefcase, Package, LucideIcon } from 'lucide-react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { SearchField } from '../../ui/SearchField';
import { cn } from '../../../utils/cn';
import Players from './sub-pages/Players';
import Garages from './sub-pages/Garages';
import Vehicles from './sub-pages/Vehicles';
import Properties from './sub-pages/Properties';
import Economy from './sub-pages/Economy';
import JobsGangs from './sub-pages/JobsGangs';
import InventoryHub from './sub-pages/Inventory';

type SubTabId = 'Players' | 'Garages' | 'Vehicles' | 'Properties' | 'Economy' | 'JobsGangs' | 'Inventory';

const TABS: { id: SubTabId; key: string; Icon: LucideIcon }[] = [
  { id: 'Players', key: 'players', Icon: Users },
  { id: 'Vehicles', key: 'vehicles', Icon: Car },
  { id: 'Garages', key: 'garages', Icon: Warehouse },
  { id: 'Properties', key: 'properties', Icon: Home },
  { id: 'Economy', key: 'economy', Icon: Wallet },
  { id: 'JobsGangs', key: 'jobs_gangs', Icon: Briefcase },
  { id: 'Inventory', key: 'inventory', Icon: Package },
];

const DatabasePage: React.FC = () => {
  const { t, menuSize } = useAdminMenu();
  const [activeTab, setActiveTab] = useState<SubTabId>('Players');
  const [searchQuery, setSearchQuery] = useState('');

  const renderSubPage = () => {
    switch (activeTab) {
      case 'Players':
        return <Players searchQuery={searchQuery} />;
      case 'Garages':
        return <Garages searchQuery={searchQuery} />;
      case 'Vehicles':
        return <Vehicles searchQuery={searchQuery} />;
      case 'Properties':
        return <Properties searchQuery={searchQuery} />;
      case 'Economy':
        return <Economy searchQuery={searchQuery} />;
      case 'JobsGangs':
        return <JobsGangs searchQuery={searchQuery} />;
      case 'Inventory':
        return <InventoryHub searchQuery={searchQuery} />;
      default:
        return null;
    }
  };

  if (menuSize !== 'Large') {
    return (
      <div className="flex flex-col h-full w-full items-center justify-center text-muted p-6 text-center">
        <p className="text-base text-primary/80">{t('ui.pages.database.large_mode_opt')}</p>
        <p className="text-sm mt-1">{t('ui.pages.database.large_mode_desc')}</p>
      </div>
    );
  }

  const activeLabel = t(`ui.pages.database.tabs.${TABS.find((tab) => tab.id === activeTab)?.key}`);

  return (
    <div className="flex flex-col h-full">
      <div className="px-6 pt-5 shrink-0">
        <div className="flex items-end justify-between gap-4 mb-4">
          <div>
            <h2 className="text-2xl font-semibold text-primary leading-tight">{t('ui.pages.database.title')}</h2>
            <p className="text-sm text-muted mt-0.5">{t('ui.pages.database.subtitle')}</p>
          </div>
          <SearchField
            className="w-80"
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder={t('ui.pages.database.search_placeholder', activeLabel.toLowerCase())}
          />
        </div>

        <nav className="flex items-center gap-1 border-b border-border/60 -mx-1 overflow-x-auto">
          {TABS.map(({ id, key, Icon }) => (
            <button
              key={id}
              onClick={() => {
                setActiveTab(id);
                setSearchQuery('');
              }}
              className={cn(
                'flex items-center gap-2 px-4 py-3 text-base font-medium border-b-2 -mb-px transition-colors whitespace-nowrap',
                activeTab === id
                  ? 'border-accent text-primary'
                  : 'border-transparent text-muted hover:text-primary',
              )}
            >
              <Icon size={17} />
              {t(`ui.pages.database.tabs.${key}`)}
            </button>
          ))}
        </nav>
      </div>

      <div className="flex-1 min-h-0 px-6 py-4">{renderSubPage()}</div>
    </div>
  );
};

export default DatabasePage;
