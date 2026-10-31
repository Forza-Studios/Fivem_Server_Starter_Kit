import { isEnvBrowser } from './misc';

/**
 * Emulates NUI messages in the browser for development purposes.
 * @param events - An array of events to trigger
 * @param timer - Optional delay before triggering events
 */
export const debugData = <T = unknown>(events: { action: string; data: T }[], timer = 1000) => {
  if (isEnvBrowser()) {
    // Add a background image for browser development to see the menu clearly
    document.body.style.backgroundColor = '#1a1a1a';
    document.body.style.backgroundImage = 'url("https://picsum.photos/seed/gta5/1920/1080?blur=4")';
    document.body.style.backgroundSize = 'cover';
    document.body.style.backgroundPosition = 'center';
    document.body.style.backgroundRepeat = 'no-repeat';

    setTimeout(() => {
      for (const event of events) {
        window.dispatchEvent(
          new MessageEvent('message', {
            data: {
              action: event.action,
              data: event.data,
            },
          }),
        );
      }
    }, timer);
  }
};
