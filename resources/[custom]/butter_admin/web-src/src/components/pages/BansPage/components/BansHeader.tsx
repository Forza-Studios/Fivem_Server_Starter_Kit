import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface BansHeaderProps {
  activeCount: number;
  historyCount: number;
  permanentCount: number;
}

const StatTile: React.FC<{ icon: string; label: string; value: number; tone: 'red' | 'emerald' | 'amber' }> = ({
  icon,
  label,
  value,
  tone,
}) => {
  const tones = {
    red: 'text-red-400 bg-red-500/10 border-red-500/20',
    emerald: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20',
    amber: 'text-amber-400 bg-amber-500/10 border-amber-500/20',
  } as const;
  return (
    <div className="flex items-center gap-3 rounded-xl bg-black/30 border border-white/5 px-4 py-3 flex-1 min-w-[130px]">
      <div className={`w-9 h-9 rounded-lg border flex items-center justify-center ${tones[tone]}`}>
        <i className={`${icon} text-sm`}></i>
      </div>
      <div className="leading-none">
        <p className="font-rajdhani font-bold text-xl text-primary">{value}</p>
        <p className="font-mono text-[10px] uppercase tracking-widest text-muted mt-1">{label}</p>
      </div>
    </div>
  );
};

export const BansHeader: React.FC<BansHeaderProps> = ({ activeCount, historyCount, permanentCount }) => {
  const { t } = useAdminMenu();
  return (
    <div className="mb-6">
      <div className="flex items-center gap-4 mb-5">
        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-red-500/20 to-accent/10 border border-red-500/30 flex items-center justify-center text-red-400">
          <i className="fa-solid fa-gavel text-2xl"></i>
        </div>
        <div>
          <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
            {t('ui.pages.bans.title')}
          </h2>
          <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
            {t('ui.pages.bans.subtitle')}
          </p>
        </div>
      </div>
      <div className="flex flex-wrap gap-3">
        <StatTile icon="fa-solid fa-ban" label={t('ui.pages.bans.active_bans')} value={activeCount} tone="red" />
        <StatTile
          icon="fa-solid fa-infinity"
          label={t('ui.pages.bans.permanent')}
          value={permanentCount}
          tone="amber"
        />
        <StatTile
          icon="fa-solid fa-clock-rotate-left"
          label={t('ui.pages.bans.history')}
          value={historyCount}
          tone="emerald"
        />
      </div>
    </div>
  );
};
