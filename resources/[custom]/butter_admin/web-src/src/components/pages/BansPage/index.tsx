import React, { useState, useMemo, useEffect } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { fetchNui } from '../../../utils/fetchNui';
import { copyTextToClipboard } from '../../../utils/misc';
import { BannedPlayer } from '../../../types';
import { SubTabs } from '../../ui/SubTabs';
import { BansHeader } from './components/BansHeader';
import { BanCard } from './components/BanCard';
import { SearchField } from '../../ui/SearchField';
import { SortSelect } from '../../ui/SortSelect';

type BanDate = BannedPlayer['Expires'] | undefined;
type BanKind = 'all' | 'permanent' | 'temporary';
type BanSort = 'newest' | 'oldest' | 'expiring';

/** Ban dates arrive as unix seconds or as os.date tables. */
const toTime = (value: BanDate): number => {
  if (!value) return 0;
  if (typeof value === 'number') return value * 1000;
  return new Date(value.year, value.month - 1, value.day, value.hour, value.min).getTime();
};

const BansPage: React.FC = () => {
  const { bans, setBans, showCheckmark, banNotes, setBanNote, requestData, t } = useAdminMenu();
  const [activeTab, setActiveTab] = useState<'active' | 'history'>('active');
  const [searchQuery, setSearchQuery] = useState('');
  const [kind, setKind] = useState<BanKind>('all');
  const [sort, setSort] = useState<BanSort>('newest');
  const [expandedBans, setExpandedBans] = useState<Record<number, boolean>>({});
  const [confirmUnbanIdx, setConfirmUnbanIdx] = useState<number | null>(null);

  useEffect(() => {
    requestData('bans').catch(() => {});
  }, [requestData]);

  const displayedBans = useMemo(() => {
    let filtered = bans.map((b, idx) => ({ ...b, _idx: idx }));
    filtered = filtered.filter((ban) => (activeTab === 'active' ? !ban.Unbanned : ban.Unbanned));
    if (kind !== 'all') filtered = filtered.filter((ban) => (kind === 'permanent') === !ban.Expires);

    if (sort === 'expiring') {
      // Permanent bans never expire, so they go last.
      filtered.sort((a, b) => (toTime(a.Expires) || Infinity) - (toTime(b.Expires) || Infinity));
    } else {
      const direction = sort === 'newest' ? -1 : 1;
      filtered.sort((a, b) => (toTime(a.BannedOn) - toTime(b.BannedOn)) * direction);
    }

    if (!searchQuery) return filtered;
    const query = searchQuery.toLowerCase();
    return filtered.filter((ban) => {
      const banId = ban.BanId || String(ban._idx);
      const note = banNotes[banId] || '';
      return (
        ban.Name.toLowerCase().includes(query) ||
        (ban.Discord && ban.Discord.toLowerCase().includes(query)) ||
        (ban.Steam && ban.Steam.toLowerCase().includes(query)) ||
        (ban.License && ban.License.toLowerCase().includes(query)) ||
        (ban.BanId && ban.BanId.toLowerCase().includes(query)) ||
        ban.Reason.toLowerCase().includes(query) ||
        ban.BannedBy.toLowerCase().includes(query) ||
        note.toLowerCase().includes(query)
      );
    });
  }, [bans, searchQuery, banNotes, activeTab, kind, sort]);

  const stats = useMemo(() => {
    const active = bans.filter((b) => !b.Unbanned);
    return {
      active: active.length,
      history: bans.filter((b) => b.Unbanned).length,
      permanent: active.filter((b) => !b.Expires).length,
    };
  }, [bans]);

  const formatDate = (val: BannedPlayer['Expires'] | undefined) => {
    if (!val) return 'Never';
    if (typeof val === 'number') {
      const d = new Date(val * 1000);
      return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()} | ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
    }
    const d = val;
    const hour = Number(d.hour) < 10 ? `0${d.hour}` : d.hour;
    const min = Number(d.min) < 10 ? `0${d.min}` : d.min;
    return `${d.day}/${d.month}/${d.year} | ${hour}:${min}`;
  };

  const copyText = (text: string, e: React.MouseEvent) => {
    e.stopPropagation();
    copyTextToClipboard(text);
    showCheckmark();
  };

  const handleUnban = (ban: BannedPlayer, e: React.MouseEvent) => {
    e.stopPropagation();

    // Moves the ban to history right away; the server keeps the record.
    setBans((prev) =>
      prev.map((b) =>
        b.BanId === ban.BanId ? { ...b, Unbanned: true, UnbannedDate: Math.floor(Date.now() / 1000) } : b,
      ),
    );
    setConfirmUnbanIdx(null);

    if (ban.BanId) fetchNui('unbanPlayer', { banId: ban.BanId });
    showCheckmark();
  };

  if (bans.length === 0) {
    return (
      <div className="flex flex-col h-full w-full items-center justify-center text-muted">
        <i className="fa-solid fa-ban text-6xl mb-4 opacity-50"></i>
        <p className="font-rajdhani text-xl">{t('ui.pages.bans.no_active')}</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full w-full">
      <div className="p-6 pb-2">
        <BansHeader activeCount={stats.active} historyCount={stats.history} permanentCount={stats.permanent} />

        <div className="border-b border-white/10 pb-4 mb-6">
          <SubTabs
            tabs={[
              { id: 'active', label: t('ui.pages.bans.active_bans'), icon: 'fa-solid fa-ban' },
              { id: 'history', label: t('ui.pages.bans.history'), icon: 'fa-solid fa-clock-rotate-left' },
            ]}
            activeTab={activeTab}
            onChange={setActiveTab}
          />
        </div>

        <div className="flex items-center gap-2 mb-4">
          <SearchField
            className="flex-1"
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder={t('ui.pages.bans.filter')}
          />
          <SubTabs
            tabs={[
              { id: 'all', label: t('ui.pages.bans.all') },
              { id: 'permanent', label: t('ui.pages.bans.permanent') },
              { id: 'temporary', label: t('ui.pages.bans.temporary') },
            ]}
            activeTab={kind}
            onChange={setKind}
            tabClassName="py-1.5"
          />
          <SortSelect
            value={sort}
            onChange={setSort}
            options={[
              { id: 'newest', label: t('ui.pages.bans.sort_newest') },
              { id: 'oldest', label: t('ui.pages.bans.sort_oldest') },
              { id: 'expiring', label: t('ui.pages.bans.sort_expiring') },
            ]}
          />
        </div>
        <p className="text-[11px] font-mono text-muted/60 mb-2">
          {t('ui.pages.bans.showing', String(displayedBans.length))}
        </p>
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar space-y-2">
        {displayedBans.map((ban) => (
          <BanCard
            key={ban.BanId || ban._idx}
            ban={ban}
            idx={ban._idx}
            isExpanded={!!expandedBans[ban._idx]}
            activeTab={activeTab}
            confirmUnbanIdx={confirmUnbanIdx}
            banNotes={banNotes}
            onToggle={() => setExpandedBans((prev) => ({ ...prev, [ban._idx]: !prev[ban._idx] }))}
            onCopy={copyText}
            onUnban={handleUnban}
            onConfirmUnban={setConfirmUnbanIdx}
            onSetNote={setBanNote}
            formatDate={formatDate}
          />
        ))}
        {displayedBans.length === 0 && bans.length > 0 && (
          <div className="text-center py-8 text-muted font-barlow">{t('ui.pages.bans.no_results')}</div>
        )}
      </div>
    </div>
  );
};

export default BansPage;
