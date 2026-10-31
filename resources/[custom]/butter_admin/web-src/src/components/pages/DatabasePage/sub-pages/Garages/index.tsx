import React, { useState, useMemo, useEffect } from 'react';
import { Car, Warehouse } from 'lucide-react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';
import { SortSelect } from '../../../../ui/SortSelect';
import { CopyButton } from '../../../../ui/CopyButton';
import { cn } from '../../../../../utils/cn';
import { vehicleStateTone } from '../Vehicles';
import {
  Column,
  DataTable,
  EmptyState,
  Meter,
  Panel,
  PanelHeader,
  Segmented,
  StatStrip,
  StatusDot,
  Toolbar,
} from '../../ui';

type GarageFilter = 'all' | 'impounded' | 'empty';
type GarageSort = 'name' | 'vehicles';

interface GarageVehicle {
  plate: string;
  model: string;
  owner?: string;
  state: string;
  fuel?: number;
  engine?: number;
}

interface GaragesProps {
  searchQuery: string;
}

const Garages: React.FC<GaragesProps> = ({ searchQuery }) => {
  const { garages, selectedPage, opened, requestData, t } = useAdminMenu();
  const [selectedName, setSelectedName] = useState<string | null>(null);
  const [filter, setFilter] = useState<GarageFilter>('all');
  const [sort, setSort] = useState<GarageSort>('name');

  useEffect(() => {
    if (opened && selectedPage === 'Database') requestData('garages').catch(() => {});
  }, [opened, selectedPage, requestData]);

  // Search matches garage names and the vehicles parked in them.
  const visibleGarages = useMemo(() => {
    const query = searchQuery.toLowerCase();
    const list = garages
      .map((garage) => {
        if (!query || garage.Name.toLowerCase().includes(query)) return garage;
        const vehicles = garage.Vehicles.filter((v) =>
          [v.model, v.plate, v.owner ?? ''].some((value) => value.toLowerCase().includes(query)),
        );
        return vehicles.length > 0 ? { ...garage, Vehicles: vehicles } : null;
      })
      .filter((garage): garage is (typeof garages)[number] => !!garage)
      .filter((garage) => {
        if (filter === 'impounded') return garage.Vehicles.some((v) => v.state === 'Impounded');
        if (filter === 'empty') return garage.Vehicles.length === 0;
        return true;
      });
    return sort === 'vehicles'
      ? list.sort((a, b) => b.Vehicles.length - a.Vehicles.length)
      : list.sort((a, b) => a.Name.localeCompare(b.Name));
  }, [garages, searchQuery, filter, sort]);

  const selected = visibleGarages.find((garage) => garage.Name === selectedName) ?? visibleGarages[0] ?? null;

  const totalVehicles = useMemo(() => garages.reduce((sum, g) => sum + g.Vehicles.length, 0), [garages]);
  const impounded = useMemo(
    () => garages.reduce((sum, g) => sum + g.Vehicles.filter((v) => v.state === 'Impounded').length, 0),
    [garages],
  );

  const columns: Column<GarageVehicle>[] = [
    {
      key: 'model',
      header: t('ui.pages.database.vehicles.col_model'),
      width: 'minmax(0,1.3fr)',
      render: (v) => <span className="text-primary truncate capitalize">{v.model}</span>,
    },
    {
      key: 'plate',
      header: t('ui.pages.database.garages.plate'),
      width: '130px',
      render: (v) => (
        <span className="flex items-center gap-1">
          <span className="font-mono text-sm px-1.5 py-0.5 rounded bg-white/5 border border-border/60">{v.plate}</span>
          <CopyButton text={v.plate} size={11} className="opacity-0 group-hover:opacity-100" />
        </span>
      ),
    },
    {
      key: 'owner',
      header: t('ui.pages.database.garages.owner_cid'),
      width: 'minmax(0,1fr)',
      render: (v) => <span className="font-mono text-sm text-muted truncate">{v.owner || '-'}</span>,
    },
    {
      key: 'state',
      header: t('ui.pages.database.vehicles.col_state'),
      width: '100px',
      render: (v) => <StatusDot tone={vehicleStateTone(v.state)} label={v.state} />,
    },
    {
      key: 'fuel',
      header: t('ui.pages.database.vehicles.fuel'),
      width: '100px',
      render: (v) => <Meter className="w-full" value={v.fuel ?? 0} />,
    },
    {
      key: 'engine',
      header: t('ui.pages.database.vehicles.engine'),
      width: '100px',
      render: (v) => <Meter className="w-full" value={(v.engine ?? 0) / 10} />,
    },
  ];

  return (
    <div className="flex flex-col h-full gap-3">
      <StatStrip
        items={[
          { label: t('ui.pages.database.garages.total_garages'), value: garages.length },
          { label: t('ui.pages.database.garages.total_vehicles'), value: totalVehicles.toLocaleString() },
          { label: t('ui.pages.database.garages.impounded'), value: impounded, tone: 'danger' },
        ]}
      />

      <Toolbar>
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { id: 'all', label: t('ui.pages.database.filter_all') },
            { id: 'impounded', label: t('ui.pages.database.garages.with_impounded') },
            { id: 'empty', label: t('ui.pages.database.garages.empty') },
          ]}
        />
        <SortSelect
          value={sort}
          onChange={setSort}
          options={[
            { id: 'name', label: t('ui.pages.database.sort_name') },
            { id: 'vehicles', label: t('ui.pages.database.garages.sort_vehicles') },
          ]}
        />
      </Toolbar>

      <div className="flex-1 min-h-0 flex gap-3">
        <Panel className="w-[260px] shrink-0 flex flex-col overflow-hidden">
          <div className="px-4 py-2 border-b border-border/60 text-[13px] text-muted font-medium">
            {t('ui.pages.database.garages.registered')} ({visibleGarages.length})
          </div>
          <div className="flex-1 overflow-y-auto custom-scrollbar">
            {visibleGarages.length === 0 ? (
              <EmptyState title={t('ui.pages.database.garages.no_results')} />
            ) : (
              visibleGarages.map((garage) => {
                const impoundedHere = garage.Vehicles.filter((v) => v.state === 'Impounded').length;
                const active = selected?.Name === garage.Name;
                return (
                  <button
                    key={garage.Name}
                    onClick={() => setSelectedName(garage.Name)}
                    className={cn(
                      'w-full flex items-center gap-3 px-4 py-2.5 border-b border-border/30 text-left transition-colors',
                      active ? 'bg-accent/10 shadow-[inset_2px_0_0_rgb(var(--accent))]' : 'hover:bg-white/[0.03]',
                    )}
                  >
                    <Warehouse size={14} className={active ? 'text-accent' : 'text-muted'} />
                    <span className="flex-1 min-w-0 text-base text-primary truncate">{garage.Name}</span>
                    {impoundedHere > 0 && <span className="text-[13px] text-danger tabular-nums">{impoundedHere}</span>}
                    <span className="text-sm text-muted tabular-nums">{garage.Vehicles.length}</span>
                  </button>
                );
              })
            )}
          </div>
        </Panel>

        <Panel className="flex-1 min-w-0 flex flex-col overflow-hidden">
          {selected ? (
            <>
              <PanelHeader
                title={selected.Name}
                subtitle={t('ui.pages.database.garages.registered_vehicles', String(selected.Vehicles.length))}
              />
              <DataTable
                className="flex-1"
                columns={columns}
                rows={selected.Vehicles}
                rowKey={(v) => v.plate}
                empty={<EmptyState icon={<Car size={28} />} title={t('ui.pages.database.garages.no_vehicles')} />}
              />
            </>
          ) : (
            <EmptyState className="flex-1" icon={<Warehouse size={28} />} title={t('ui.pages.database.garages.no_results')} />
          )}
        </Panel>
      </div>
    </div>
  );
};

export default Garages;
