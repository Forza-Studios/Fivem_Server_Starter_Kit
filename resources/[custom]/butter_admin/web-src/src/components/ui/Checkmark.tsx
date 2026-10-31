import React from 'react';

interface CheckmarkProps {
  visible: boolean;
}

export const Checkmark: React.FC<CheckmarkProps> = ({ visible }) => {
  if (!visible) return null;
  return (
    <div className="absolute inset-0 z-[999] bg-black/50 flex items-center justify-center animate-in fade-in duration-300">
      <div className="flex flex-col items-center justify-center p-10 rounded-2xl bg-black/80 border border-accent/40 animate-in zoom-in-90 duration-300">
        <div className="w-24 h-24 rounded-2xl bg-accent/20 flex items-center justify-center border border-accent/50 mb-5 transform scale-0 animate-[popIn_0.5s_cubic-bezier(0.175,0.885,0.32,1.275)_0.1s_forwards]">
          <i className="fa-solid fa-check text-5xl text-accent transform scale-0 animate-[popIn_0.4s_cubic-bezier(0.175,0.885,0.32,1.275)_0.3s_forwards]"></i>
        </div>
        <h3 className="font-rajdhani font-bold text-2xl tracking-widest text-primary uppercase animate-in slide-in-from-bottom-2 fade-in duration-500 delay-300 fill-mode-both">
          Success
        </h3>
      </div>
    </div>
  );
};

export const Crossmark: React.FC<CheckmarkProps> = ({ visible }) => {
  if (!visible) return null;
  return (
    <div className="absolute inset-0 z-[999] bg-black/50 flex items-center justify-center animate-in fade-in duration-300">
      <div className="flex flex-col items-center justify-center p-10 rounded-2xl bg-black/80 border border-red-500/40 animate-in zoom-in-90 duration-300">
        <div className="w-24 h-24 rounded-2xl bg-red-500/20 flex items-center justify-center border border-red-500/50 mb-5 transform scale-0 animate-[popIn_0.5s_cubic-bezier(0.175,0.885,0.32,1.275)_0.1s_forwards]">
          <i className="fa-solid fa-xmark text-5xl text-red-500 transform scale-0 animate-[popIn_0.4s_cubic-bezier(0.175,0.885,0.32,1.275)_0.3s_forwards]"></i>
        </div>
        <h3 className="font-rajdhani font-bold text-2xl tracking-widest text-primary uppercase animate-in slide-in-from-bottom-2 fade-in duration-500 delay-300 fill-mode-both">
          Failed
        </h3>
      </div>
    </div>
  );
};
