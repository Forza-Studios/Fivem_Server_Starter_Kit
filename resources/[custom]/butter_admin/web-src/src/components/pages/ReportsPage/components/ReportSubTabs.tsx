import React from 'react';
import { SubTabs, Tab } from '../../../ui/SubTabs';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface ReportSubTabsProps {
  activeTab: 'Active' | 'Closed';
  setActiveTab: (tab: 'Active' | 'Closed') => void;
  activeCount: number;
  closedCount: number;
}

export const ReportSubTabs: React.FC<ReportSubTabsProps> = ({ activeTab, setActiveTab, activeCount, closedCount }) => {
  const { t } = useAdminMenu();
  const tabs: Tab<'Active' | 'Closed'>[] = [
    { id: 'Active', label: t('ui.pages.reports.tab_active'), icon: 'fa-regular fa-clock', count: activeCount },
    {
      id: 'Closed',
      label: t('ui.pages.reports.tab_closed'),
      icon: 'fa-solid fa-clock-rotate-left',
      count: closedCount,
    },
  ];

  return (
    <div className="border-b border-border/50 pb-4 mb-4 shrink-0">
      <SubTabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />
    </div>
  );
};
