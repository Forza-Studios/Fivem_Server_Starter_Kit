import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { useResolutionScale } from '../hooks/useResolutionScale';
import { useNuiEvent } from '../hooks/useNuiEvent';

interface TextUIData {
  visible: boolean;
  text?: string;
  icon?: string;
}

const GenericTextUIPanel: React.FC = () => {
  const [data, setData] = useState<TextUIData>({ visible: false });
  const dynamicZoom = useResolutionScale();

  useNuiEvent<TextUIData>('textUiUpdate', (payload) => setData(payload));

  if (!data.visible) return null;

  // Support multiline text by splitting on newlines or literal '\n'
  const processedText = data.text ? data.text.replace(/\\n/g, '\n') : '';
  const lines = processedText.split('\n');

  const panel = (
    <div
      style={{
        position: 'fixed',
        top: '50%',
        right: '24px',
        transform: 'translateY(-50%)',
        zIndex: 99998,
        pointerEvents: 'none',
        zoom: dynamicZoom,
        animation: 'slideInRightSpring 0.4s cubic-bezier(0.16, 1, 0.3, 1) both',
      }}
    >
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'auto 1fr',
          gap: '12px 16px',
          alignItems: 'center',
          background: 'rgba(15, 23, 42, 0.9)',
          border: '1px solid rgba(255, 255, 255, 0.05)',
          borderRadius: '8px',
          padding: '20px 24px',
          fontFamily: "var(--font-sans), 'Inter', sans-serif",
          minWidth: '240px',
        }}
      >
        {lines.map((line, idx) => {
          const trimmed = line.trim();
          const match = trimmed.match(/^\[(.*?)\](.*)$/);

          if (match) {
            return (
              <React.Fragment key={idx}>
                <div
                  style={{
                    background: 'rgba(255, 255, 255, 0.1)',
                    borderRadius: '4px',
                    padding: '4px 8px',
                    fontSize: '13px',
                    fontWeight: 700,
                    color: '#ffffff',
                    textAlign: 'center',
                    letterSpacing: '0.5px',
                  }}
                >
                  {match[1]}
                </div>
                <span
                  style={{
                    fontSize: '15px',
                    color: 'rgba(255, 255, 255, 0.85)',
                    fontWeight: 500,
                  }}
                >
                  {match[2].trim()}
                </span>
              </React.Fragment>
            );
          }

          return (
            <div
              key={idx}
              style={{
                gridColumn: '1 / -1',
                fontSize: '15px',
                fontWeight: 500,
                color: 'rgba(255, 255, 255, 0.9)',
                lineHeight: '1.4',
              }}
            >
              {trimmed}
            </div>
          );
        })}
      </div>
    </div>
  );

  return ReactDOM.createPortal(panel, document.body);
};

export default GenericTextUIPanel;
