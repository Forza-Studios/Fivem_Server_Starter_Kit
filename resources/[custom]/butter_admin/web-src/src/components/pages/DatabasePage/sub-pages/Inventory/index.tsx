import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { Package, Plus, RefreshCw, Search, Trash2 } from 'lucide-react';
import { useAdminMenu, toArray } from '../../../../../providers/AdminMenuContext';
import { Inventory, InventoryItem } from '../../../../../types';
import { fetchNui } from '../../../../../utils/fetchNui';
import { cn } from '../../../../../utils/cn';
import Pagination from '../../../../ui/Pagination';
import { InventoryItemImage } from '../../../../ui/InventoryItemImage';
import { SearchField } from '../../../../ui/SearchField';
import { SortSelect } from '../../../../ui/SortSelect';
import { CopyButton } from '../../../../ui/CopyButton';
import {
  Badge,
  Button,
  EmptyState,
  IconButton,
  Label,
  Modal,
  Panel,
  PanelHeader,
  Segmented,
  Toolbar,
  inputClass,
} from '../../ui';

type ContainerType = 'player' | 'stash' | 'trunk' | 'glovebox';
type ItemSort = 'slot' | 'name' | 'count';

const CONTAINERS_PER_PAGE = 15;

interface InventoryProps {
  searchQuery: string;
}

const InventoryHub: React.FC<InventoryProps> = ({ searchQuery }) => {
  const { opened, selectedPage, t } = useAdminMenu();

  const [category, setCategory] = useState<ContainerType>('player');
  const [inventories, setInventories] = useState<Inventory[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [containerSearch, setContainerSearch] = useState('');
  const [loading, setLoading] = useState(false);

  const [selected, setSelected] = useState<Inventory | null>(null);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [itemsLoading, setItemsLoading] = useState(false);
  const [itemSearch, setItemSearch] = useState('');
  const [itemSort, setItemSort] = useState<ItemSort>('slot');

  const [addOpen, setAddOpen] = useState(false);
  const [newItem, setNewItem] = useState({ name: '', count: 1 });
  const [removing, setRemoving] = useState<InventoryItem | null>(null);

  const activeSearch = containerSearch || searchQuery;

  const loadContainers = useCallback(
    async (page: number) => {
      setLoading(true);
      try {
        const res = await fetchNui<{ inventories: Inventory[]; totalCount: number } | false>('fetchInventories', {
          type: category,
          offset: (page - 1) * CONTAINERS_PER_PAGE,
          limit: CONTAINERS_PER_PAGE,
          search: activeSearch,
        });
        setInventories(res ? toArray<Inventory>(res.inventories) : []);
        setTotalCount(res ? Number(res.totalCount) || 0 : 0);
      } catch {
        setInventories([]);
        setTotalCount(0);
      } finally {
        setLoading(false);
      }
    },
    [category, activeSearch],
  );

  const loadItems = useCallback(async (invId: string) => {
    setItemsLoading(true);
    try {
      setItems(toArray(await fetchNui<InventoryItem[]>('fetchInventoryItems', { invId }, [])));
    } catch {
      setItems([]);
    } finally {
      setItemsLoading(false);
    }
  }, []);

  useEffect(() => {
    setCurrentPage(1);
    setSelected(null);
  }, [category, activeSearch]);

  useEffect(() => {
    if (!opened || selectedPage !== 'Database') return;
    const timer = setTimeout(() => loadContainers(currentPage), activeSearch ? 300 : 0);
    return () => clearTimeout(timer);
  }, [opened, selectedPage, currentPage, activeSearch, loadContainers]);

  const selectedId = selected?.id;
  useEffect(() => {
    setItemSearch('');
    if (selectedId) loadItems(selectedId);
    else setItems([]);
  }, [selectedId, loadItems]);

  const visibleItems = useMemo(() => {
    const query = itemSearch.toLowerCase();
    const list = items.filter(
      (item) => !query || item.name.toLowerCase().includes(query) || item.label?.toLowerCase().includes(query),
    );
    if (itemSort === 'name') return list.sort((a, b) => (a.label || a.name).localeCompare(b.label || b.name));
    if (itemSort === 'count') return list.sort((a, b) => b.count - a.count);
    return list.sort((a, b) => (a.slot ?? 0) - (b.slot ?? 0));
  }, [items, itemSearch, itemSort]);

  const totalItemCount = useMemo(() => items.reduce((sum, item) => sum + (Number(item.count) || 0), 0), [items]);

  const runAction = async (action: 'AddItem' | 'RemoveItem', data: Record<string, unknown>) => {
    if (!selected) return false;
    const applied = await fetchNui<boolean>('inventoryAction', { action, invId: selected.id, data }).catch(() => false);
    if (applied) loadItems(selected.id);
    return !!applied;
  };

  const addItem = async () => {
    if (!newItem.name.trim()) return;
    if (await runAction('AddItem', { item: newItem.name.trim(), count: newItem.count })) {
      setAddOpen(false);
      setNewItem({ name: '', count: 1 });
    }
  };

  const removeItem = async () => {
    if (!removing) return;
    if (await runAction('RemoveItem', { item: removing.name, slot: removing.slot, count: removing.count })) {
      setRemoving(null);
    }
  };

  return (
    <div className="flex h-full gap-3">
      <Panel className="w-[280px] shrink-0 flex flex-col overflow-hidden">
        <div className="p-3 space-y-2 border-b border-border/60">
          <Segmented
            className="w-full"
            value={category}
            onChange={setCategory}
            options={[
              { id: 'player', label: t('ui.pages.database.inventory.player_tab') },
              { id: 'stash', label: t('ui.pages.database.inventory.stash_tab') },
              { id: 'trunk', label: t('ui.pages.database.inventory.trunk_tab') },
              { id: 'glovebox', label: t('ui.pages.database.inventory.glovebox_tab') },
            ]}
          />
          <SearchField
            value={containerSearch}
            onChange={setContainerSearch}
            placeholder={t('ui.pages.database.inventory.search_containers_placeholder')}
          />
        </div>
        <div className="flex items-center justify-between px-4 py-1.5 border-b border-border/60 text-[13px] text-muted">
          <span>{t('ui.pages.database.inventory.total_nodes')}</span>
          <span className="flex items-center gap-1 tabular-nums">
            {totalCount}
            <IconButton className="p-1" spinning={loading} onClick={() => loadContainers(currentPage)}>
              <RefreshCw size={11} />
            </IconButton>
          </span>
        </div>
        <div className="flex-1 overflow-y-auto custom-scrollbar">
          {inventories.length === 0 ? (
            <EmptyState
              title={
                loading ? t('ui.pages.database.inventory.syncing_registry') : t('ui.pages.database.inventory.zero_nodes')
              }
            />
          ) : (
            inventories.map((inv) => {
              const active = selected?.id === inv.id;
              return (
                <button
                  key={inv.id}
                  onClick={() => setSelected(inv)}
                  className={cn(
                    'w-full px-4 py-2.5 border-b border-border/30 text-left transition-colors',
                    active ? 'bg-accent/10 shadow-[inset_2px_0_0_rgb(var(--accent))]' : 'hover:bg-white/[0.03]',
                  )}
                >
                  <span className="block text-base text-primary truncate">{inv.label}</span>
                  <span className="block font-mono text-[13px] text-muted truncate">{inv.id}</span>
                </button>
              );
            })
          )}
        </div>
        {totalCount > CONTAINERS_PER_PAGE && (
          <div className="px-3 py-2 border-t border-border/60">
            <Pagination
              currentPage={currentPage}
              totalItems={totalCount}
              itemsPerPage={CONTAINERS_PER_PAGE}
              onPageChange={setCurrentPage}
              label={t('ui.pages.database.inventory.nodes_pagination')}
              stacked
            />
          </div>
        )}
      </Panel>

      <Panel className="flex-1 min-w-0 flex flex-col overflow-hidden">
        {!selected ? (
          <EmptyState
            className="flex-1"
            icon={<Package size={28} />}
            title={t('ui.pages.database.inventory.access_restricted')}
            hint={t('ui.pages.database.inventory.access_restricted_desc')}
          />
        ) : (
          <>
            <PanelHeader
              title={
                <span className="flex items-center gap-2">
                  {selected.label}
                  <Badge>{t(`ui.pages.database.inventory.${selected.type}_tab`)}</Badge>
                </span>
              }
              subtitle={
                <span className="flex items-center gap-1 font-mono">
                  {selected.id}
                  <CopyButton text={selected.id} size={11} />
                </span>
              }
              actions={
                <>
                  <IconButton spinning={itemsLoading} onClick={() => loadItems(selected.id)}>
                    <RefreshCw size={14} />
                  </IconButton>
                  <Button variant="primary" icon={<Plus size={13} />} onClick={() => setAddOpen(true)}>
                    {t('ui.pages.database.inventory.add_item')}
                  </Button>
                </>
              }
            />

            {items.length > 0 && (
              <Toolbar className="px-4 py-2.5 border-b border-border/60">
                <SearchField
                  className="flex-1 max-w-xs"
                  value={itemSearch}
                  onChange={setItemSearch}
                  placeholder={t('ui.pages.database.inventory.search_items_placeholder')}
                />
                <SortSelect
                  value={itemSort}
                  onChange={setItemSort}
                  options={[
                    { id: 'slot', label: t('ui.pages.database.inventory.sort_slot') },
                    { id: 'name', label: t('ui.pages.database.sort_name') },
                    { id: 'count', label: t('ui.pages.database.inventory.sort_count') },
                  ]}
                />
                <span className="ml-auto text-sm text-muted">
                  {t('ui.pages.database.inventory.item_summary', String(items.length), String(totalItemCount))}
                </span>
              </Toolbar>
            )}

            <div className="flex-1 overflow-y-auto custom-scrollbar p-4">
              {itemsLoading && items.length === 0 ? (
                <div className="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-3">
                  {Array.from({ length: 10 }, (_, i) => (
                    <div key={i} className="h-[168px] rounded-md border border-border/40 bg-white/[0.02] animate-pulse" />
                  ))}
                </div>
              ) : items.length === 0 ? (
                <EmptyState
                  icon={<Package size={28} />}
                  title={t('ui.pages.database.inventory.empty_sector')}
                  hint={t('ui.pages.database.inventory.empty_sector_desc')}
                />
              ) : visibleItems.length === 0 ? (
                <EmptyState icon={<Search size={24} />} title={t('ui.pages.database.inventory.no_matching_items')} />
              ) : (
                <div className="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-3">
                  {visibleItems.map((item) => (
                    <div
                      key={`${item.slot}-${item.name}`}
                      className="group relative flex flex-col rounded-md border border-border/50 bg-black/10 p-3 hover:border-border transition-colors"
                    >
                      <div className="flex items-center justify-between text-[13px] text-muted tabular-nums">
                        <span>#{item.slot}</span>
                        <span className="text-primary">x{item.count}</span>
                      </div>
                      <div className="h-24 flex items-center justify-center my-1">
                        <InventoryItemImage item={item} className="w-20 h-20 object-contain" />
                      </div>
                      <p className="text-base text-primary truncate" title={item.label || item.name}>
                        {item.label || item.name}
                      </p>
                      <p className="font-mono text-[13px] text-muted truncate">{item.name}</p>
                      <IconButton
                        tone="danger"
                        title={t('ui.pages.database.inventory.delete')}
                        className="absolute top-8 right-1.5 opacity-0 group-hover:opacity-100 bg-bg-primary/80"
                        onClick={() => setRemoving(item)}
                      >
                        <Trash2 size={13} />
                      </IconButton>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </Panel>

      {addOpen && (
        <Modal
          title={t('ui.pages.database.inventory.asset_dispatch')}
          subtitle={selected?.label}
          onClose={() => setAddOpen(false)}
          footer={
            <>
              <Button variant="ghost" onClick={() => setAddOpen(false)}>
                {t('ui.pages.database.inventory.cancel')}
              </Button>
              <Button variant="primary" disabled={!newItem.name.trim()} onClick={addItem}>
                {t('ui.pages.database.inventory.confirm_dispatch')}
              </Button>
            </>
          }
        >
          <div className="space-y-4">
            <div>
              <Label>{t('ui.pages.database.inventory.asset_identifier')}</Label>
              <input
                autoFocus
                className={inputClass}
                placeholder={t('ui.pages.database.inventory.asset_identifier_placeholder')}
                value={newItem.name}
                onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                onKeyDown={(e) => e.key === 'Enter' && addItem()}
              />
            </div>
            <div>
              <Label>{t('ui.pages.database.inventory.quantity_factor')}</Label>
              <input
                type="number"
                min={1}
                className={inputClass}
                value={newItem.count}
                onChange={(e) => setNewItem({ ...newItem, count: Math.max(1, parseInt(e.target.value) || 1) })}
              />
            </div>
          </div>
        </Modal>
      )}

      {removing && (
        <Modal
          title={t('ui.pages.database.inventory.destroy_asset')}
          onClose={() => setRemoving(null)}
          footer={
            <>
              <Button variant="ghost" onClick={() => setRemoving(null)}>
                {t('ui.pages.database.inventory.cancel')}
              </Button>
              <Button variant="danger" onClick={removeItem}>
                {t('ui.pages.database.inventory.confirm_destruction')}
              </Button>
            </>
          }
        >
          <div className="flex items-center gap-3">
            <InventoryItemImage item={removing} className="w-12 h-12 object-contain" />
            <p className="text-base text-muted">
              {t(
                'ui.pages.database.inventory.destroy_asset_confirm',
                `${removing.count}x ${removing.label || removing.name}`,
              )}
            </p>
          </div>
        </Modal>
      )}
    </div>
  );
};

export default InventoryHub;
