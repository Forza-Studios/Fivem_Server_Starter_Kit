import React, { useState, useEffect, useCallback } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { SubTabs } from '../../ui/SubTabs';
import { SearchField } from '../../ui/SearchField';
import { SortSelect } from '../../ui/SortSelect';
import { CopyButton } from '../../ui/CopyButton';
import Pagination from '../../ui/Pagination';

const formatDate = (dateStr: string) => {
  const d = new Date(dateStr);
  const secs = d.getSeconds() < 10 ? `0${d.getSeconds()}` : d.getSeconds();
  const mins = d.getMinutes() < 10 ? `0${d.getMinutes()}` : d.getMinutes();
  const hour = d.getHours() < 10 ? `0${d.getHours()}` : d.getHours();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()} ${hour}:${mins}:${secs}`;
};

const ITEMS_PER_PAGE = 25;

type LogRange = 'all' | '24h' | '7d' | '30d';
type LogOrder = 'newest' | 'oldest';

const PlayerLogsPage: React.FC = () => {
  const { logs, logsTotal, menuSize, requestData, t } = useAdminMenu();
  const [searchInput, setSearchInput] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState<'all' | 'admin' | 'player' | 'vehicles' | 'database'>('all');
  const [expandedLogs, setExpandedLogs] = useState<Record<number, boolean>>({});
  const [currentPage, setCurrentPage] = useState(1);
  const [range, setRange] = useState<LogRange>('all');
  const [order, setOrder] = useState<LogOrder>('newest');

  const isLargeMode = menuSize === 'Large';

  // Debounce search query to avoid database flooding
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearchQuery(searchInput);
      setCurrentPage(1);
    }, 450);
    return () => clearTimeout(timer);
  }, [searchInput]);

  const handleRefresh = useCallback(() => {
    requestData('logs', {
      page: currentPage,
      limit: ITEMS_PER_PAGE,
      search: searchQuery,
      category: filterCategory,
      range,
      order,
    }).catch(() => {});
  }, [requestData, currentPage, searchQuery, filterCategory, range, order]);

  // Logs are paged and filtered in SQL; only the large menu shows them.
  useEffect(() => {
    if (!isLargeMode) return;
    handleRefresh();
    setExpandedLogs({});
  }, [isLargeMode, handleRefresh]);

  useEffect(() => {
    setCurrentPage(1);
  }, [filterCategory, range, order]);

  // Helper to get styled dynamic icons
  const getIcon = (type: string) => {
    if (!type) return 'fa-solid fa-terminal';
    const t = type.toLowerCase();
    if (t.includes('cloak')) return 'fa-solid fa-ghost';
    if (t.includes('revive')) return 'fa-solid fa-heart-pulse';
    if (t.includes('heal')) return 'fa-solid fa-house-medical';
    if (t.includes('job')) return 'fa-solid fa-briefcase';
    if (t.includes('gang')) return 'fa-solid fa-users';
    if (t.includes('money') || t.includes('cash') || t.includes('bank')) return 'fa-solid fa-money-bill-1';
    if (t.includes('vehicle') || t.includes('car') || t === 'spawn' || t === 'delete') return 'fa-solid fa-car';
    if (t.includes('ban') || t.includes('kick') || t.includes('warn')) return 'fa-solid fa-ban';
    if (t.includes('note')) return 'fa-solid fa-clipboard';
    if (t.includes('prop') || t.includes('object')) return 'fa-solid fa-cubes';
    if (t.includes('item') || t.includes('inventory') || t.includes('stash')) return 'fa-solid fa-box-archive';
    return 'fa-solid fa-terminal';
  };

  const getIconStyle = (type: string) => {
    if (!type) return 'bg-slate-500/10 text-slate-400';
    const t = type.toLowerCase();
    if (t.includes('cloak')) return 'bg-cyan-500/10 text-cyan-400';
    if (t.includes('revive')) return 'bg-green-500/10 text-green-400';
    if (t.includes('heal')) return 'bg-emerald-500/10 text-emerald-400';
    if (t.includes('job') || t.includes('gang')) return 'bg-amber-500/10 text-amber-400';
    if (t.includes('money') || t.includes('cash') || t.includes('bank')) return 'bg-yellow-500/10 text-yellow-400';
    if (t.includes('vehicle') || t.includes('car') || t === 'spawn' || t === 'delete')
      return 'bg-indigo-500/10 text-indigo-400';
    if (t.includes('ban') || t.includes('kick')) return 'bg-red-500/10 text-red-400';
    if (t.includes('note')) return 'bg-purple-500/10 text-purple-400';
    if (t.includes('prop') || t.includes('object') || t.includes('item') || t.includes('inventory'))
      return 'bg-rose-500/10 text-rose-400';
    return 'bg-slate-500/10 text-slate-400';
  };

  const getTagStyle = (type: string) => {
    if (!type) return 'bg-slate-500/5 text-slate-400/80 border-slate-500/15';
    const t = type.toLowerCase();
    if (t.includes('cloak')) return 'bg-cyan-500/5 text-cyan-400/80 border-cyan-500/15';
    if (t.includes('revive')) return 'bg-green-500/5 text-green-400/80 border-green-500/15';
    if (t.includes('heal')) return 'bg-emerald-500/5 text-emerald-400/80 border-emerald-500/15';
    if (t.includes('job') || t.includes('gang')) return 'bg-amber-500/5 text-amber-400/80 border-amber-500/15';
    if (t.includes('money') || t.includes('cash') || t.includes('bank'))
      return 'bg-yellow-500/5 text-yellow-400/80 border-yellow-500/15';
    if (t.includes('vehicle') || t.includes('car') || t === 'spawn' || t === 'delete')
      return 'bg-indigo-500/5 text-indigo-400/80 border-indigo-500/15';
    if (t.includes('ban') || t.includes('kick')) return 'bg-red-500/5 text-red-400/80 border-red-500/15';
    if (t.includes('note')) return 'bg-purple-500/5 text-purple-400/80 border-purple-500/15';
    if (t.includes('prop') || t.includes('object') || t.includes('item') || t.includes('inventory'))
      return 'bg-rose-500/5 text-rose-400/80 border-rose-500/15';
    return 'bg-slate-500/5 text-slate-400/80 border-slate-500/15';
  };

  const formatJson = (data: string) => {
    try {
      const parsed = typeof data === 'string' ? JSON.parse(data) : data;
      return JSON.stringify(parsed, null, 2);
    } catch (e) {
      return data;
    }
  };

  const toggleLogExpand = (idx: number) => {
    setExpandedLogs((prev) => ({
      ...prev,
      [idx]: !prev[idx],
    }));
  };

  if (!isLargeMode) {
    return (
      <div className="flex flex-col h-full w-full items-center justify-center text-muted p-4">
        <i className="fa-regular fa-face-frown text-6xl mb-4 opacity-50"></i>
        <p className="font-rajdhani text-xl text-center max-w-xs">{t('ui.pages.logs.large_mode_opt')}</p>
        <p className="font-barlow text-sm mt-2 opacity-70 text-center">{t('ui.pages.logs.large_mode_desc')}</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full w-full">
      {/* Header Panel */}
      <div className="p-6 pb-2 shrink-0">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-list-ul text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {t('ui.pages.logs.title')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
                {t('ui.pages.logs.subtitle')}
              </p>
            </div>
          </div>
          <button
            onClick={handleRefresh}
            className="bg-accent hover:bg-accent/80 text-white px-4 py-2 rounded-lg font-rajdhani font-bold tracking-wider uppercase transition-all duration-300 flex items-center gap-2 "
          >
            <i className="fa-solid fa-rotate"></i>
            {t('ui.pages.logs.refresh')}
          </button>
        </div>

        {/* SubTabs Category Filter */}
        <div className="border-b border-white/10 pb-4 mb-6">
          <SubTabs
            tabs={[
              { id: 'all', label: t('ui.pages.logs.categories.all'), icon: 'fa-solid fa-list' },
              { id: 'admin', label: t('ui.pages.logs.categories.admin'), icon: 'fa-solid fa-shield-halved text-cyan-400' },
              {
                id: 'player',
                label: t('ui.pages.logs.categories.player'),
                icon: 'fa-solid fa-user-gear text-amber-400',
              },
              { id: 'vehicles', label: t('ui.pages.logs.categories.vehicles'), icon: 'fa-solid fa-car text-indigo-400' },
              {
                id: 'database',
                label: t('ui.pages.logs.categories.database'),
                icon: 'fa-solid fa-database text-purple-400',
              },
            ]}
            activeTab={filterCategory}
            onChange={setFilterCategory}
          />
        </div>

        <div className="flex items-center gap-2 mb-4">
          <SearchField
            className="flex-1"
            value={searchInput}
            onChange={setSearchInput}
            placeholder={t('ui.pages.logs.filter')}
          />
          <SubTabs
            tabs={[
              { id: 'all', label: t('ui.pages.logs.range_all') },
              { id: '24h', label: t('ui.pages.logs.range_24h') },
              { id: '7d', label: t('ui.pages.logs.range_7d') },
              { id: '30d', label: t('ui.pages.logs.range_30d') },
            ]}
            activeTab={range}
            onChange={setRange}
            tabClassName="py-1.5"
          />
          <SortSelect
            value={order}
            onChange={setOrder}
            options={[
              { id: 'newest', label: t('ui.pages.logs.order_newest') },
              { id: 'oldest', label: t('ui.pages.logs.order_oldest') },
            ]}
          />
        </div>
      </div>

      {/* Grid of log entries */}
      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar flex flex-col justify-between">
        <div className="flex flex-col gap-2">
          {logs.map((log, idx) => {
            return (
              <div
                key={idx}
                className="group bg-black/20 border border-white/5 rounded-xl p-4 flex flex-col gap-3 hover:bg-white/5 hover:border-white/10 transition-all duration-300 animate-fadeIn"
              >
                <div className="flex items-center justify-between flex-wrap gap-4">
                  <div className="flex items-center gap-4">
                    {/* Styled category icon */}
                    <div
                      className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0 ${getIconStyle(log.Type)}`}
                    >
                      <i className={getIcon(log.Type)}></i>
                    </div>
                    <div>
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-primary font-rajdhani font-bold text-base tracking-wide leading-tight">
                          {log.Desc}
                        </span>
                        <span
                          className={`text-[9px] uppercase font-mono px-2 py-0.5 rounded border leading-none font-bold tracking-wider ${getTagStyle(log.Type)}`}
                        >
                          {log.Type || 'System'}
                        </span>
                      </div>
                      <div className="flex items-center gap-4 mt-1.5 text-xs text-muted flex-wrap">
                        <span className="flex items-center gap-1 font-mono">
                          <i className="fa-solid fa-clock text-[10px] opacity-75"></i> {formatDate(log.Date)}
                        </span>
                        {(log.AdminName || log.Steam) && (
                          <span className="flex items-center gap-1 font-mono opacity-80" title={log.Steam}>
                            <i className="fa-solid fa-shield-halved text-[10px] opacity-75"></i> {t('ui.pages.logs.admin')}{' '}
                            <span className="text-primary/95">
                              {log.AdminName
                                ? log.AdminName
                                : log.Steam.includes('license:')
                                  ? log.Steam.split('license:')[1]
                                  : log.Steam.includes('steam:')
                                    ? log.Steam.split('steam:')[1]
                                    : log.Steam}
                            </span>
                          </span>
                        )}
                        {log.Cid && (
                          <span className="flex items-center gap-1 font-mono opacity-80">
                            <i className="fa-solid fa-id-card text-[10px] opacity-75"></i> {t('ui.pages.logs.target')}{' '}
                            <span className="text-primary/95 font-bold">{log.Cid}</span>
                            <CopyButton text={log.Cid} size={10} />
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Expanding JSON payload details */}
                  {log.Data && log.Data !== '{}' && log.Data !== 'null' && (
                    <button
                      onClick={() => toggleLogExpand(idx)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-rajdhani font-bold tracking-wider uppercase transition-all duration-300 flex items-center gap-2 border select-none ${
                        expandedLogs[idx]
                          ? 'bg-accent/20 text-accent border-accent/40 hover:bg-accent/30'
                          : 'bg-white/5 text-muted border-white/10 hover:bg-white/10 hover:text-primary'
                      }`}
                    >
                      <i className={`fa-solid ${expandedLogs[idx] ? 'fa-eye-slash' : 'fa-database'}`}></i>
                      {expandedLogs[idx] ? t('ui.pages.logs.hide_data') : t('ui.pages.logs.view_data')}
                    </button>
                  )}
                </div>

                {/* JSON code block viewer */}
                {expandedLogs[idx] && log.Data && (
                  <div className="mt-1 p-3.5 bg-black/40 border border-white/5 rounded-xl font-mono text-xs text-muted/90 overflow-x-auto select-text">
                    <div className="text-[10px] uppercase tracking-wider text-accent/80 font-bold mb-1.5 opacity-80 flex items-center gap-1">
                      <i className="fa-solid fa-code"></i> {t('ui.pages.logs.data')}
                      <CopyButton text={formatJson(log.Data)} size={10} className="ml-auto" />
                    </div>
                    <pre className="whitespace-pre-wrap break-words leading-relaxed text-emerald-400/90 font-medium">
                      {formatJson(log.Data)}
                    </pre>
                  </div>
                )}
              </div>
            );
          })}

          {/* Empty state fallback */}
          {logs.length === 0 && (
            <div className="flex flex-col items-center justify-center py-20 text-muted shrink-0">
              <i className="fa-solid fa-list-ul text-4xl mb-4 opacity-20"></i>
              <p className="font-rajdhani font-bold uppercase tracking-widest">{t('ui.pages.logs.no_results')}</p>
            </div>
          )}
        </div>

        {logsTotal > ITEMS_PER_PAGE && (
          <Pagination
            className="mt-6"
            currentPage={currentPage}
            totalItems={logsTotal}
            itemsPerPage={ITEMS_PER_PAGE}
            onPageChange={setCurrentPage}
            label={t('ui.pages.logs.label')}
          />
        )}
      </div>
    </div>
  );
};

export default PlayerLogsPage;
