import React from 'react';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface CurrentTargetBannerProps {
  currentTarget: { Text: string; Source: string | number } | null;
  onClear: () => void;
}

export const CurrentTargetBanner: React.FC<CurrentTargetBannerProps> = ({ currentTarget, onClear }) => {
  const { t } = useAdminMenu();
  if (!currentTarget) return null;
  return (
    <div
      className="mb-4 bg-accent/20 border border-accent/50 text-accent px-4 py-2 rounded-lg text-sm font-barlow flex justify-between items-center cursor-pointer hover:bg-accent/30 transition-colors animate-in fade-in slide-in-from-top-2 duration-300"
      onClick={onClear}
    >
      <span>
        <i className="fa-solid fa-crosshairs mr-2"></i> {t('ui.pages.players.current_target', currentTarget.Text)}
      </span>
      <i className="fa-solid fa-times"></i>
    </div>
  );
};
