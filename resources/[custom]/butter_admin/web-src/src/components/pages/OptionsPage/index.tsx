import React, { useState, useEffect } from 'react';
import { useAdminMenu } from '../../../providers/AdminMenuContext';
import { MenuOptions } from '../../../types';
import { fetchNui } from '../../../utils/fetchNui';
import { SubTabs } from '../../ui/SubTabs';
import CustomThemeEditor, { clearCustomThemeVars, getSavedCustomThemes } from './CustomThemeEditor';
import {
  getUserScale,
  setUserScale,
  USER_SCALE_MIN,
  USER_SCALE_MAX,
  USER_SCALE_DEFAULT,
} from '../../../hooks/useResolutionScale';
import {
  FONTS,
  getFontScale,
  setFontScale,
  FONT_SCALE_MIN,
  FONT_SCALE_MAX,
  FONT_SCALE_DEFAULT,
} from '../../../utils/fonts';
import { dropdownPositionFrom } from '../../../utils/dropdownPosition';

interface OptionItem {
  id: 'LargeDefault' | 'BindOpen' | 'Tooltips' | 'Resizer';
  label: string;
}
const OPTION_ITEMS: OptionItem[] = [
  { id: 'LargeDefault', label: 'ui.pages.options.large_default' },
  { id: 'BindOpen', label: 'ui.pages.options.bind_open' },
  { id: 'Tooltips', label: 'ui.pages.options.tooltips' },
  { id: 'Resizer', label: 'ui.pages.options.resizer' },
];
const THEMES = [
  { id: 'Dark', name: 'Dark', color: '#0d1117', accent: '#3b82f6' },
  { id: 'Midnight', name: 'Midnight', color: '#111827', accent: '#6366f1' },
  { id: 'Cyberpunk', name: 'Cyberpunk', color: '#000000', accent: '#facc15' },
  { id: 'Crimson', name: 'Crimson', color: '#0f0a0a', accent: '#dc2626' },
  { id: 'Emerald', name: 'Emerald', color: '#061a10', accent: '#10b981' },
  { id: 'Amethyst', name: 'Amethyst', color: '#1a0b2e', accent: '#a855f7' },
  { id: 'Sunset', name: 'Sunset', color: '#2a0f15', accent: '#f97316' },
  { id: 'Ocean', name: 'Ocean', color: '#081c24', accent: '#06b6d4' },
  { id: 'Forest', name: 'Forest', color: '#0f1c13', accent: '#84cc16' },
  { id: 'Gold', name: 'Gold', color: '#121212', accent: '#eab308' },
  { id: 'Bubble', name: 'Bubble', color: '#fdf4ff', accent: '#d946ef' },
  { id: 'Cloud', name: 'Cloud', color: '#f0f9ff', accent: '#0ea5e9' },
  { id: 'Mint', name: 'Mint', color: '#f0fdf4', accent: '#22c55e' },
  { id: 'Peach', name: 'Peach', color: '#fff7ed', accent: '#f97316' },
];

const ThemePreviewBox = ({
  data,
  label,
  isActive,
}: {
  data: { name: string; bg: string; accent: string };
  label: string;
  isActive?: boolean;
}) => (
  <div
    className={`flex flex-col gap-2 w-full animate-in fade-in duration-300 ${isActive ? 'opacity-100' : 'opacity-90 hover:opacity-100 transition-opacity'}`}
  >
    <span
      className={`text-[10px] font-rajdhani font-bold uppercase tracking-widest pl-1 ${isActive ? 'text-accent' : 'text-muted'}`}
    >
      {label}
    </span>
    <div
      className={`w-full aspect-video rounded-xl overflow-hidden relative transition-all duration-500 ease-out border-2 ${isActive ? 'border-accent/80' : 'border-white/10'}`}
      style={{ backgroundColor: data.bg }}
    >
      {/* Mock Header */}
      <div className="h-6 w-full bg-white/5 border-b border-white/5 flex items-center px-3 gap-2">
        <div className="flex gap-1">
          <div className="w-1.5 h-1.5 rounded-full bg-white/20"></div>
          <div className="w-1.5 h-1.5 rounded-full bg-white/20"></div>
        </div>
        <div className="w-16 h-1.5 rounded-full ml-auto" style={{ backgroundColor: data.accent, opacity: 0.8 }}></div>
      </div>
      {/* Mock Content */}
      <div className="flex h-[calc(100%-1.5rem)] w-full">
        <div className="w-1/4 h-full bg-white/5 border-r border-white/5 p-2 flex flex-col gap-2">
          <div className="w-full h-1.5 rounded bg-white/10"></div>
          <div className="w-3/4 h-1.5 rounded bg-white/10"></div>
          <div className="w-full h-1.5 rounded" style={{ backgroundColor: data.accent, opacity: 0.9 }}></div>
          <div className="w-2/3 h-1.5 rounded bg-white/10"></div>
        </div>
        <div className="flex-1 p-3 flex flex-col gap-3">
          <div className="w-1/3 h-2 rounded" style={{ backgroundColor: data.accent }}></div>
          <div className="grid grid-cols-2 gap-2">
            <div className="h-10 rounded-lg bg-white/5 border border-white/5 relative overflow-hidden">
              <div className="absolute left-0 top-0 bottom-0 w-1" style={{ backgroundColor: data.accent }}></div>
            </div>
            <div className="h-10 rounded-lg bg-white/5 border border-white/5"></div>
          </div>
          <div className="w-full flex-1 rounded-lg bg-white/5 border border-white/5 relative overflow-hidden">
            <div className="absolute top-2 left-2 w-1/4 h-2 bg-white/10 rounded"></div>
          </div>
        </div>
      </div>
      <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-white/5 pointer-events-none mix-blend-overlay"></div>
    </div>
    <div className="flex items-center justify-between mt-1 px-1">
      <span className="font-barlow font-bold text-primary text-sm truncate pr-2">{data.name}</span>
      <div className="flex gap-1.5 shrink-0">
        <div
          className="w-3.5 h-3.5 rounded-full "
          style={{ backgroundColor: data.bg, border: '1px solid rgba(255,255,255,0.15)' }}
        ></div>
        <div className="w-3.5 h-3.5 rounded-full" style={{ backgroundColor: data.accent }}></div>
      </div>
    </div>
  </div>
);

const OptionsPage: React.FC = () => {
  const { options, setOptions, changeSize, theme, setTheme, font, setFont, menuSize, setDropdown, t } = useAdminMenu();
  const [activeTab, setActiveTab] = useState<'themes' | 'preferences'>('themes');
  const [customEditorOpen, setCustomEditorOpen] = useState(false);
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [savedCustomThemes, setSavedCustomThemes] = useState(() => getSavedCustomThemes());
  const [hoveredThemeId, setHoveredThemeId] = useState<string | null>(null);
  const [uiScale, setUiScale] = useState<number>(() => getUserScale());
  const [fontScale, setFontScaleState] = useState<number>(() => getFontScale());

  const handleUiScaleChange = (value: number) => {
    const applied = setUserScale(value);
    setUiScale(applied);
  };

  const handleFontScaleChange = (value: number) => {
    const applied = setFontScale(value);
    setFontScaleState(applied);
  };

  const getThemePreviewData = (themeId: string) => {
    const preset = THEMES.find((t) => t.id === themeId);
    if (preset) return { name: preset.name, bg: preset.color, accent: preset.accent };

    const custom = savedCustomThemes.find((t) => t.id === themeId);
    if (custom)
      return {
        name: custom.name,
        bg: `rgb(${custom.bg.r},${custom.bg.g},${custom.bg.b})`,
        accent: `rgb(${custom.accent.r},${custom.accent.g},${custom.accent.b})`,
      };

    return { name: 'Unknown', bg: '#000000', accent: '#ffffff' };
  };

  const activeThemeData = getThemePreviewData(theme);
  const previewThemeData = hoveredThemeId ? getThemePreviewData(hoveredThemeId) : activeThemeData;

  useEffect(() => {
    if (options && options.CustomThemes) {
      setSavedCustomThemes(options.CustomThemes);
    }
  }, [options]);

  useEffect(() => {
    if (options.LargeDefault) changeSize('Large');
  }, [options.LargeDefault, changeSize]);

  const handleOptionChange = <K extends keyof MenuOptions>(optionKey: K, value: MenuOptions[K]) => {
    setOptions((previous) => ({ ...previous, [optionKey]: value }));
    fetchNui('setPreference', { type: 'options', key: optionKey, value }).catch(() => {});
    if (optionKey === 'LargeDefault') changeSize(value ? 'Large' : 'Small');
  };

  const handleThemeChange = (themeId: string) => {
    // Clear any inline CSS vars from the custom theme editor BEFORE applying a preset
    clearCustomThemeVars();
    setTheme(themeId);
    localStorage.setItem('adminMenuTheme', themeId);
    fetchNui('setPreference', { type: 'options', key: 'Theme', value: themeId }).catch(() => {});
  };

  const handleFontChange = (fontId: string) => {
    setFont(fontId);
    localStorage.setItem('adminMenuFont', fontId);
    fetchNui('setPreference', { type: 'options', key: 'Font', value: fontId }).catch(() => {});
  };

  const handleResetMenu = () => {
    fetchNui('resetPreferences').catch(() => {});

    clearCustomThemeVars();
    setTheme('Dark');
    localStorage.removeItem('adminMenuTheme');
    localStorage.removeItem('adminMenuCustomThemes');
    setSavedCustomThemes([]);

    setShowResetConfirm(false);
  };

  return (
    <div className="flex flex-col h-full w-full overflow-hidden">
      <div className="p-6 pb-2">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-gear text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {t('ui.pages.options.title')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70 font-bold">
                {t('ui.pages.options.subtitle')}
              </p>
            </div>
          </div>
        </div>

        <div className="border-b border-white/10 pb-4 mb-6">
          <SubTabs
            tabs={[
              { id: 'themes', label: t('ui.pages.options.themes'), icon: 'fa-solid fa-palette' },
              { id: 'preferences', label: t('ui.pages.options.preferences'), icon: 'fa-solid fa-sliders' },
            ]}
            activeTab={activeTab}
            onChange={setActiveTab}
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6 custom-scrollbar animate-in fade-in duration-200">
        {activeTab === 'themes' && (
          <>
            {menuSize === 'Large' ? (
              <div className="flex gap-8 h-full w-full">
                {/* Left side: Themes Grid */}
                <div className="w-1/2 flex flex-col h-full overflow-hidden">
                  <h3 className="text-xs font-rajdhani font-bold text-accent uppercase tracking-[0.2em] mb-4 shrink-0 flex items-center gap-2">
                    <i className="fa-solid fa-swatchbook"></i> {t('ui.pages.options.available_themes')}
                  </h3>
                  <div className="grid grid-cols-3 gap-3 overflow-y-auto pr-2 pb-6 custom-scrollbar content-start">
                    {THEMES.map((t) => (
                      <div
                        key={t.id}
                        onClick={() => handleThemeChange(t.id)}
                        onMouseEnter={() => setHoveredThemeId(t.id)}
                        onMouseLeave={() => setHoveredThemeId(null)}
                        className={`flex flex-col items-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 ${theme === t.id ? 'border-accent bg-accent/10' : 'border-white/5 bg-black/20 hover:border-white/20 hover:bg-white/5'}`}
                      >
                        <div
                          className="w-10 h-10 rounded-full mb-2 relative overflow-hidden"
                          style={{ backgroundColor: t.color }}
                        >
                          <div
                            className="absolute bottom-0 right-0 w-5 h-5 rounded-tl-full"
                            style={{ backgroundColor: t.accent }}
                          ></div>
                        </div>
                        <span className="font-barlow text-xs font-medium text-primary">{t.name}</span>
                      </div>
                    ))}

                    {/* Saved Custom Themes */}
                    {savedCustomThemes.map((ct) => (
                      <div
                        key={ct.id}
                        onClick={() => handleThemeChange(ct.id)}
                        onMouseEnter={() => setHoveredThemeId(ct.id)}
                        onMouseLeave={() => setHoveredThemeId(null)}
                        className={`flex flex-col items-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 ${theme === ct.id ? 'border-accent bg-accent/10' : 'border-white/5 bg-black/20 hover:border-white/20 hover:bg-white/5'}`}
                      >
                        <div className="w-10 h-10 rounded-full mb-2 relative overflow-hidden">
                          <div
                            className="absolute inset-0"
                            style={{ backgroundColor: `rgb(${ct.bg.r},${ct.bg.g},${ct.bg.b})` }}
                          />
                          <div
                            className="absolute bottom-0 right-0 w-5 h-5 rounded-tl-full"
                            style={{ backgroundColor: `rgb(${ct.accent.r},${ct.accent.g},${ct.accent.b})` }}
                          />
                        </div>
                        <span className="font-barlow text-xs font-medium text-primary truncate w-full text-center">
                          {ct.name}
                        </span>
                        <span className="text-[9px] text-accent/80 font-mono uppercase tracking-wider mt-0.5">
                          {t('ui.pages.options.custom')}
                        </span>
                      </div>
                    ))}

                    {/* Create Custom Theme Tile */}
                    <div
                      onClick={() => setCustomEditorOpen(true)}
                      className="flex flex-col items-center justify-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 border-dashed border-white/10 bg-black/20 hover:border-accent/50 hover:bg-accent/5"
                    >
                      <div
                        className="w-10 h-10 rounded-full mb-2 relative overflow-hidden flex items-center justify-center border border-white/10"
                        style={{
                          background:
                            'conic-gradient(from 180deg, #3b82f6, #8b5cf6, #d946ef, #f43f5e, #f97316, #eab308, #22c55e, #06b6d4, #3b82f6)',
                        }}
                      >
                        <div className="absolute inset-0 bg-black/20 mix-blend-overlay"></div>
                        <i className="fa-solid fa-plus text-white text-sm relative z-10"></i>
                      </div>
                      <span className="font-barlow text-xs font-medium text-primary">
                        {t('ui.pages.options.custom_themes.title')}
                      </span>
                      <span className="text-[9px] text-accent/80 font-mono uppercase tracking-wider mt-0.5">
                        {t('ui.pages.options.custom_themes.new_theme')}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Right side: Previews Side by Side */}
                <div className="w-1/2 flex flex-col bg-black/20 border border-white/5 rounded-2xl p-6 relative overflow-hidden">
                  <h3 className="text-xs font-rajdhani font-bold text-accent uppercase tracking-[0.2em] mb-8 shrink-0 flex items-center gap-2 relative z-10">
                    <i className="fa-solid fa-code-compare"></i> {t('ui.pages.options.live_comparison')}
                  </h3>

                  <div className="flex gap-6 flex-1 items-center justify-center relative z-10 w-full">
                    {/* Current Theme */}
                    <div className="w-1/2 h-full max-h-[300px] flex items-center justify-center">
                      <ThemePreviewBox
                        data={activeThemeData}
                        label={t('ui.pages.options.custom_themes.current_active')}
                        isActive={true}
                      />
                    </div>

                    {/* VS divider */}
                    <div className="shrink-0 flex flex-col items-center justify-center px-2">
                      <div className="h-16 w-px bg-gradient-to-b from-transparent via-white/20 to-transparent"></div>
                      <div className="w-8 h-8 rounded-full bg-black/40 border border-white/10 flex items-center justify-center my-2">
                        <i className="fa-solid fa-angle-right text-white/30 text-xs"></i>
                      </div>
                      <div className="h-16 w-px bg-gradient-to-b from-transparent via-white/20 to-transparent"></div>
                    </div>

                    {/* Preview Theme */}
                    <div className="w-1/2 h-full max-h-[300px] flex items-center justify-center">
                      <ThemePreviewBox
                        data={previewThemeData}
                        label={
                          hoveredThemeId && hoveredThemeId !== theme
                            ? t('ui.pages.options.hover_preview')
                            : t('ui.pages.options.selected')
                        }
                        isActive={false}
                      />
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 pb-6">
                {THEMES.map((t) => (
                  <div
                    key={t.id}
                    onClick={() => handleThemeChange(t.id)}
                    className={`flex flex-col items-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 ${theme === t.id ? 'border-accent bg-accent/10' : 'border-white/5 bg-black/20 hover:border-white/20 hover:bg-white/5'}`}
                  >
                    <div
                      className="w-12 h-12 rounded-full mb-2 relative overflow-hidden"
                      style={{ backgroundColor: t.color }}
                    >
                      <div
                        className="absolute bottom-0 right-0 w-6 h-6 rounded-tl-full"
                        style={{ backgroundColor: t.accent }}
                      ></div>
                    </div>
                    <span className="font-barlow text-sm font-medium text-primary">{t.name}</span>
                  </div>
                ))}

                {/* Saved Custom Themes */}
                {savedCustomThemes.map((ct) => (
                  <div
                    key={ct.id}
                    onClick={() => handleThemeChange(ct.id)}
                    className={`flex flex-col items-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 ${theme === ct.id ? 'border-accent bg-accent/10' : 'border-white/5 bg-black/20 hover:border-white/20 hover:bg-white/5'}`}
                  >
                    <div className="w-12 h-12 rounded-full mb-2 relative overflow-hidden">
                      <div
                        className="absolute inset-0"
                        style={{ backgroundColor: `rgb(${ct.bg.r},${ct.bg.g},${ct.bg.b})` }}
                      />
                      <div
                        className="absolute bottom-0 right-0 w-6 h-6 rounded-tl-full"
                        style={{ backgroundColor: `rgb(${ct.accent.r},${ct.accent.g},${ct.accent.b})` }}
                      />
                    </div>
                    <span className="font-barlow text-sm font-medium text-primary truncate w-full text-center">
                      {ct.name}
                    </span>
                    <span className="text-[9px] text-accent/80 font-mono uppercase tracking-wider mt-0.5">
                      {t('ui.pages.options.custom')}
                    </span>
                  </div>
                ))}

                {/* Create Custom Theme Tile */}
                <div
                  onClick={() => setCustomEditorOpen(true)}
                  className="flex flex-col items-center justify-center p-3 rounded-xl cursor-pointer transition-all-smooth border-2 border-dashed border-white/10 bg-black/20 hover:border-accent/50 hover:bg-accent/5"
                >
                  <div
                    className="w-12 h-12 rounded-full mb-2 relative overflow-hidden flex items-center justify-center border border-white/10"
                    style={{
                      background:
                        'conic-gradient(from 180deg, #3b82f6, #8b5cf6, #d946ef, #f43f5e, #f97316, #eab308, #22c55e, #06b6d4, #3b82f6)',
                    }}
                  >
                    <div className="absolute inset-0 bg-black/20 mix-blend-overlay"></div>
                    <i className="fa-solid fa-plus text-white text-lg relative z-10"></i>
                  </div>
                  <span className="font-barlow text-sm font-medium text-primary">
                    {t('ui.pages.options.custom_themes.title')}
                  </span>
                  <span className="text-[9px] text-accent/80 font-mono uppercase tracking-wider mt-0.5">
                    {t('ui.pages.options.custom_themes.new_theme')}
                  </span>
                </div>
              </div>
            )}
          </>
        )}
        {activeTab === 'preferences' && (
          <div className="space-y-4">
            {/* Interface / Menu Size */}
            <div className="p-4 rounded-xl bg-black/20 border border-white/5">
              <div className="flex items-center justify-between mb-1">
                <span className="font-barlow text-primary font-medium">{t('ui.pages.options.ui_scale')}</span>
                <div className="flex items-center gap-3">
                  <span className="font-mono text-sm font-bold text-accent tabular-nums w-14 text-right">
                    {Math.round(uiScale * 100)}%
                  </span>
                  {Math.abs(uiScale - USER_SCALE_DEFAULT) > 0.001 && (
                    <button
                      onClick={() => handleUiScaleChange(USER_SCALE_DEFAULT)}
                      className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted hover:text-accent transition-colors"
                    >
                      {t('ui.pages.options.reset_default')}
                    </button>
                  )}
                </div>
              </div>
              <p className="text-[10px] font-barlow text-muted opacity-70 leading-relaxed mb-3">
                {t('ui.pages.options.ui_scale_desc')}
              </p>
              <div className="flex items-center gap-3">
                <i className="fa-solid fa-magnifying-glass-minus text-muted text-xs shrink-0"></i>
                <input
                  type="range"
                  min={USER_SCALE_MIN}
                  max={USER_SCALE_MAX}
                  step={0.05}
                  value={uiScale}
                  onChange={(e) => handleUiScaleChange(parseFloat(e.target.value))}
                  className="flex-1 h-2 rounded-full appearance-none cursor-pointer bg-black/40 accent-accent"
                  style={{
                    background: `linear-gradient(to right, rgba(var(--accent),1) 0%, rgba(var(--accent),1) ${((uiScale - USER_SCALE_MIN) / (USER_SCALE_MAX - USER_SCALE_MIN)) * 100}%, rgba(255,255,255,0.08) ${((uiScale - USER_SCALE_MIN) / (USER_SCALE_MAX - USER_SCALE_MIN)) * 100}%, rgba(255,255,255,0.08) 100%)`,
                  }}
                />
                <i className="fa-solid fa-magnifying-glass-plus text-muted text-xs shrink-0"></i>
              </div>
            </div>

            {/* Font Size */}
            <div className="p-4 rounded-xl bg-black/20 border border-white/5">
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <i className="fa-solid fa-text-height text-accent text-xs"></i>
                  <span className="font-barlow text-primary font-medium">{t('ui.pages.options.font_size')}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="font-mono text-sm font-bold text-accent tabular-nums w-14 text-right">
                    {Math.round(fontScale * 100)}%
                  </span>
                  {Math.abs(fontScale - FONT_SCALE_DEFAULT) > 0.001 && (
                    <button
                      onClick={() => handleFontScaleChange(FONT_SCALE_DEFAULT)}
                      className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted hover:text-accent transition-colors"
                    >
                      {t('ui.pages.options.reset_default')}
                    </button>
                  )}
                </div>
              </div>
              <p className="text-[10px] font-barlow text-muted opacity-70 leading-relaxed mb-3">
                {t('ui.pages.options.font_size_desc')}
              </p>
              <div className="flex items-center gap-3">
                <span className="text-muted text-[10px] font-bold shrink-0">A</span>
                <input
                  type="range"
                  min={FONT_SCALE_MIN}
                  max={FONT_SCALE_MAX}
                  step={0.05}
                  value={fontScale}
                  onChange={(e) => handleFontScaleChange(parseFloat(e.target.value))}
                  className="flex-1 h-2 rounded-full appearance-none cursor-pointer bg-black/40 accent-accent"
                  style={{
                    background: `linear-gradient(to right, rgba(var(--accent),1) 0%, rgba(var(--accent),1) ${((fontScale - FONT_SCALE_MIN) / (FONT_SCALE_MAX - FONT_SCALE_MIN)) * 100}%, rgba(255,255,255,0.08) ${((fontScale - FONT_SCALE_MIN) / (FONT_SCALE_MAX - FONT_SCALE_MIN)) * 100}%, rgba(255,255,255,0.08) 100%)`,
                  }}
                />
                <span className="text-muted text-base font-bold shrink-0">A</span>
              </div>
            </div>

            {/* Font Picker */}
            <div className="p-4 rounded-xl bg-black/20 border border-white/5">
              <div className="flex items-center gap-2 mb-1">
                <i className="fa-solid fa-font text-accent text-xs"></i>
                <span className="font-barlow text-primary font-medium">{t('ui.pages.options.font')}</span>
              </div>
              <p className="text-[10px] font-barlow text-muted opacity-70 leading-relaxed mb-3">
                {t('ui.pages.options.font_desc')}
              </p>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {FONTS.map((f) => (
                  <button
                    key={f.id}
                    onClick={() => handleFontChange(f.id)}
                    style={{ fontFamily: f.stack }}
                    className={`flex flex-col items-start gap-0.5 px-3 py-2.5 rounded-xl cursor-pointer transition-all-smooth border-2 text-left ${font === f.id ? 'border-accent bg-accent/10' : 'border-white/5 bg-black/20 hover:border-white/20 hover:bg-white/5'}`}
                  >
                    <span className="text-sm font-semibold text-primary leading-tight">{f.name}</span>
                    <span className="text-[11px] text-muted leading-tight">Aa Bb Cc 123</span>
                  </button>
                ))}
              </div>
            </div>

            {OPTION_ITEMS.map((opt) => (
              <div
                key={opt.id}
                className="flex items-center justify-between p-4 rounded-xl bg-black/20 border border-white/5 hover:border-white/10 transition-all"
              >
                <span className="font-barlow text-primary font-medium">{t(opt.label)}</span>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    className="sr-only peer"
                    checked={!!options[opt.id]}
                    onChange={(e) => handleOptionChange(opt.id, e.target.checked)}
                  />
                  <div className="w-11 h-6 bg-black/40 border border-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent peer-checked:border-accent"></div>
                </label>
              </div>
            ))}

            <div className="mt-8 pt-4 space-y-4">
              <h3 className="text-[11px] font-rajdhani font-bold text-accent uppercase tracking-[0.2em] border-b border-white/5 pb-2">
                {t('ui.pages.options.overhead_data')}
              </h3>
              <div className="grid grid-cols-2 gap-4">
                {[
                  { id: 'OverheadName' as const, label: t('ui.pages.options.display_name') },
                  { id: 'OverheadId' as const, label: t('ui.pages.options.server_id') },
                  { id: 'OverheadHealth' as const, label: t('ui.pages.options.health_bar') },
                  { id: 'OverheadArmor' as const, label: t('ui.pages.options.armor_bar') },
                ].map((opt) => (
                  <div
                    key={opt.id}
                    className="flex items-center gap-3 p-4 rounded-xl bg-black/20 border border-white/5 hover:border-white/10 transition-all"
                  >
                    <label className="relative inline-flex items-center cursor-pointer shrink-0">
                      <input
                        type="checkbox"
                        className="sr-only peer"
                        checked={options[opt.id] !== false}
                        onChange={(e) => handleOptionChange(opt.id, e.target.checked)}
                      />
                      <div className="w-11 h-6 bg-black/40 border border-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent peer-checked:border-accent"></div>
                    </label>
                    <span className="font-barlow text-sm text-primary font-medium">{opt.label}</span>
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-2 gap-4 mt-2">
                <div className="flex flex-col gap-2 p-4 rounded-xl bg-black/20 border border-white/5">
                  <label className="text-[10px] font-rajdhani font-bold text-muted uppercase tracking-widest leading-none mb-1">
                    {t('ui.pages.options.overhead_style')}
                  </label>
                  <button
                    onClick={(e) => {
                      const position = dropdownPositionFrom(e.currentTarget);
                      setDropdown((prev) => {
                        if (prev && prev.id === 'overhead-style') return null;
                        return {
                          id: 'overhead-style',
                          name: 'Overhead Style',
                          options: [
                            {
                              Text: t('ui.pages.options.style_butter'),
                              Callback: () => handleOptionChange('OverheadStyle', 'Butter'),
                            },
                            {
                              Text: t('ui.pages.options.style_tx'),
                              Callback: () => handleOptionChange('OverheadStyle', 'TX'),
                            },
                          ],
                          position,
                          hasSearch: false,
                        };
                      });
                    }}
                    className="w-full bg-black/40 border border-white/5 hover:border-accent/50 rounded-xl px-3 py-2 text-[11px] text-primary font-bold tracking-wide flex items-center justify-between text-left focus:outline-none transition-colors"
                  >
                    <span>
                      {options.OverheadStyle === 'TX'
                        ? t('ui.pages.options.style_tx')
                        : t('ui.pages.options.style_butter')}
                    </span>
                    <i className="fa-solid fa-chevron-down text-[10px] text-muted"></i>
                  </button>
                </div>

                <div className="flex flex-col gap-2 p-4 rounded-xl bg-black/20 border border-white/5">
                  <label className="text-[10px] font-rajdhani font-bold text-muted uppercase tracking-widest leading-none mb-1">
                    {t('ui.pages.options.name_source')}
                  </label>
                  <button
                    onClick={(e) => {
                      const position = dropdownPositionFrom(e.currentTarget);
                      setDropdown((prev) => {
                        if (prev && prev.id === 'name-source') return null;
                        return {
                          id: 'name-source',
                          name: 'Name Source',
                          options: [
                            {
                              Text: t('ui.pages.options.name_source_player'),
                              Callback: () => handleOptionChange('NameSource', 'Player'),
                            },
                            {
                              Text: t('ui.pages.options.name_source_character'),
                              Callback: () => handleOptionChange('NameSource', 'Character'),
                            },
                          ],
                          position,
                          hasSearch: false,
                        };
                      });
                    }}
                    className="w-full bg-black/40 border border-white/5 hover:border-accent/50 rounded-xl px-3 py-2 text-[11px] text-primary font-bold tracking-wide flex items-center justify-between text-left focus:outline-none transition-colors"
                  >
                    <span>
                      {options.NameSource === 'Character'
                        ? t('ui.pages.options.name_source_character')
                        : t('ui.pages.options.name_source_player')}
                    </span>
                    <i className="fa-solid fa-chevron-down text-[10px] text-muted"></i>
                  </button>
                </div>
              </div>
            </div>

            <div className="mt-8 pt-4 space-y-4">
              <h3 className="text-[11px] font-rajdhani font-bold text-red-500 uppercase tracking-[0.2em] border-b border-white/5 pb-2">
                {t('ui.pages.options.global_reset')}
              </h3>
              <div className="flex flex-col gap-3 p-4 rounded-xl bg-red-500/5 border border-red-500/10 mt-4">
                <p className="text-[10px] font-barlow text-muted opacity-70 uppercase tracking-widest leading-relaxed">
                  {t('ui.pages.options.reset_note')}
                </p>
                <button
                  onClick={() => setShowResetConfirm(true)}
                  className="w-full bg-red-500/10 border border-red-500/20 hover:bg-red-500 hover:text-white rounded-xl py-3 text-xs text-red-400 font-rajdhani font-bold tracking-[0.1em] uppercase transition-all duration-300"
                >
                  {t('ui.pages.options.reset_btn')}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Custom Theme Editor Modal */}
      {customEditorOpen && (
        <CustomThemeEditor
          onClose={() => setCustomEditorOpen(false)}
          onApply={(themeId) => {
            setSavedCustomThemes(getSavedCustomThemes());
            setTheme(themeId);
            localStorage.setItem('adminMenuTheme', themeId);
          }}
        />
      )}

      {/* Reset Confirmation Modal */}
      {showResetConfirm && (
        <div className="absolute inset-0 bg-black/80 z-50 flex items-center justify-center p-6 transition-all duration-300">
          <div className="bg-bg-primary border border-red-500/40 rounded-2xl w-full max-w-md p-8 outline outline-1 outline-red-500/20">
            <div className="w-16 h-16 rounded-2xl bg-red-500/20 border border-red-500/30 flex items-center justify-center text-red-500 text-3xl mx-auto mb-6">
              <i className="fa-solid fa-triangle-exclamation"></i>
            </div>
            <h2 className="text-2xl font-rajdhani font-bold text-white tracking-wider uppercase mb-3 text-center leading-none">
              Reset Configuration
            </h2>
            <p className="text-white/70 text-center mb-8 font-barlow text-sm leading-relaxed">
              {t('ui.pages.options.reset_config_desc').split('Purge All Settings')[0]}
              <span className="text-red-400 font-mono bg-red-500/20 px-2 py-0.5 rounded border border-red-500/30 font-bold uppercase">
                Purge All Settings
              </span>
              {t('ui.pages.options.reset_config_desc').split('Purge All Settings')[1]}
            </p>

            <div className="flex gap-4">
              <button
                onClick={() => setShowResetConfirm(false)}
                className="flex-1 py-3 rounded-lg font-bold uppercase text-xs tracking-widest bg-white/5 hover:bg-white/10 text-white/60 hover:text-white border border-white/10 transition-all"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={handleResetMenu}
                className="flex-1 py-3 rounded-lg font-bold uppercase text-xs tracking-widest bg-red-600 hover:bg-red-500 text-white flex items-center justify-center gap-2 transition-all"
              >
                <i className="fa-solid fa-trash-can text-sm"></i>
                {t('ui.pages.options.confirm_reset')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OptionsPage;
