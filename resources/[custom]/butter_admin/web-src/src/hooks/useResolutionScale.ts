import { useState, useEffect } from 'react';

/**
 * Baseline resolution the UI was originally designed for.
 * All zoom values are calculated relative to this.
 */
const BASELINE_WIDTH = 1920;
const BASELINE_HEIGHT = 1080;

/**
 * The "design zoom" that was hardcoded originally.
 * At 1920x1080 the zoom will be exactly this value.
 */
const DESIGN_ZOOM = 0.7;

/**
 * Clamp bounds for the *automatic* resolution zoom so it never goes
 * too small or too large before the user scale is applied.
 */
const MIN_ZOOM = 0.5;
const MAX_ZOOM = 1.4;

/**
 * User-controlled scale (set from the Options page). This is a multiplier
 * applied on top of the automatic resolution zoom, letting every player pick
 * their own menu size regardless of their screen resolution.
 */
const USER_SCALE_KEY = 'adminMenuUiScale';
export const USER_SCALE_MIN = 0.6;
export const USER_SCALE_MAX = 1.6;
export const USER_SCALE_DEFAULT = 1.0;

/**
 * Absolute clamp on the final zoom (auto * user) so extreme combinations
 * can never make the menu unusable.
 */
const ABS_MIN_ZOOM = 0.35;
const ABS_MAX_ZOOM = 2.2;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/**
 * Computes the automatic zoom factor for the current screen resolution.
 *
 * Strategy: scale proportionally to screen area relative to baseline,
 * using the geometric mean of the width and height ratios so that
 * neither axis alone dominates.
 *
 * At 1920×1080 → returns DESIGN_ZOOM (0.7)
 * At 2560×1440 → scales up proportionally
 * At 3840×2160 → scales up proportionally
 * At 1280×720 → scales down proportionally
 */
function computeAutoZoom(screenWidth: number, screenHeight: number): number {
  const wRatio = screenWidth / BASELINE_WIDTH;
  const hRatio = screenHeight / BASELINE_HEIGHT;

  // Geometric mean keeps aspect-ratio neutrality
  let scale = Math.sqrt(wRatio * hRatio);

  // Small-screen boost: prevent the UI from becoming too tiny on low-res displays
  if (screenWidth < 1280) {
    scale *= 1.08;
  }

  const zoom = DESIGN_ZOOM * scale;
  return clamp(zoom, MIN_ZOOM, MAX_ZOOM);
}

function loadUserScale(): number {
  if (typeof window === 'undefined') return USER_SCALE_DEFAULT;
  try {
    const raw = window.localStorage.getItem(USER_SCALE_KEY);
    const parsed = raw != null ? parseFloat(raw) : NaN;
    if (Number.isFinite(parsed)) return clamp(parsed, USER_SCALE_MIN, USER_SCALE_MAX);
  } catch {
    /* ignore storage errors */
  }
  return USER_SCALE_DEFAULT;
}

/** Current physical screen dimensions, falling back to the window size. */
function currentScreen(): [number, number] {
  if (typeof window === 'undefined') return [BASELINE_WIDTH, BASELINE_HEIGHT];
  return [window.screen.width || window.innerWidth, window.screen.height || window.innerHeight];
}

function computeFinalZoom(): number {
  const [w, h] = currentScreen();
  return clamp(computeAutoZoom(w, h) * _userScale, ABS_MIN_ZOOM, ABS_MAX_ZOOM);
}

/**
 * User scale multiplier and the resulting final zoom are kept at module level
 * so non-hook code (dropdown positioning, etc.) can read them synchronously.
 */
let _userScale: number = loadUserScale();
let _currentZoom: number = computeFinalZoom();

/** Subscribers notified whenever the zoom or user scale changes. */
const listeners = new Set<() => void>();

function subscribe(fn: () => void): () => void {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

function recompute(): void {
  _currentZoom = computeFinalZoom();
  listeners.forEach((fn) => fn());
}

if (typeof window !== 'undefined') {
  window.addEventListener('resize', recompute);
}

/**
 * Read the current zoom value without a React hook.
 * Use this in event handlers and utility functions that cannot call hooks.
 */
export function getCurrentZoom(): number {
  return _currentZoom;
}

/** The current user scale multiplier (independent of resolution). */
export function getUserScale(): number {
  return _userScale;
}

/**
 * Update the user scale multiplier. Persists to localStorage (per client, so
 * every player keeps their own size) and live-updates all mounted consumers.
 */
export function setUserScale(scale: number): number {
  _userScale = clamp(scale, USER_SCALE_MIN, USER_SCALE_MAX);
  try {
    window.localStorage.setItem(USER_SCALE_KEY, String(_userScale));
  } catch {
    /* ignore storage errors */
  }
  recompute();
  return _userScale;
}

/**
 * Hook that returns the dynamic zoom factor, updating on window resize and
 * whenever the user changes their scale preference.
 * Use this value wherever the UI previously used hardcoded `zoom: 0.7`.
 */
export function useResolutionScale(): number {
  const [zoom, setZoom] = useState<number>(() => _currentZoom);

  useEffect(() => {
    // Sync immediately in case the value changed before this effect ran.
    setZoom(_currentZoom);
    return subscribe(() => setZoom(_currentZoom));
  }, []);

  return zoom;
}

/**
 * Hook that returns just the user scale multiplier (independent of resolution),
 * updating live when the player changes it. Use this to size the menu container
 * so the whole box grows/shrinks with the content, not just the zoom.
 */
export function useUserScale(): number {
  const [scale, setScale] = useState<number>(() => _userScale);

  useEffect(() => {
    setScale(_userScale);
    return subscribe(() => setScale(_userScale));
  }, []);

  return scale;
}
