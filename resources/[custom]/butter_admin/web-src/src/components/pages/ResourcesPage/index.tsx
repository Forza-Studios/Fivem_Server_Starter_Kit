import React, { useState, useMemo, useEffect } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { fetchNui } from '../../../utils/fetchNui';
import { SubTabs } from '../../ui/SubTabs';
import { SearchField } from '../../ui/SearchField';
import { CopyButton } from '../../ui/CopyButton';

const ResourcesPage: React.FC = () => {
  const { resources, refreshResources, menuSize, t } = useAdminMenu();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | 'started' | 'stopped'>('all');
  const [pendingAction, setPendingAction] = useState<{ name: string; action: 'stop' | 'restart' } | null>(null);
  const isLarge = menuSize === 'Large';

  useEffect(() => {
    refreshResources();
  }, [refreshResources]);

  const filteredResources = useMemo(
    () =>
      resources
        .filter((res) => {
          const matchesSearch = res.Name.toLowerCase().includes(searchQuery.toLowerCase());
          const matchesStatus = filterStatus === 'all' || res.State === filterStatus;
          return matchesSearch && matchesStatus;
        })
        .sort((a, b) => a.Name.localeCompare(b.Name)),
    [resources, searchQuery, filterStatus],
  );

  const startedCount = useMemo(() => resources.filter((res) => res.State === 'started').length, [resources]);

  const handleAction = (resourceName: string, action: 'start' | 'stop' | 'restart') => {
    // The server answers with an updateMenu message carrying the new resource states.
    fetchNui('resourceAction', { resource: resourceName, action }).catch(() => {});
  };

  const requestAction = (resourceName: string, action: 'start' | 'stop' | 'restart') => {
    if (action === 'start') return handleAction(resourceName, action);
    setPendingAction({ name: resourceName, action });
  };

  const confirmPendingAction = () => {
    if (!pendingAction) return;
    handleAction(pendingAction.name, pendingAction.action);
    setPendingAction(null);
  };

  return (
    <div className="flex flex-col h-full w-full">
      <div className="p-6 pb-2">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-cubes text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {t('ui.pages.resources.title')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
                {t('ui.pages.resources.subtitle')}
              </p>
            </div>
          </div>
          <button
            onClick={refreshResources}
            className="bg-accent hover:bg-accent/80 text-white px-4 py-2 rounded-lg font-rajdhani font-bold tracking-wider uppercase transition-all duration-300 flex items-center gap-2 "
          >
            <i className="fa-solid fa-rotate"></i>
            {isLarge && t('ui.pages.resources.refresh_btn')}
          </button>
        </div>

        <div className="border-b border-white/10 pb-4 mb-6">
          <SubTabs
            tabs={[
              { id: 'all', label: t('ui.pages.resources.all'), icon: 'fa-solid fa-cubes', count: resources.length },
              {
                id: 'started',
                label: t('ui.pages.resources.started'),
                icon: 'fa-solid fa-play text-green-500',
                count: startedCount,
              },
              {
                id: 'stopped',
                label: t('ui.pages.resources.stopped'),
                icon: 'fa-solid fa-stop text-red-500',
                count: resources.length - startedCount,
              },
            ]}
            activeTab={filterStatus}
            onChange={setFilterStatus}
          />
        </div>

        <SearchField
          className="mb-4"
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder={t('ui.pages.resources.search_placeholder')}
        />
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar">
        <div className="grid grid-cols-1 gap-2">
          {filteredResources.map((res) => (
            <div
              key={res.Name}
              className="group bg-black/20 border border-white/5 rounded-xl p-4 flex items-center justify-between hover:bg-white/5 hover:border-white/10 transition-all duration-300"
            >
              <div className="flex items-center gap-4">
                <div
                  className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg ${res.State === 'started' ? 'bg-green-500/10 text-green-400' : 'bg-red-500/10 text-red-400'}`}
                >
                  <i className="fa-solid fa-cube"></i>
                </div>
                <div>
                  <div className="flex items-center gap-1 text-primary font-rajdhani font-bold text-lg tracking-wide">
                    {res.Name}
                    <CopyButton text={res.Name} className="opacity-0 group-hover:opacity-100" />
                  </div>
                  <div
                    className={`text-[10px] uppercase tracking-[0.2em] font-black ${res.State === 'started' ? 'text-green-500' : 'text-red-500'}`}
                  >
                    {res.State}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {res.State === 'started' ? (
                  <>
                    <button
                      onClick={() => requestAction(res.Name, 'restart')}
                      className="w-9 h-9 rounded-lg bg-blue-500/10 text-blue-400 hover:bg-blue-500 hover:text-white transition-all duration-300 flex items-center justify-center"
                      title={t('ui.pages.resources.restart')}
                    >
                      <i className="fa-solid fa-arrows-rotate text-sm"></i>
                    </button>
                    <button
                      onClick={() => requestAction(res.Name, 'stop')}
                      className="w-9 h-9 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500 hover:text-white transition-all duration-300 flex items-center justify-center"
                      title={t('ui.pages.resources.stop')}
                    >
                      <i className="fa-solid fa-stop text-sm"></i>
                    </button>
                  </>
                ) : (
                  <button
                    onClick={() => requestAction(res.Name, 'start')}
                    className="w-9 h-9 rounded-lg bg-green-500/10 text-green-400 hover:bg-green-500 hover:text-white transition-all duration-300 flex items-center justify-center"
                    title={t('ui.pages.resources.start')}
                  >
                    <i className="fa-solid fa-play text-sm"></i>
                  </button>
                )}
              </div>
            </div>
          ))}
          {filteredResources.length === 0 && (
            <div className="flex flex-col items-center justify-center py-20 text-muted">
              <i className="fa-solid fa-cubes text-4xl mb-4 opacity-20"></i>
              <p className="font-rajdhani font-bold uppercase tracking-widest">{t('ui.pages.resources.no_results')}</p>
              <p className="text-xs mt-1">{t('ui.pages.resources.adjust_filters')}</p>
            </div>
          )}
        </div>
      </div>

      {pendingAction && (
        <div
          className="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-black/80 animate-in fade-in duration-200"
          onClick={() => setPendingAction(null)}
        >
          <div
            className="w-full max-w-sm bg-sidebar border border-white/10 rounded-2xl p-5 animate-in zoom-in-95 duration-200"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl bg-red-500/10 border border-red-500/20 flex items-center justify-center text-red-500">
                <i className="fa-solid fa-triangle-exclamation"></i>
              </div>
              <h3 className="text-primary font-rajdhani font-bold text-lg uppercase tracking-wide">
                {pendingAction.action === 'stop' ? t('ui.pages.resources.stop') : t('ui.pages.resources.restart')}
              </h3>
            </div>
            <p className="text-xs text-muted mb-5">
              {pendingAction.action === 'stop'
                ? t('ui.pages.resources.stop_confirm', pendingAction.name)
                : t('ui.pages.resources.restart_confirm', pendingAction.name)}
            </p>
            <div className="flex gap-2">
              <button
                onClick={() => setPendingAction(null)}
                className="flex-1 p-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-[10px] uppercase font-bold tracking-widest hover:bg-white/10 transition-all"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={confirmPendingAction}
                className="flex-1 p-2.5 bg-red-600 rounded-xl text-white text-[10px] uppercase font-bold tracking-widest hover:bg-red-700 transition-all"
              >
                {t('ui.pages.resources.confirm')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ResourcesPage;
