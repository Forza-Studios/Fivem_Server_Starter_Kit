import React, { useState, useEffect, useRef } from 'react';
import { AlertTriangle } from 'lucide-react';
import { fetchNui } from '../utils/fetchNui';
import { useResolutionScale } from '../hooks/useResolutionScale';

interface WarningOverlayProps {
  reason: string;
  adminName: string;
  onClose: () => void;
}

const WarningOverlay: React.FC<WarningOverlayProps> = ({ reason, adminName, onClose }) => {
  const [isHolding, setIsHolding] = useState(false);
  const [progress, setProgress] = useState(0); // 0 to 100
  const dynamicZoom = useResolutionScale();

  const timerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const intervalRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined);
  const startHoldingRef = useRef<() => void>(() => {});
  const stopHoldingRef = useRef<() => void>(() => {});

  // Stop Escape key propagation to prevent closing
  useEffect(() => {
    const preventEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopImmediatePropagation();
        e.preventDefault();
      }
    };
    window.addEventListener('keydown', preventEscape, true);
    return () => window.removeEventListener('keydown', preventEscape, true);
  }, []);

  const startHolding = () => {
    if (isHolding) return;
    setIsHolding(true);
    setProgress(0);

    const startTime = Date.now();
    const duration = 10000; // 10 seconds hold time

    intervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const pct = Math.min((elapsed / duration) * 100, 100);
      setProgress(pct);
    }, 30);

    timerRef.current = setTimeout(async () => {
      setIsHolding(false);
      setProgress(100);
      if (intervalRef.current) clearInterval(intervalRef.current);

      await fetchNui('dismissWarning').catch(() => {});

      onClose();
    }, duration);
  };

  const stopHolding = () => {
    setIsHolding(false);
    setProgress(0);
    if (timerRef.current) clearTimeout(timerRef.current);
    if (intervalRef.current) clearInterval(intervalRef.current);
  };

  // Sync refs to avoid stale closures in event listeners
  useEffect(() => {
    startHoldingRef.current = startHolding;
    stopHoldingRef.current = stopHolding;
  });

  // Spacebar hold keyboard listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space' || e.key === ' ') {
        e.preventDefault();
        if (e.repeat) return; // Prevent multiple triggers while holding
        startHoldingRef.current();
      }
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space' || e.key === ' ') {
        e.preventDefault();
        stopHoldingRef.current();
      }
    };

    const handleBlur = () => {
      stopHoldingRef.current();
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('blur', handleBlur);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      window.removeEventListener('blur', handleBlur);
    };
  }, []);

  // Calculate remaining seconds for hold feedback
  const remainingSeconds = Math.max(0, Math.ceil((10000 - progress * 100) / 1000));

  return (
    <div
      className="fixed inset-0 z-[9999] flex flex-col items-center justify-center select-none p-4"
      style={{ backgroundColor: 'rgba(178, 28, 28, 0.92)', zoom: dynamicZoom }}
    >
      {/* Main Dashed Warning Card */}
      <div
        className={`w-full max-w-lg py-10 px-12 bg-black/15 border-2 border-dashed rounded-2xl flex flex-col items-center transition-all duration-300 ${
          isHolding ? 'border-white scale-[1.01]' : 'border-white/80 '
        }`}
      >
        {/* Warning Icon and Label Header */}
        <div className="flex items-center justify-center gap-3 text-3.5xl font-black text-white tracking-[0.15em] uppercase font-sans drop-shadow-[0_2px_8px_rgba(0,0,0,0.5)]">
          <AlertTriangle
            className={`w-8 h-8 text-white fill-none stroke-[2.5] transition-transform duration-300 ${isHolding ? 'scale-110' : ''}`}
          />
          WARNING
          <AlertTriangle
            className={`w-8 h-8 text-white fill-none stroke-[2.5] transition-transform duration-300 ${isHolding ? 'scale-110' : ''}`}
          />
        </div>

        {/* Divider line */}
        <hr className="border-t border-white/30 my-5 w-full" />

        {/* Reason for warning */}
        <p className="text-4xl font-black text-white text-center break-words max-w-full my-4 tracking-wide leading-tight drop-shadow-[0_4px_12px_rgba(0,0,0,0.6)]">
          {reason || 'No Reason Specified'}
        </p>

        {/* Admin Name */}
        <p className="text-xs text-white/70 text-center font-normal tracking-wider mt-2 bg-black/10 px-3 py-1.5 rounded border border-white/5">
          Warned by: <span className="font-semibold text-white">{adminName || 'Administrator'}</span>
        </p>
      </div>

      {/* Instruction text below card */}
      <div className="mt-8 flex flex-col items-center">
        <p className="text-sm font-medium text-white/95 tracking-wide text-center">
          Hold
          <span
            className={`inline-block px-3 py-1 bg-white text-black font-extrabold rounded font-sans text-xs mx-1.5 border-b-4 border-neutral-300 transition-all duration-100 ${
              isHolding ? 'translate-y-[2px] border-b bg-neutral-100' : ' hover:bg-neutral-50'
            }`}
          >
            SPACE
          </span>
          for 10 seconds to dismiss this message.
        </p>

        {/* Interactive Hold Progress feedback */}
        <div className="h-10 mt-4 flex items-center justify-center">
          {isHolding ? (
            <div className="flex flex-col items-center animate-fade-in">
              <div className="w-[320px] h-2.5 bg-black/40 rounded-full overflow-hidden border border-white/10 relative">
                <div
                  className="h-full bg-gradient-to-r from-neutral-200 via-white to-neutral-200 transition-all ease-linear "
                  style={{ width: `${progress}%`, transitionDuration: '30ms' }}
                />
              </div>
              <span className="text-[10px] text-white font-black uppercase tracking-widest mt-2 bg-black/25 px-2.5 py-0.5 rounded animate-pulse">
                Holding Space ({remainingSeconds}s remaining)
              </span>
            </div>
          ) : (
            <span className="text-[10px] text-white/40 uppercase font-bold tracking-widest transition-opacity duration-300">
              Waiting for spacebar hold...
            </span>
          )}
        </div>
      </div>
    </div>
  );
};

export default WarningOverlay;
