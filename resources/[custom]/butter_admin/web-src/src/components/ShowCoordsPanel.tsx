import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { useResolutionScale } from '../hooks/useResolutionScale';
import { useNuiEvent } from '../hooks/useNuiEvent';

interface ShowCoordsData {
  visible: boolean;
  vec3?: string;
  vec4?: string;
  heading?: string;
}

const ShowCoordsPanel: React.FC = () => {
  const [data, setData] = useState<ShowCoordsData>({ visible: false });
  const dynamicZoom = useResolutionScale();

  useNuiEvent<ShowCoordsData>('coordsUpdate', (payload) => setData(payload));

  if (!data.visible) return null;

  const panel = (
    <div
      className="fixed bottom-8 left-1/2 -translate-x-1/2 z-[99999] pointer-events-none"
      style={{ zoom: dynamicZoom }}
    >
      <div className="flex items-stretch bg-slate-950/80 border border-white/10 rounded-2xl p-1.5">
        <div className="flex items-center gap-3 px-4 py-2 border-r border-white/10">
          <div className="flex items-center justify-center w-8 h-8 rounded-full bg-accent/20 text-accent">
            <i className="fa-solid fa-location-crosshairs text-sm"></i>
          </div>
          <div className="flex flex-col justify-center">
            <span className="text-white font-rajdhani font-semibold text-lg tracking-wide leading-none">
              Coordinates
            </span>
          </div>
        </div>

        <div className="flex items-center gap-4 px-4 py-1">
          <div className="flex items-center gap-2">
            <span className="flex items-center justify-center min-w-[26px] h-[26px] px-1.5 bg-white/90 border-b-2 border-white/50 rounded-md text-slate-900 text-xs font-bold font-sans">
              E
            </span>
            <div className="flex flex-col justify-center px-4 py-2 bg-white/5 rounded-xl border border-white/5">
              <span className="text-white/90 font-mono text-xs font-medium tracking-tight">{data.vec3}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="flex items-center justify-center min-w-[26px] h-[26px] px-1.5 bg-white/90 border-b-2 border-white/50 rounded-md text-slate-900 text-xs font-bold font-sans">
              G
            </span>
            <div className="flex flex-col justify-center px-4 py-2 bg-white/5 rounded-xl border border-white/5">
              <span className="text-white/90 font-mono text-xs font-medium tracking-tight">{data.vec4}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="flex items-center justify-center min-w-[26px] h-[26px] px-1.5 bg-white/90 border-b-2 border-white/50 rounded-md text-slate-900 text-xs font-bold font-sans">
              H
            </span>
            <div className="flex flex-col justify-center px-4 py-2 bg-white/5 rounded-xl border border-white/5">
              <span className="text-white/90 font-mono text-xs font-medium tracking-tight">{data.heading}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  return ReactDOM.createPortal(panel, document.body);
};

export default ShowCoordsPanel;
