import React from 'react';
import ReactDOM from 'react-dom/client';
import { VisibilityProvider } from './providers/VisibilityProvider';
import { AdminMenuProvider } from './providers/AdminMenuContext';
import App from './components/App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <VisibilityProvider>
      <AdminMenuProvider>
        <App />
      </AdminMenuProvider>
    </VisibilityProvider>
  </React.StrictMode>,
);
