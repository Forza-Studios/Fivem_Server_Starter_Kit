import React, { createContext, useContext, useState } from 'react';
import { useNuiEvent } from '../hooks/useNuiEvent';

interface VisibilityProviderValue {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

const VisibilityContext = createContext<VisibilityProviderValue | null>(null);

// Escape is handled by App, which also tells the client to release focus.
export const VisibilityProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [visible, setVisible] = useState(false);

  // Browser development helpers toggle visibility through this message.
  useNuiEvent<boolean>('setVisible', setVisible);

  return (
    <VisibilityContext.Provider value={{ visible, setVisible }}>
      <div style={{ visibility: visible ? 'visible' : 'hidden', height: '100%' }}>{children}</div>
    </VisibilityContext.Provider>
  );
};

export const useVisibility = () => {
  const context = useContext(VisibilityContext);
  if (!context) throw new Error('useVisibility must be used within VisibilityProvider');
  return context;
};
