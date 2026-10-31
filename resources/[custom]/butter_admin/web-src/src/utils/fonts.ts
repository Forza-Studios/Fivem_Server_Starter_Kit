// Predefined fonts the admin can choose from for the whole menu UI.
// The `stack` is applied to the `--font-sans` CSS variable, which every
// font-* utility (sans / rajdhani / barlow) and the base body/headings resolve to.
// All families listed here are already loaded via the Google Fonts <link> in index.html.

export interface FontOption {
  id: string;
  name: string;
  stack: string;
  /** A short preview string rendered in the chosen font */
  sample?: string;
}

export const DEFAULT_FONT = 'Saira';

export const FONTS: FontOption[] = [
  { id: 'Saira', name: 'Saira', stack: "'Saira', 'Inter', sans-serif" },
  { id: 'Inter', name: 'Inter', stack: "'Inter', sans-serif" },
  { id: 'JetBrains Mono', name: 'JetBrains Mono', stack: "'JetBrains Mono', monospace" },
  { id: 'Roboto', name: 'Roboto', stack: "'Roboto', sans-serif" },
  { id: 'Rubik', name: 'Rubik', stack: "'Rubik', sans-serif" },
  { id: 'Poppins', name: 'Poppins', stack: "'Poppins', sans-serif" },
  { id: 'Nunito Sans', name: 'Nunito Sans', stack: "'Nunito Sans', sans-serif" },
  { id: 'Barlow', name: 'Barlow', stack: "'Barlow', sans-serif" },
  { id: 'Manrope', name: 'Manrope', stack: "'Manrope', sans-serif" },
  { id: 'Sora', name: 'Sora', stack: "'Sora', sans-serif" },
  { id: 'Outfit', name: 'Outfit', stack: "'Outfit', sans-serif" },
  { id: 'Space Grotesk', name: 'Space Grotesk', stack: "'Space Grotesk', sans-serif" },
  { id: 'IBM Plex Sans', name: 'IBM Plex Sans', stack: "'IBM Plex Sans', sans-serif" },
  { id: 'Titillium Web', name: 'Titillium Web', stack: "'Titillium Web', sans-serif" },
  { id: 'Exo 2', name: 'Exo 2', stack: "'Exo 2', sans-serif" },
  { id: 'Chakra Petch', name: 'Chakra Petch', stack: "'Chakra Petch', sans-serif" },
  { id: 'Oxanium', name: 'Oxanium', stack: "'Oxanium', sans-serif" },
  { id: 'Orbitron', name: 'Orbitron', stack: "'Orbitron', sans-serif" },
  { id: 'Fira Code', name: 'Fira Code', stack: "'Fira Code', monospace" },
  { id: 'Space Mono', name: 'Space Mono', stack: "'Space Mono', monospace" },
  { id: 'Rajdhani', name: 'Rajdhani', stack: "'Rajdhani', sans-serif" },
  { id: 'Lato', name: 'Lato', stack: "'Lato', sans-serif" },
];

export function getSavedFont(): string {
  return localStorage.getItem('adminMenuFont') || DEFAULT_FONT;
}

export function applyFont(fontId: string): void {
  const font = FONTS.find((f) => f.id === fontId) || FONTS[0];
  document.documentElement.style.setProperty('--font-sans', font.stack);
}

// A per-client multiplier exposed as the `--font-scale` CSS variable. The
// Tailwind fontSize scale (see tailwind.config.js) multiplies every text
// utility by it, so this scales TEXT ONLY, rem-based layout (padding, gap,
// widths) is untouched and the menu box keeps its size. Persisted to
// localStorage so each player keeps their own choice.

const FONT_SCALE_KEY = 'adminMenuFontScale';

export const FONT_SCALE_MIN = 0.8;
export const FONT_SCALE_MAX = 1.4;
export const FONT_SCALE_DEFAULT = 1.0;

function clampScale(value: number): number {
  return Math.min(FONT_SCALE_MAX, Math.max(FONT_SCALE_MIN, value));
}

export function getFontScale(): number {
  try {
    const raw = localStorage.getItem(FONT_SCALE_KEY);
    const parsed = raw != null ? parseFloat(raw) : NaN;
    if (Number.isFinite(parsed)) return clampScale(parsed);
  } catch {
    /* ignore storage errors */
  }
  return FONT_SCALE_DEFAULT;
}

export function applyFontScale(scale: number): void {
  document.documentElement.style.setProperty('--font-scale', String(clampScale(scale)));
}

export function setFontScale(scale: number): number {
  const applied = clampScale(scale);
  try {
    localStorage.setItem(FONT_SCALE_KEY, String(applied));
  } catch {
    /* ignore storage errors */
  }
  applyFontScale(applied);
  return applied;
}
