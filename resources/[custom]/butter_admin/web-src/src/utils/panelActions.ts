import { fetchNui } from './fetchNui';

/** Runs one of the client's fixed panel actions (PANEL_ACTIONS in modules/menu/client.lua). */
export const runPanelAction = (action: string, data?: Record<string, unknown>) => {
  fetchNui('runAction', { action, data }).catch(() => {});
};
