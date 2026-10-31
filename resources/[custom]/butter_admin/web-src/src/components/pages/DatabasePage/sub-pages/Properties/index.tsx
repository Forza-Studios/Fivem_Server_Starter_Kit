import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { Home, Navigation, Trash2 } from 'lucide-react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';
import { Property } from '../../../../../types';
import { fetchNui } from '../../../../../utils/fetchNui';
import Pagination from '../../../../ui/Pagination';
import { SortSelect } from '../../../../ui/SortSelect';
import { CopyButton } from '../../../../ui/CopyButton';
import {
  Badge,
  Button,
  Column,
  DataTable,
  EmptyState,
  Field,
  Panel,
  PanelHeader,
  Section,
  Segmented,
  StatStrip,
  Toolbar,
  formatMoney,
} from '../../ui';

const ITEMS_PER_PAGE = 25;
const TYPES = ['luxury', 'commercial', 'storage', 'vacation'] as const;

type PropertySort = 'default' | 'name' | 'price_desc' | 'price_asc';

interface PropertiesProps {
  searchQuery: string;
}

const Properties: React.FC<PropertiesProps> = ({ searchQuery }) => {
  const { properties, propertiesTotal, selectedPage, opened, requestData, t } = useAdminMenu();
  const [selected, setSelected] = useState<Property | null>(null);
  const [filter, setFilter] = useState('all');
  const [sort, setSort] = useState<PropertySort>('default');
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [loading, setLoading] = useState(false);

  const refreshProperties = useCallback(() => {
    setLoading(true);
    return requestData('properties', { page: currentPage, limit: ITEMS_PER_PAGE, search: searchQuery, filter, sort })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [requestData, currentPage, searchQuery, filter, sort]);

  useEffect(() => {
    if (!opened || selectedPage !== 'Database') return;
    const timer = setTimeout(refreshProperties, searchQuery ? 300 : 0);
    return () => clearTimeout(timer);
  }, [opened, selectedPage, searchQuery, refreshProperties]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, filter, sort]);

  const pageValue = useMemo(() => properties.reduce((sum, p) => sum + (p.price || 0), 0), [properties]);

  const select = (property: Property | null) => {
    setSelected(property);
    setConfirmDelete(false);
  };

  const handleAction = async (action: 'teleport' | 'delete', propertyId: number) => {
    const applied = await fetchNui<boolean>('propertyAction', { action, propertyId });
    if (!applied) return;
    refreshProperties();
    if (action === 'delete') select(null);
  };

  const typeLabel = (type: string) => {
    const key = type.toLowerCase();
    return (TYPES as readonly string[]).includes(key) ? t(`ui.pages.database.properties.${key}`) : type;
  };

  const columns: Column<Property>[] = [
    {
      key: 'label',
      header: t('ui.pages.database.properties.col_name'),
      width: 'minmax(0,1.4fr)',
      render: (p) => <span className="text-primary truncate">{p.label}</span>,
    },
    {
      key: 'address',
      header: t('ui.pages.database.properties.col_address'),
      width: 'minmax(0,1.4fr)',
      render: (p) => <span className="text-muted truncate">{p.address}</span>,
    },
    {
      key: 'type',
      header: t('ui.pages.database.properties.asset_type'),
      width: '110px',
      render: (p) => <Badge>{typeLabel(p.type)}</Badge>,
    },
    {
      key: 'owner',
      header: t('ui.pages.database.properties.current_owner'),
      width: 'minmax(0,1fr)',
      render: (p) => <span className="text-muted truncate">{p.owner || '-'}</span>,
    },
    {
      key: 'price',
      header: t('ui.pages.database.properties.asset_value'),
      width: '110px',
      align: 'right',
      render: (p) => <span className="tabular-nums">{formatMoney(p.price ?? 0)}</span>,
    },
  ];

  return (
    <div className="flex flex-col h-full gap-3">
      <StatStrip
        items={[
          { label: t('ui.pages.database.properties.managed_assets'), value: propertiesTotal.toLocaleString() },
          { label: t('ui.pages.database.properties.total_equity'), value: formatMoney(pageValue), tone: 'success' },
          {
            label: t('ui.pages.database.properties.luxury_portfolio'),
            value: properties.filter((p) => p.type.toLowerCase() === 'luxury').length,
          },
        ]}
      />

      <Toolbar>
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { id: 'all', label: t('ui.pages.database.filter_all') },
            ...TYPES.map((type) => ({ id: type, label: t(`ui.pages.database.properties.${type}`) })),
          ]}
        />
        <SortSelect
          value={sort}
          onChange={setSort}
          options={[
            { id: 'default', label: t('ui.pages.database.sort_default') },
            { id: 'name', label: t('ui.pages.database.sort_name') },
            { id: 'price_desc', label: t('ui.pages.database.properties.sort_price_desc') },
            { id: 'price_asc', label: t('ui.pages.database.properties.sort_price_asc') },
          ]}
        />
        <span className="ml-auto text-sm text-muted">
          {t('ui.pages.database.result_count', propertiesTotal.toLocaleString())}
        </span>
      </Toolbar>

      <div className="flex-1 min-h-0 flex gap-3">
        <Panel className="flex-1 min-w-0 flex flex-col overflow-hidden">
          <DataTable
            className="flex-1"
            columns={selected ? columns.filter((column) => !['address', 'owner'].includes(column.key)) : columns}
            rows={properties}
            rowKey={(p) => String(p.id)}
            onRowClick={(p) => select(selected?.id === p.id ? null : p)}
            selectedKey={selected ? String(selected.id) : null}
            loading={loading}
            empty={<EmptyState icon={<Home size={28} />} title={t('ui.pages.database.properties.no_results')} />}
          />
          {propertiesTotal > ITEMS_PER_PAGE && (
            <div className="px-4 py-2 border-t border-border/60">
              <Pagination
                currentPage={currentPage}
                totalItems={propertiesTotal}
                itemsPerPage={ITEMS_PER_PAGE}
                onPageChange={setCurrentPage}
                label={t('ui.pages.database.properties.label')}
              />
            </div>
          )}
        </Panel>

        {selected && (
          <Panel className="w-[300px] shrink-0 flex flex-col overflow-hidden animate-in slide-in-from-right-2 duration-200">
            <PanelHeader
              title={selected.label}
              subtitle={t('ui.pages.database.properties.registry_number', String(selected.id))}
              onClose={() => select(null)}
            />
            <div className="flex-1 overflow-y-auto custom-scrollbar p-4 space-y-5">
              <Section title={t('ui.pages.database.properties.details')}>
                <div>
                  <Field label={t('ui.pages.database.properties.col_address')}>{selected.address}</Field>
                  <Field label={t('ui.pages.database.properties.asset_type')}>{typeLabel(selected.type)}</Field>
                  <Field label={t('ui.pages.database.properties.asset_value')}>{formatMoney(selected.price ?? 0)}</Field>
                  <Field label={t('ui.pages.database.properties.current_owner')}>
                    {selected.owner || '-'}
                    {selected.owner && <CopyButton text={selected.owner} size={11} />}
                  </Field>
                </div>
              </Section>
              <Button className="w-full" icon={<Navigation size={13} />} onClick={() => handleAction('teleport', selected.id)}>
                {t('ui.pages.database.properties.teleport')}
              </Button>
            </div>
            <div className="p-4 border-t border-border/60">
              {confirmDelete ? (
                <div className="flex gap-2">
                  <Button variant="ghost" className="flex-1" onClick={() => setConfirmDelete(false)}>
                    {t('common.cancel')}
                  </Button>
                  <Button variant="danger" className="flex-1" onClick={() => handleAction('delete', selected.id)}>
                    {t('ui.pages.database.properties.confirm')}
                  </Button>
                </div>
              ) : (
                <Button variant="danger" className="w-full" icon={<Trash2 size={13} />} onClick={() => setConfirmDelete(true)}>
                  {t('ui.pages.database.properties.delete_property')}
                </Button>
              )}
            </div>
          </Panel>
        )}
      </div>
    </div>
  );
};

export default Properties;
