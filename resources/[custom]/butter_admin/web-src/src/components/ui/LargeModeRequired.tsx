import React from 'react';
import { useAdminMenu } from '../../providers/AdminMenuContext';

interface LargeModeRequiredProps {
  pageName: string;
  description?: string;
}

const LargeModeRequired: React.FC<LargeModeRequiredProps> = ({ pageName, description }) => {
  const { t, changeSize } = useAdminMenu();

  return (
    <div className="w-full h-full flex flex-col items-center justify-center p-8 text-center animate-in fade-in duration-500">
      <div className="w-24 h-24 mb-6 rounded-full bg-white/5 flex items-center justify-center text-white/20 border border-white/10">
        <i className="fa-solid fa-face-frown text-5xl"></i>
      </div>

      <h2 className="text-xl font-rajdhani font-bold text-white tracking-widest uppercase mb-2">
        {pageName} {t('info.large_mode_required_title') || 'are best viewed in Large Mode.'}
      </h2>

      <p className="text-white/40 font-rajdhani text-sm max-w-xs leading-relaxed mb-8">
        {description ||
          t('info.large_mode_required_desc') ||
          'Please expand the menu using the button on the left to view this page.'}
      </p>

      <button
        onClick={() => changeSize('Large')}
        className="px-6 py-2 bg-accent/20 hover:bg-accent/30 border border-accent/30 text-accent text-xs font-rajdhani font-bold tracking-widest uppercase rounded-lg transition-all duration-300 hover:scale-105 active:scale-95"
      >
        Expand Menu
      </button>
    </div>
  );
};

export default LargeModeRequired;
