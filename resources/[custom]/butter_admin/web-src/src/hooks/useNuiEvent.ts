import { useEffect, useRef } from 'react';

interface NuiMessage<T> {
  action: string;
  data: T;
}

/**
 * Runs `handler` for every `{ action, data }` message the client sends with this action.
 * The latest handler is always used, so it may be an inline function.
 */
export const useNuiEvent = <T = unknown>(action: string, handler: (data: T) => void) => {
  const savedHandler = useRef(handler);

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const listener = (event: MessageEvent<NuiMessage<T>>) => {
      if (event.data && typeof event.data === 'object' && event.data.action === action) {
        savedHandler.current(event.data.data);
      }
    };

    window.addEventListener('message', listener);
    return () => window.removeEventListener('message', listener);
  }, [action]);
};
