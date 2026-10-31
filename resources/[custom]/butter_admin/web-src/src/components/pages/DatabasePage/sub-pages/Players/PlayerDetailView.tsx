import React, { useState, useEffect } from 'react';
import { ArrowLeft, Car, Check, Eye, EyeOff, Home, Loader2, Package, Pencil, Trash2 } from 'lucide-react';
import { FactionMembership, Player, PlayerVehicle } from '../../../../../types';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';
import { fetchNui } from '../../../../../utils/fetchNui';
import { cn } from '../../../../../utils/cn';
import { InventoryItemImage } from '../../../../ui/InventoryItemImage';
import { CopyButton } from '../../../../ui/CopyButton';
import { Select } from '../../../../ui/Select';
import { vehicleStateTone } from '../Vehicles';
import {
  Badge,
  Button,
  Column,
  DataTable,
  EmptyState,
  Field,
  IconButton,
  Label,
  Meter,
  Modal,
  Panel,
  Section,
  Segmented,
  StatusDot,
  formatMoney,
  inputClass,
} from '../../ui';

interface PlayerDetailViewProps {
  player: Player;
  onBack: () => void;
}

type AssetTab = 'vehicles' | 'properties' | 'inventory';
type DetailProperty = NonNullable<NonNullable<Player['Details']>['properties']>[number];

const STATES = ['Stored', 'Out', 'Impounded'] as const;

const membershipLabel = (membership: FactionMembership | string | undefined, fallback: string) => {
  if (!membership) return fallback;
  if (typeof membership === 'string') return membership;
  const name = membership.label || membership.name || fallback;
  const grade = membership.grade?.label || membership.grade?.name;
  return grade ? `${name} (${grade})` : name;
};

const PlayerDetailView: React.FC<PlayerDetailViewProps> = ({ player: initialPlayer, onBack }) => {
  const { t, garages, jobs, gangs, players } = useAdminMenu();
  const [player, setPlayer] = useState<Player>(initialPlayer);
  const [loading, setLoading] = useState(true);
  const [ipRevealed, setIpRevealed] = useState(false);
  const [assetTab, setAssetTab] = useState<AssetTab>('vehicles');

  const [vehicle, setVehicle] = useState<PlayerVehicle | null>(null);
  const [newPlate, setNewPlate] = useState('');
  const [newGarage, setNewGarage] = useState('');
  const [confirmDelete, setConfirmDelete] = useState(false);

  const [alignmentType, setAlignmentType] = useState<'job' | 'gang' | null>(null);
  const [target, setTarget] = useState<{ id: string; grade: number }>({ id: '', grade: 0 });

  const profileId = initialPlayer.CitizenId ?? initialPlayer.License;

  const refreshProfile = async () => {
    const updated = await fetchNui<Player | false>('fetchPlayerProfile', { id: profileId });
    if (updated) setPlayer(updated);
  };

  useEffect(() => {
    setLoading(true);
    fetchNui<Player | false>('fetchPlayerProfile', { id: initialPlayer.CitizenId ?? initialPlayer.License }, initialPlayer)
      .then((data) => {
        if (data && data.Name) setPlayer(data);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [initialPlayer]);

  const details = player.Details;
  const job = details?.job || player.job;
  const gang = details?.gang || player.gang;
  const money = details?.money || { cash: 0, bank: 0 };
  const vehicles = details?.vehicles || [];
  const properties = details?.properties || [];
  const inventory = details?.inventory || [];
  const isOnline = player.isOnline ?? (players || []).some((p) => p.CitizenId === player.CitizenId);

  const openVehicle = (v: PlayerVehicle | null) => {
    setVehicle(v);
    setNewPlate(v?.plate ?? '');
    setNewGarage(v?.garage ?? '');
    setConfirmDelete(false);
  };

  const vehicleAction = async (action: string, data: Record<string, string> = {}) => {
    if (!vehicle) return;
    const applied = await fetchNui<boolean>('vehicleAction', { action, plate: vehicle.plate, data });
    if (!applied) return;
    await refreshProfile();
    if (action === 'DeleteVehicle') return openVehicle(null);

    const patch: Partial<PlayerVehicle> = {};
    if (data.NewState) patch.state = data.NewState;
    if (data.NewPlate) patch.plate = data.NewPlate;
    if (data.NewGarage !== undefined) patch.garage = data.NewGarage;
    setVehicle({ ...vehicle, ...patch });
  };

  const startAlignment = (type: 'job' | 'gang') => {
    const membership = type === 'job' ? job : gang;
    const currentId = typeof membership === 'string' ? membership : (membership?.name ?? '');
    const currentGrade = typeof membership === 'object' ? (membership.grade?.level ?? 0) : 0;
    setTarget({ id: currentId, grade: currentGrade });
    setAlignmentType(type);
  };

  const saveAlignment = async () => {
    if (!alignmentType) return;
    const applied = await fetchNui<boolean>('updateAlignment', {
      citizenid: player.CitizenId,
      type: alignmentType,
      alignment: target.id,
      grade: target.grade,
    });
    if (!applied) return;
    await refreshProfile();
    setAlignmentType(null);
  };

  const alignmentGroups = alignmentType === 'gang' ? gangs : jobs;
  const targetGrades = alignmentGroups.find((group) => group.id === target.id)?.grades ?? [];

  const identifiers = [
    { label: t('ui.pages.database.players.license'), value: player.License },
    { label: 'Steam', value: player.Steam },
    { label: 'Discord', value: player.Discord },
    { label: 'FiveM', value: player.Fivem },
    { label: t('ui.pages.database.players.hardware_id'), value: player.HardwareId },
  ].filter((identifier) => identifier.value);

  const vehicleColumns: Column<PlayerVehicle>[] = [
    {
      key: 'model',
      header: t('ui.pages.database.vehicles.col_model'),
      width: 'minmax(0,1.3fr)',
      render: (v) => <span className="text-primary truncate capitalize">{v.model}</span>,
    },
    {
      key: 'plate',
      header: t('ui.pages.database.vehicles.plate'),
      width: '110px',
      render: (v) => <span className="font-mono text-sm px-1.5 py-0.5 rounded bg-white/5 border border-border/60">{v.plate}</span>,
    },
    {
      key: 'garage',
      header: t('ui.pages.database.vehicles.col_garage'),
      width: 'minmax(0,1fr)',
      render: (v) => <span className="text-muted truncate">{v.garage || '-'}</span>,
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
  ];

  const propertyColumns: Column<DetailProperty>[] = [
    {
      key: 'label',
      header: t('ui.pages.database.properties.col_name'),
      width: 'minmax(0,1.2fr)',
      render: (p) => <span className="text-primary truncate">{p.label}</span>,
    },
    {
      key: 'address',
      header: t('ui.pages.database.properties.col_address'),
      width: 'minmax(0,1.5fr)',
      render: (p) => <span className="text-muted truncate">{p.address}</span>,
    },
    {
      key: 'type',
      header: t('ui.pages.database.properties.asset_type'),
      width: '110px',
      render: (p) => <Badge>{p.type}</Badge>,
    },
  ];

  return (
    <div className="flex flex-col h-full gap-3 relative">
      <div className="flex items-center gap-3 shrink-0">
        <IconButton onClick={onBack} title={t('ui.pages.database.players.back')}>
          <ArrowLeft size={16} />
        </IconButton>
        <div className="w-10 h-10 rounded-md bg-white/5 border border-border/60 flex items-center justify-center text-base font-semibold text-primary">
          {(player.Name || '?')
            .split(' ')
            .map((word) => word[0])
            .slice(0, 2)
            .join('')
            .toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h3 className="text-xl font-semibold text-primary truncate">{player.Name}</h3>
            <StatusDot
              tone={isOnline ? 'success' : 'default'}
              label={isOnline ? t('ui.pages.database.players.online_now') : t('ui.pages.database.players.offline')}
            />
          </div>
          <div className="flex items-center gap-1 text-sm text-muted font-mono">
            {player.CitizenId || player.License}
            <CopyButton text={player.CitizenId || player.License} size={11} />
          </div>
        </div>
        {loading && <Loader2 size={16} className="animate-spin text-muted" />}
      </div>

      <div className="flex-1 min-h-0 flex gap-3">
        <Panel className="w-[300px] shrink-0 overflow-y-auto custom-scrollbar p-4 space-y-5">
          <Section title={t('ui.pages.database.players.basic_info')}>
            <div>
              <Field label={t('ui.pages.database.players.dob')}>{details?.dob || '-'}</Field>
              <Field label={t('ui.pages.database.players.blood_group')}>{details?.bloodgroup || '-'}</Field>
              <Field label={t('ui.pages.database.players.phone_number')}>
                {details?.phone || '-'}
                {details?.phone && <CopyButton text={details.phone} size={11} />}
              </Field>
              <Field label={t('ui.pages.database.players.job')}>
                <span className="truncate">{membershipLabel(job, t('ui.pages.database.jobs_gangs.unemployed'))}</span>
                <IconButton className="p-1" onClick={() => startAlignment('job')}>
                  <Pencil size={11} />
                </IconButton>
              </Field>
              <Field label={t('ui.pages.database.players.gang')}>
                <span className="truncate">{membershipLabel(gang, t('ui.pages.database.players.no_gang'))}</span>
                <IconButton className="p-1" onClick={() => startAlignment('gang')}>
                  <Pencil size={11} />
                </IconButton>
              </Field>
            </div>
          </Section>

          <Section title={t('ui.pages.database.players.money')}>
            <div>
              <Field label={t('ui.pages.database.economy.cash')}>
                <span className="tabular-nums text-success">{formatMoney(money.cash)}</span>
              </Field>
              <Field label={t('ui.pages.database.economy.bank')}>
                <span className="tabular-nums text-success">{formatMoney(money.bank)}</span>
              </Field>
              {money.crypto !== undefined && (
                <Field label={t('ui.pages.database.players.crypto')}>
                  <span className="tabular-nums">{money.crypto}</span>
                </Field>
              )}
            </div>
          </Section>

          <Section title={t('ui.pages.database.players.identifiers')}>
            <div>
              {identifiers.map((identifier) => (
                <Field key={identifier.label} label={identifier.label} mono>
                  <span className="truncate">{identifier.value}</span>
                  <CopyButton text={identifier.value || ''} size={11} />
                </Field>
              ))}
              {player.IP && (
                <Field label={t('ui.pages.database.players.ip')} mono>
                  <span className="truncate">{ipRevealed ? player.IP : '••••••••••'}</span>
                  <IconButton className="p-1" onClick={() => setIpRevealed((value) => !value)}>
                    {ipRevealed ? <EyeOff size={11} /> : <Eye size={11} />}
                  </IconButton>
                </Field>
              )}
            </div>
          </Section>
        </Panel>

        <Panel className="flex-1 min-w-0 flex flex-col overflow-hidden">
          <div className="px-4 py-2.5 border-b border-border/60 shrink-0">
            <Segmented
              value={assetTab}
              onChange={setAssetTab}
              options={[
                { id: 'vehicles', label: t('ui.pages.database.players.owned_vehicles'), count: vehicles.length },
                { id: 'properties', label: t('ui.pages.database.players.owned_properties'), count: properties.length },
                { id: 'inventory', label: t('ui.pages.database.players.player_inventory'), count: inventory.length },
              ]}
            />
          </div>

          {assetTab === 'vehicles' && (
            <DataTable
              className="flex-1"
              columns={vehicleColumns}
              rows={vehicles}
              rowKey={(v) => v.plate}
              onRowClick={openVehicle}
              empty={<EmptyState icon={<Car size={28} />} title={t('ui.pages.database.players.no_vehicles_registered')} />}
            />
          )}

          {assetTab === 'properties' && (
            <DataTable
              className="flex-1"
              columns={propertyColumns}
              rows={properties}
              rowKey={(p) => String(p.id ?? p.label)}
              empty={<EmptyState icon={<Home size={28} />} title={t('ui.pages.database.players.no_properties_owned')} />}
            />
          )}

          {assetTab === 'inventory' && (
            <div className="flex-1 overflow-y-auto custom-scrollbar p-4">
              {inventory.length === 0 ? (
                <EmptyState icon={<Package size={28} />} title={t('ui.pages.database.inventory.empty_sector_desc')} />
              ) : (
                <div className="grid grid-cols-[repeat(auto-fill,minmax(110px,1fr))] gap-2.5">
                  {[...inventory]
                    .sort((a, b) => a.slot - b.slot)
                    .map((item) => (
                      <div
                        key={`${item.slot}-${item.name}`}
                        className="flex flex-col rounded-md border border-border/50 bg-black/10 p-2.5"
                        title={item.name}
                      >
                        <div className="flex justify-between text-[13px] text-muted tabular-nums">
                          <span>#{item.slot}</span>
                          <span className="text-primary">x{item.count}</span>
                        </div>
                        <div className="h-16 flex items-center justify-center">
                          <InventoryItemImage item={item} className="w-14 h-14 object-contain" />
                        </div>
                        <p className="text-sm text-primary truncate">{item.label || item.name}</p>
                      </div>
                    ))}
                </div>
              )}
            </div>
          )}
        </Panel>
      </div>

      {vehicle && (
        <Modal
          title={vehicle.model.charAt(0).toUpperCase() + vehicle.model.slice(1)}
          subtitle={`${vehicle.plate} · ${vehicle.garage || '-'}`}
          onClose={() => openVehicle(null)}
          footer={
            confirmDelete ? (
              <>
                <Button variant="ghost" onClick={() => setConfirmDelete(false)}>
                  {t('common.cancel')}
                </Button>
                <Button variant="danger" onClick={() => vehicleAction('DeleteVehicle')}>
                  {t('ui.pages.database.vehicles.confirm_delete')}
                </Button>
              </>
            ) : (
              <Button variant="danger" icon={<Trash2 size={13} />} onClick={() => setConfirmDelete(true)}>
                {t('ui.pages.database.vehicles.delete_vehicle')}
              </Button>
            )
          }
        >
          <div className="space-y-4">
            <div>
              <Field label={t('ui.pages.database.vehicles.engine')}>
                <Meter className="w-32" value={(vehicle.engine ?? 1000) / 10} />
              </Field>
              <Field label={t('ui.pages.database.players.body')}>
                <Meter className="w-32" value={(vehicle.body ?? 1000) / 10} />
              </Field>
              <Field label={t('ui.pages.database.vehicles.fuel')}>
                <Meter className="w-32" value={vehicle.fuel ?? 100} />
              </Field>
            </div>
            <div>
              <Label>{t('ui.pages.database.vehicles.set_status')}</Label>
              <Segmented
                className="w-full"
                value={vehicle.state as (typeof STATES)[number]}
                onChange={(state) => state !== vehicle.state && vehicleAction('ChangeState', { NewState: state })}
                options={STATES.map((state) => ({ id: state, label: state }))}
              />
            </div>
            <div>
              <Label>{t('ui.pages.database.vehicles.change_plate')}</Label>
              <div className="flex gap-2">
                <input
                  className={`${inputClass} font-mono uppercase`}
                  value={newPlate}
                  maxLength={8}
                  onChange={(e) => setNewPlate(e.target.value.toUpperCase())}
                />
                <Button
                  icon={<Check size={13} />}
                  disabled={!newPlate.trim() || newPlate === vehicle.plate}
                  onClick={() => vehicleAction('ChangePlate', { NewPlate: newPlate.trim() })}
                />
              </div>
            </div>
            <div>
              <Label>{t('ui.pages.database.vehicles.garage_relocation')}</Label>
              <div className="flex gap-2">
                <Select
                  className="flex-1"
                  triggerClassName={inputClass}
                  value={newGarage}
                  onChange={setNewGarage}
                  options={[
                    { id: '', label: t('ui.pages.database.vehicles.deregistered_none') },
                    ...garages.map((garage) => ({ id: garage.Name, label: garage.Name })),
                  ]}
                />
                <Button
                  icon={<Check size={13} />}
                  disabled={newGarage === (vehicle.garage ?? '')}
                  onClick={() => vehicleAction('ChangeGarage', { NewGarage: newGarage })}
                />
              </div>
            </div>
          </div>
        </Modal>
      )}

      {alignmentType && (
        <Modal
          title={alignmentType === 'job' ? t('ui.pages.database.players.change_job') : t('ui.pages.database.players.change_gang')}
          subtitle={player.Name}
          onClose={() => setAlignmentType(null)}
          footer={
            <>
              <Button variant="ghost" onClick={() => setAlignmentType(null)}>
                {t('common.cancel')}
              </Button>
              <Button variant="primary" disabled={!target.id} onClick={saveAlignment}>
                {t('ui.pages.access.ranks.commit')}
              </Button>
            </>
          }
        >
          <div className="space-y-4">
            <div>
              <Label>{t('ui.pages.database.jobs_gangs.assigned_group')}</Label>
              <Select
                triggerClassName={inputClass}
                value={target.id}
                onChange={(id) => setTarget({ id, grade: 0 })}
                options={alignmentGroups.map((group) => ({ id: group.id, label: `${group.label} (${group.id})` }))}
              />
            </div>
            <div>
              <Label>{t('ui.pages.database.jobs_gangs.rank_grade')}</Label>
              {targetGrades.length > 0 ? (
                <div className="border border-border/60 rounded-md max-h-56 overflow-y-auto custom-scrollbar">
                  {[...targetGrades]
                    .sort((a, b) => a.level - b.level)
                    .map((grade) => (
                      <button
                        key={grade.level}
                        onClick={() => setTarget({ ...target, grade: grade.level })}
                        className={cn(
                          'w-full flex items-center gap-3 px-3 py-2 border-b border-border/30 last:border-0 text-left text-base',
                          target.grade === grade.level ? 'bg-accent/10 text-primary' : 'text-muted hover:bg-white/[0.04]',
                        )}
                      >
                        <span className="w-6 tabular-nums text-sm">{grade.level}</span>
                        <span className="flex-1 truncate">{grade.label}</span>
                        {target.grade === grade.level && <span className="w-1.5 h-1.5 rounded-full bg-accent" />}
                      </button>
                    ))}
                </div>
              ) : (
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={target.grade}
                  onChange={(e) => setTarget({ ...target, grade: parseInt(e.target.value) || 0 })}
                />
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};

export default PlayerDetailView;
