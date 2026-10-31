// UI side of Config.Debug.Debug: when the server enables debug output, NUI
// messages and callbacks are logged to the F8 / CEF console.
let debugEnabled = false;

export const setDebugEnabled = (enabled: boolean) => {
  debugEnabled = enabled;
};

export const debugLog = (...args: unknown[]) => {
  if (debugEnabled) console.debug('[butter_admin]', ...args);
};

window.addEventListener('message', (event: MessageEvent) => {
  const message = event.data;
  if (message && typeof message === 'object' && 'action' in message) {
    debugLog('message', message.action, message.data);
  }
});
