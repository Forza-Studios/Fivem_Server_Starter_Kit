import React, { useState, useEffect } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { fetchNui } from '../../../utils/fetchNui';
import { CustomTheme, RGB } from '../../../types';

function hexToRgb(hex: string): RGB {
  const clean = hex.replace('#', '').padEnd(6, '0');
  const result = /^([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(clean);
  return result
    ? { r: parseInt(result[1], 16), g: parseInt(result[2], 16), b: parseInt(result[3], 16) }
    : { r: 0, g: 0, b: 0 };
}

function rgbToHex({ r, g, b }: RGB): string {
  return '#' + [r, g, b].map((v) => Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0')).join('');
}

export function applyCustomThemeVars(bg: RGB, accent: RGB, sidebar: RGB) {
  const root = document.documentElement;
  root.style.setProperty('--bg-primary', `${bg.r}, ${bg.g}, ${bg.b}`);
  root.style.setProperty(
    '--bg-secondary',
    `${Math.min(bg.r + 14, 255)}, ${Math.min(bg.g + 14, 255)}, ${Math.min(bg.b + 14, 255)}`,
  );
  root.style.setProperty('--sidebar-bg', `${sidebar.r}, ${sidebar.g}, ${sidebar.b}`);
  root.style.setProperty('--accent', `${accent.r}, ${accent.g}, ${accent.b}`);
  root.style.setProperty('--text-primary', `240, 246, 252`);
  root.style.setProperty('--text-muted', `139, 148, 158`);
  root.style.setProperty(
    '--border',
    `${Math.min(bg.r + 40, 255)}, ${Math.min(bg.g + 40, 255)}, ${Math.min(bg.b + 40, 255)}`,
  );
}

export function clearCustomThemeVars() {
  const root = document.documentElement;
  const props = [
    '--bg-primary',
    '--bg-secondary',
    '--sidebar-bg',
    '--accent',
    '--text-primary',
    '--text-muted',
    '--border',
    '--theme-white',
    '--theme-black',
  ];
  props.forEach((p) => root.style.removeProperty(p));
}

const SAVED_KEY = 'adminMenuCustomThemes';

export function getSavedCustomThemes(): CustomTheme[] {
  try {
    return JSON.parse(localStorage.getItem(SAVED_KEY) || '[]');
  } catch {
    return [];
  }
}

interface Props {
  onClose: () => void;
  onApply: (themeId: string) => void;
}

const CustomThemeEditor: React.FC<Props> = ({ onClose, onApply }) => {
  const { t } = useAdminMenu();
  const [bg, setBg] = useState<RGB>(hexToRgb('#0d1117'));
  const [accent, setAccent] = useState<RGB>(hexToRgb('#3b82f6'));
  const [sidebar, setSidebar] = useState<RGB>(hexToRgb('#010409'));
  const [step, setStep] = useState<'edit' | 'name'>('edit');
  const [themeName, setThemeName] = useState('');

  // Live preview as colours change
  useEffect(() => {
    applyCustomThemeVars(bg, accent, sidebar);
  }, [bg, accent, sidebar]);

  const handleColorRow = (val: string, setter: (r: RGB) => void) => {
    setter(hexToRgb(val));
  };

  const handleConfirm = () => {
    if (!themeName.trim()) return;
    const id = `custom_${Date.now()}`;
    const existing = getSavedCustomThemes();
    const newTheme = { id, name: themeName.trim(), bg, accent, sidebar };
    const updatedThemes = [...existing, newTheme];
    localStorage.setItem(SAVED_KEY, JSON.stringify(updatedThemes));

    // Persist custom themes to the persistent client KVP database
    fetchNui('setPreference', { type: 'options', key: 'CustomThemes', value: updatedThemes }).catch(() => {});

    // Keep the custom vars applied
    applyCustomThemeVars(bg, accent, sidebar);
    onApply(id);
    onClose();
  };

  const previewAccent = rgbToHex(accent);

  const rows = [
    { label: t('ui.pages.options.custom_themes.bg'), icon: 'fa-fill', value: bg, setter: setBg },
    { label: t('ui.pages.options.custom_themes.accent'), icon: 'fa-star', value: accent, setter: setAccent },
    { label: t('ui.pages.options.custom_themes.sidebar'), icon: 'fa-sidebar', value: sidebar, setter: setSidebar },
  ];

  return (
    <div className="absolute inset-0 bg-black/85 z-50 flex items-center justify-center p-6 animate-in fade-in duration-200">
      <div className="bg-[#0d0e12] border border-white/10 rounded-2xl w-full max-w-sm flex flex-col outline outline-1 outline-white/5 overflow-hidden">
        {/* Header */}
        <div className="px-6 py-5 border-b border-white/10 flex items-center justify-between bg-[#0a0b0f]">
          <div className="flex items-center gap-3">
            <div
              className="w-9 h-9 rounded-xl flex items-center justify-center text-base border border-white/10"
              style={{
                background: `conic-gradient(${previewAccent}, #6366f1, #d946ef, #f97316, #10b981, ${previewAccent})`,
              }}
            >
              <i className="fa-solid fa-palette text-white text-sm"></i>
            </div>
            <div>
              <h2 className="text-base font-rajdhani font-bold text-white uppercase tracking-wider leading-none">
                {step === 'edit'
                  ? t('ui.pages.options.custom_themes.title')
                  : t('ui.pages.options.custom_themes.save_title')}
              </h2>
              <p className="text-[10px] font-mono mt-1 text-white/40 uppercase tracking-wider">
                {step === 'edit'
                  ? t('ui.pages.options.custom_themes.preview')
                  : t('ui.pages.options.custom_themes.name_prompt')}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-lg hover:bg-white/10 text-white/40 hover:text-white transition-all flex items-center justify-center border border-white/5"
          >
            <i className="fa-solid fa-xmark text-sm"></i>
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-4">
          {step === 'edit' ? (
            <>
              {rows.map((row) => (
                <div
                  key={row.label}
                  className="flex items-center gap-4 p-3 rounded-xl bg-white/3 border border-white/5"
                >
                  <div
                    className="w-9 h-9 rounded-lg border-2 border-white/20 shrink-0 cursor-pointer overflow-hidden relative "
                    style={{ backgroundColor: rgbToHex(row.value) }}
                  >
                    <input
                      type="color"
                      value={rgbToHex(row.value)}
                      onChange={(e) => handleColorRow(e.target.value, row.setter)}
                      className="absolute inset-0 opacity-0 w-full h-full cursor-pointer"
                    />
                  </div>
                  <div className="flex-1">
                    <p className="text-[10px] font-rajdhani font-bold uppercase tracking-[0.15em] text-white/50 mb-1">
                      <i className={`fa-solid ${row.icon} mr-1.5 opacity-60`}></i>
                      {row.label}
                    </p>
                    <input
                      type="text"
                      value={rgbToHex(row.value)}
                      onChange={(e) => handleColorRow(e.target.value, row.setter)}
                      maxLength={7}
                      className="w-full bg-transparent text-sm font-mono text-white/90 focus:outline-none border-b border-white/10 focus:border-accent pb-0.5 transition-colors"
                    />
                  </div>
                  {/* Live mini swatch */}
                  <div
                    className="w-6 h-6 rounded-full shrink-0 border border-white/10"
                    style={{ backgroundColor: rgbToHex(row.value) }}
                  />
                </div>
              ))}
            </>
          ) : (
            <div className="space-y-3">
              <p className="text-sm text-white/50 font-barlow text-center leading-relaxed">
                {t('ui.pages.options.custom_themes.saved_msg')}
              </p>
              <div className="relative">
                <i className="fa-solid fa-tag absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-xs"></i>
                <input
                  autoFocus
                  type="text"
                  value={themeName}
                  onChange={(e) => setThemeName(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleConfirm()}
                  placeholder={t('ui.pages.options.custom_themes.placeholder')}
                  maxLength={24}
                  className="w-full bg-white/5 border border-white/10 focus:border-accent rounded-xl pl-9 pr-4 py-3 text-sm text-white font-barlow focus:outline-none transition-colors placeholder:text-white/20"
                />
              </div>
              {/* Color summary */}
              <div className="flex gap-2 pt-2 justify-center">
                {[bg, accent, sidebar].map((c, i) => (
                  <div
                    key={i}
                    className="w-8 h-8 rounded-full border-2 border-white/20 "
                    style={{ backgroundColor: rgbToHex(c) }}
                  />
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 pb-6 flex gap-3">
          {step === 'edit' ? (
            <>
              <button
                onClick={onClose}
                className="flex-1 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/50 hover:text-white font-barlow font-bold uppercase text-xs tracking-wider border border-white/5 transition-all"
              >
                {t('ui.pages.options.custom_themes.cancel')}
              </button>
              <button
                onClick={() => setStep('name')}
                className="flex-[2] py-2.5 rounded-xl text-white font-barlow font-bold uppercase text-xs tracking-wider transition-all flex items-center justify-center gap-2 "
                style={{ backgroundColor: previewAccent }}
              >
                <i className="fa-solid fa-arrow-right text-xs"></i>
                {t('ui.pages.options.custom_themes.save')}
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => setStep('edit')}
                className="flex-1 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/50 hover:text-white font-barlow font-bold uppercase text-xs tracking-wider border border-white/5 transition-all"
              >
                <i className="fa-solid fa-arrow-left text-xs mr-1"></i> {t('ui.pages.options.custom_themes.back')}
              </button>
              <button
                onClick={handleConfirm}
                disabled={!themeName.trim()}
                className="flex-[2] py-2.5 rounded-xl text-white font-barlow font-bold uppercase text-xs tracking-wider transition-all flex items-center justify-center gap-2 disabled:opacity-30"
                style={{ backgroundColor: previewAccent }}
              >
                <i className="fa-solid fa-check text-xs"></i>
                {t('ui.pages.options.custom_themes.confirm')}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default CustomThemeEditor;
