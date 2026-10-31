import React from 'react';
import { useAdminMenu } from '../../../../providers/AdminMenuContext';

interface DeleteModalProps {
  onCancel: () => void;
  onConfirm: () => void;
}

export const DeleteModal: React.FC<DeleteModalProps> = ({ onCancel, onConfirm }) => {
  const { t } = useAdminMenu();
  return (
    <div className="fixed inset-0 z-[999999] flex items-center justify-center bg-black/60 animate-in fade-in duration-200">
      <div className="bg-bg-secondary border border-border/50 rounded-lg p-6 max-w-sm w-full mx-4 animate-in zoom-in-95 duration-200">
        <div className="flex items-center gap-3 mb-4 text-red-500">
          <i className="fa-solid fa-triangle-exclamation text-2xl"></i>
          <h3 className="text-xl font-rajdhani font-bold text-primary">{t('ui.pages.reports.delete_title')}</h3>
        </div>
        <p className="text-muted font-barlow text-sm mb-6">{t('ui.pages.reports.delete_confirm_desc')}</p>
        <div className="flex justify-end gap-3">
          <button
            className="px-4 py-2 rounded font-rajdhani font-semibold text-sm bg-black/40 text-primary hover:bg-black/60 transition-colors border border-border/50"
            onClick={onCancel}
          >
            {t('common.cancel')}
          </button>
          <button
            className="px-4 py-2 rounded font-rajdhani font-semibold text-sm bg-red-500 text-white hover:bg-red-600 transition-colors "
            onClick={onConfirm}
          >
            {t('common.delete')}
          </button>
        </div>
      </div>
    </div>
  );
};

interface CloseModalProps {
  closingNotes: string;
  setClosingNotes: (v: string) => void;
  onCancel: () => void;
  onConfirm: () => void;
}

export const CloseTicketModal: React.FC<CloseModalProps> = ({ closingNotes, setClosingNotes, onCancel, onConfirm }) => {
  const { t } = useAdminMenu();
  return (
    <div className="fixed inset-0 z-[999999] flex items-center justify-center bg-black/60 animate-in fade-in duration-200">
      <div className="bg-bg-secondary border border-border/50 rounded-lg p-6 max-w-md w-full mx-4 animate-in zoom-in-95 duration-200">
        <div className="flex items-center gap-3 mb-4 text-orange-400">
          <i className="fa-solid fa-lock text-2xl"></i>
          <h3 className="text-xl font-rajdhani font-bold text-primary">{t('ui.pages.reports.close_ticket')}</h3>
        </div>
        <p className="text-muted font-barlow text-sm mb-4">{t('ui.pages.reports.close_confirm_desc')}</p>
        <textarea
          className="w-full bg-black/40 border border-border/50 rounded-lg p-3 text-primary font-barlow text-sm focus:outline-none focus:border-accent transition-colors mb-6 min-h-[100px] resize-none"
          placeholder={t('ui.pages.reports.close_placeholder')}
          value={closingNotes}
          onChange={(e) => setClosingNotes(e.target.value)}
          autoFocus
        />
        <div className="flex justify-end gap-3">
          <button
            className="px-4 py-2 rounded font-rajdhani font-semibold text-sm bg-black/40 text-primary hover:bg-black/60 transition-colors border border-border/50"
            onClick={onCancel}
          >
            {t('common.cancel')}
          </button>
          <button
            className={`px-4 py-2 rounded font-rajdhani font-semibold text-sm transition-colors ${
              closingNotes.trim()
                ? 'bg-orange-500 text-white hover:bg-orange-600 '
                : 'bg-orange-500/50 text-white/50 cursor-not-allowed'
            }`}
            onClick={onConfirm}
            disabled={!closingNotes.trim()}
          >
            {t('ui.pages.reports.close_ticket')}
          </button>
        </div>
      </div>
    </div>
  );
};
