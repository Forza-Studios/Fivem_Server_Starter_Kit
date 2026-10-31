import { debugLog } from './debug';

const resourceName = window.GetParentResourceName?.() ?? 'butter_admin';
const isEnvBrowser = !window.invokeNative;

/**
 * Calls a RegisterNUICallback handler on the client.
 * In a regular browser the mock handlers answer instead, falling back to `mockData`.
 * The mocks are loaded on demand, so they are never part of the in-game bundle.
 */
export async function fetchNui<T = unknown>(eventName: string, data?: unknown, mockData?: T): Promise<T> {
  debugLog('callback', eventName, data);

  if (isEnvBrowser) {
    const { handleMockNui } = await import('./mockNuiHandlers');
    const mocked = handleMockNui(eventName, data as Record<string, unknown> | undefined);
    return (mocked !== undefined ? mocked : (mockData ?? {})) as T;
  }

  const response = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data ?? {}),
  });
  const result = (await response.json()) as T;
  debugLog('callback result', eventName, result);
  return result;
}
