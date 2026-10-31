import React, { useState, useEffect, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { useAdminMenu, toArray } from '../../../providers/AdminMenuContext';
import type { ScreenCaptureViewer } from '@screencapture/live';
import { fetchNui } from '../../../utils/fetchNui';
import { isEnvBrowser } from '../../../utils/misc';
import { SearchField } from '../../ui/SearchField';
import { cn } from '../../../utils/cn';

interface PlayerLocation {
  source: number;
  name: string;
  coords: { x: number; y: number; z: number };
  health: number;
  armor: number;
}

// Browser preview only; in-game the client answers.
const MOCK_LOCATIONS: PlayerLocation[] = [
  { source: 1, name: 'Youba Dev', coords: { x: 0, y: 0, z: 0 }, health: 100, armor: 50 },
  { source: 2, name: 'KasBer', coords: { x: 100, y: 100, z: 0 }, health: 200, armor: 100 },
];

const MonitoringPage: React.FC = () => {
  const { t } = useAdminMenu();
  const [players, setPlayers] = useState<PlayerLocation[]>([]);
  const [selectedPlayer, setSelectedPlayer] = useState<PlayerLocation | null>(null);
  const [activeStreams, setActiveStreams] = useState<ActiveStream[]>([]);
  const [streamError, setStreamError] = useState<string | null>(null);

  // Map Pan & Zoom State
  const [scale, setScale] = useState(0.8);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [playerSearch, setPlayerSearch] = useState('');

  const visiblePlayers = useMemo(() => {
    const query = playerSearch.toLowerCase();
    return players
      .filter((p) => !query || p.name.toLowerCase().includes(query) || String(p.source) === query)
      .sort((a, b) => a.source - b.source);
  }, [players, playerSearch]);

  // Blips sit at coords / 10 from the map centre, so this pans one into view.
  const focusPlayer = (player: PlayerLocation) => {
    setSelectedPlayer(player);
    setPosition({ x: (-player.coords.x / 10) * scale, y: (player.coords.y / 10) * scale });
  };

  const zoomBy = (factor: number) => setScale((current) => Math.max(0.5, Math.min(current * factor, 10)));

  // Positions change constantly and the map is only open while watched, so it polls.
  useEffect(() => {
    const fetchLocations = () => {
      fetchNui<PlayerLocation[]>('fetchPlayerLocations', {}, MOCK_LOCATIONS)
        .then((locations) => setPlayers(toArray(locations)))
        .catch(() => {});
    };

    fetchLocations();
    const interval = setInterval(fetchLocations, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleAction = (action: string, targetSource: number) => {
    fetchNui('monitoringAction', { action, target: targetSource }).catch(() => {});
  };

  const requestLiveStream = async (targetSource: number, playerName: string) => {
    // Avoid duplicates
    if (activeStreams.find((s) => s.playerSource === targetSource)) return;

    try {
      const data = await fetchNui<{ streamId: string; viewerToken: string; endpoint?: string } | false>(
        'requestLiveStream',
        { target: targetSource },
        false,
      );
      const endpoint = data ? data.endpoint : undefined;
      if (data && data.streamId && endpoint) {
        setActiveStreams((prev) => [
          ...prev,
          {
            id: data.streamId,
            streamId: data.streamId,
            viewerToken: data.viewerToken || 'mock-token',
            endpoint,
            playerName,
            playerSource: targetSource,
          },
        ]);
      } else if (isEnvBrowser()) {
        // Mock data for local browser preview only, never in-game.
        const mockId = 'mock-stream-' + Math.random().toString(36).substring(2, 10) + '-' + Date.now();
        setActiveStreams((prev) => [
          ...prev,
          {
            id: mockId,
            streamId: mockId,
            viewerToken: 'mock-token',
            endpoint: 'https://example.invalid/mock-stream',
            playerName,
            playerSource: targetSource,
          },
        ]);
      } else {
        setStreamError(t('ui.pages.monitoring.stream_not_configured'));
      }
    } catch {
      setStreamError(t('ui.pages.monitoring.stream_failed'));
    }
  };

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const zoomSensitivity = 0.1;
    const newScale = e.deltaY < 0 ? scale * (1 + zoomSensitivity) : scale * (1 - zoomSensitivity);
    setScale(Math.max(0.5, Math.min(newScale, 10))); // clamp between 0.5x and 10x
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    setIsDragging(true);
    setDragStart({ x: e.clientX - position.x, y: e.clientY - position.y });
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging) return;
    setPosition({ x: e.clientX - dragStart.x, y: e.clientY - dragStart.y });
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  return (
    <div className="flex h-full w-full bg-black/40 text-white relative">
      {streamError && (
        <div className="absolute top-3 left-1/2 -translate-x-1/2 z-50 bg-red-500/90 text-white text-xs font-bold px-4 py-2 rounded-lg flex items-center gap-3">
          <i className="fa-solid fa-triangle-exclamation"></i>
          {streamError}
          <button onClick={() => setStreamError(null)} className="text-white/80 hover:text-white">
            <i className="fa-solid fa-xmark"></i>
          </button>
        </div>
      )}
      <div className="absolute top-3 left-3 z-40 w-64 bg-black/80 border border-white/10 rounded-xl overflow-hidden flex flex-col max-h-[60%]">
        <div className="p-2 border-b border-white/10">
          <SearchField
            value={playerSearch}
            onChange={setPlayerSearch}
            placeholder={t('ui.pages.monitoring.search_players', String(players.length))}
          />
        </div>
        <div className="overflow-y-auto custom-scrollbar p-1">
          {visiblePlayers.map((p) => (
            <button
              key={p.source}
              onClick={() => focusPlayer(p)}
              className={cn(
                'w-full flex items-center gap-2 px-2 py-1.5 rounded-lg text-left text-xs transition-colors',
                selectedPlayer?.source === p.source ? 'bg-accent/20 text-white' : 'text-white/70 hover:bg-white/10',
              )}
            >
              <span className="font-mono text-[10px] text-white/40 w-7 shrink-0">#{p.source}</span>
              <span className="truncate flex-1">{p.name}</span>
              <span className="text-[10px] font-mono text-green-400/80">{p.health}</span>
            </button>
          ))}
          {visiblePlayers.length === 0 && (
            <p className="px-2 py-3 text-[11px] text-white/30 text-center">{t('ui.pages.monitoring.no_players')}</p>
          )}
        </div>
      </div>

      <div className="absolute bottom-3 left-3 z-40 flex flex-col bg-black/80 border border-white/10 rounded-xl overflow-hidden">
        <button onClick={() => zoomBy(1.25)} className="w-8 h-8 text-white/70 hover:text-white hover:bg-white/10">
          <i className="fa-solid fa-plus text-xs"></i>
        </button>
        <button onClick={() => zoomBy(0.8)} className="w-8 h-8 text-white/70 hover:text-white hover:bg-white/10">
          <i className="fa-solid fa-minus text-xs"></i>
        </button>
        <button
          onClick={() => {
            setScale(0.8);
            setPosition({ x: 0, y: 0 });
          }}
          title={t('ui.pages.monitoring.reset_view')}
          className="w-8 h-8 text-white/70 hover:text-white hover:bg-white/10 border-t border-white/10"
        >
          <i className="fa-solid fa-crosshairs text-xs"></i>
        </button>
      </div>

      {/* Main Map Area */}
      <div
        className="flex-1 relative overflow-hidden flex items-center justify-center cursor-grab active:cursor-grabbing"
        style={{ backgroundColor: '#1589bb' }} // exact match for the GTAV_ATLUS ocean color
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
      >
        {/* Map Transform Container */}
        <div
          className="absolute"
          style={{
            width: '4000px',
            height: '4000px',
            left: '50%',
            top: '50%',
            transform: `translate(calc(-50% + ${position.x}px), calc(-50% + ${position.y}px)) scale(${scale})`,
            transformOrigin: 'center center',
            transition: isDragging ? 'none' : 'transform 0.1s ease-out',
          }}
        >
          {/* GTA V Map Image Background */}
          <div
            className="absolute inset-0 opacity-80"
            style={{
              backgroundImage: 'url("https://www.bragitoff.com/wp-content/uploads/2015/11/GTAV_ATLUS_8192x8192.png")',
              backgroundSize: 'cover',
              backgroundPosition: 'center',
              backgroundRepeat: 'no-repeat',
            }}
          ></div>

          {/* Render Blips */}
          {players.map((p) => (
            <div
              key={p.source}
              className={cn(
                'absolute w-4 h-4 rounded-full cursor-pointer border border-white',
                selectedPlayer?.source === p.source ? 'bg-accent ring-4 ring-accent/40' : 'bg-red-500 hover:bg-red-400',
              )}
              style={{
                // Super basic mapping to center for mock purposes
                left: `calc(50% + ${p.coords.x / 10}px)`,
                top: `calc(50% - ${p.coords.y / 10}px)`,
                transform: 'translate(-50%, -50%)',
                // Keep blips relatively same size when zooming
                transformOrigin: 'center',
              }}
              onClick={(e) => {
                e.stopPropagation(); // prevent dragging map when clicking player
                setSelectedPlayer(p);
              }}
            >
              <span
                className="absolute top-5 left-1/2 -translate-x-1/2 bg-black/80 px-1 py-0.5 rounded whitespace-nowrap"
                style={{ fontSize: `${Math.max(8, 12 / scale)}px` }}
              >
                [{p.source}] {p.name}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Action Panel Sidebar */}
      {selectedPlayer && (
        <div className="w-80 bg-black/60 border-l border-white/10 flex flex-col h-full shrink-0">
          <div className="p-4 border-b border-white/10 flex justify-between items-center">
            <h2 className="font-rajdhani font-bold text-xl">{selectedPlayer.name}</h2>
            <button onClick={() => setSelectedPlayer(null)} className="text-white/50 hover:text-white">
              <i className="fa-solid fa-times"></i>
            </button>
          </div>

          <div className="p-4 space-y-4">
            <div className="bg-white/5 rounded p-3 text-sm">
              <div className="flex justify-between mb-1">
                <span className="text-white/50">{t('ui.pages.monitoring.server_id')}</span>
                <span>{selectedPlayer.source}</span>
              </div>
              <div className="flex justify-between mb-1">
                <span className="text-white/50">{t('ui.pages.monitoring.health')}</span>
                <span className="text-green-400">{selectedPlayer.health}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-white/50">{t('ui.pages.monitoring.armor')}</span>
                <span className="text-blue-400">{selectedPlayer.armor}</span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => handleAction('bring', selectedPlayer.source)}
                className="bg-white/10 hover:bg-white/20 py-2 rounded font-rajdhani text-sm transition-colors"
              >
                <i className="fa-solid fa-arrow-down mr-2"></i> {t('ui.pages.monitoring.bring')}
              </button>
              <button
                onClick={() => handleAction('goto', selectedPlayer.source)}
                className="bg-white/10 hover:bg-white/20 py-2 rounded font-rajdhani text-sm transition-colors"
              >
                <i className="fa-solid fa-location-dot mr-2"></i> {t('ui.pages.monitoring.goto')}
              </button>
              <button
                onClick={() => handleAction('freeze', selectedPlayer.source)}
                className="bg-white/10 hover:bg-white/20 py-2 rounded font-rajdhani text-sm transition-colors"
              >
                <i className="fa-solid fa-snowflake mr-2"></i> {t('ui.pages.monitoring.freeze')}
              </button>
              <button
                onClick={() => handleAction('revive', selectedPlayer.source)}
                className="bg-white/10 hover:bg-white/20 py-2 rounded font-rajdhani text-sm transition-colors"
              >
                <i className="fa-solid fa-heart mr-2"></i> {t('ui.pages.monitoring.revive')}
              </button>
              <button
                onClick={() => requestLiveStream(selectedPlayer.source, selectedPlayer.name)}
                className="bg-accent/80 hover:bg-accent col-span-2 py-2 rounded font-rajdhani text-sm transition-colors mt-2"
              >
                <i className="fa-solid fa-desktop mr-2"></i> {t('ui.pages.monitoring.view_screen')}
              </button>
              <button
                onClick={() => handleAction('screenshot', selectedPlayer.source)}
                className="bg-white/10 hover:bg-white/20 col-span-2 py-2 rounded font-rajdhani text-sm transition-colors"
              >
                <i className="fa-solid fa-camera mr-2"></i> {t('ui.pages.monitoring.screenshot')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Picture-in-Picture Viewer Overlays (Rendered in Portal so they can be dragged anywhere) */}
      {typeof document !== 'undefined' &&
        ReactDOM.createPortal(
          <>
            {activeStreams.map((stream, idx) => (
              <DraggablePIP
                key={stream.id}
                stream={stream}
                index={idx}
                onClose={() => setActiveStreams((prev) => prev.filter((s) => s.id !== stream.id))}
              />
            ))}
          </>,
          document.body,
        )}
    </div>
  );
};

interface ActiveStream {
  id: string;
  streamId: string;
  viewerToken: string;
  endpoint: string;
  playerName: string;
  playerSource: number;
}

const DraggablePIP: React.FC<{ stream: ActiveStream; onClose: () => void; index: number }> = ({
  stream,
  onClose,
  index,
}) => {
  const [pos, setPos] = useState({ x: 20 + index * 40, y: 20 + index * 40 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragOffset, setDragOffset] = useState({ x: 0, y: 0 });

  const onMouseDown = (e: React.MouseEvent) => {
    setIsDragging(true);
    setDragOffset({ x: e.clientX - pos.x, y: e.clientY - pos.y });
  };

  useEffect(() => {
    const onMouseMove = (e: MouseEvent) => {
      if (isDragging) {
        setPos({ x: e.clientX - dragOffset.x, y: e.clientY - dragOffset.y });
      }
    };
    const onMouseUp = () => setIsDragging(false);

    if (isDragging) {
      window.addEventListener('mousemove', onMouseMove);
      window.addEventListener('mouseup', onMouseUp);
    }
    return () => {
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };
  }, [isDragging, dragOffset]);

  return (
    <div
      className="absolute w-[400px] bg-[#0f1115] border border-white/5 rounded-lg flex flex-col overflow-hidden z-[9999]"
      style={{ left: pos.x, top: pos.y }}
    >
      <div
        className="bg-[#15171c] px-3 py-2 flex justify-between items-center cursor-move border-b border-white/5 select-none"
        onMouseDown={onMouseDown}
      >
        <div className="flex items-center text-xs font-semibold text-white/80 uppercase font-rajdhani tracking-wider">
          <i className="fa-solid fa-desktop text-green-400 mr-2"></i>
          {stream.playerName}
        </div>
        <div className="flex items-center gap-3">
          <span className="text-white/30 text-[10px] font-mono">#{stream.playerSource}</span>
          <button onClick={onClose} className="text-white/40 hover:text-white transition-colors">
            <i className="fa-solid fa-times"></i>
          </button>
        </div>
      </div>
      <div className="bg-black relative aspect-video">
        <video
          id={`stream-${stream.streamId}`}
          className="w-full h-full object-contain"
          autoPlay
          playsInline
          muted
        ></video>
        <LiveStreamer
          streamId={stream.streamId}
          viewerToken={stream.viewerToken}
          endpoint={stream.endpoint}
          videoId={`stream-${stream.streamId}`}
        />
        <div className="absolute bottom-2 left-2 bg-black/80 px-2 py-1 rounded flex items-center text-[10px] font-bold text-white uppercase font-rajdhani">
          <i className="fa-solid fa-circle text-red-500 text-[6px] mr-1.5 animate-pulse"></i> LIVE
        </div>
      </div>
    </div>
  );
};

const LiveStreamer: React.FC<{ streamId: string; viewerToken: string; endpoint: string; videoId: string }> = ({
  streamId,
  viewerToken,
  endpoint,
  videoId,
}) => {
  useEffect(() => {
    let viewer: ScreenCaptureViewer | null = null;
    let isMounted = true;

    const startStream = async () => {
      try {
        // Browser preview streams have no backend to connect to.
        if (viewerToken === 'mock-token') return;

        const { ScreenCaptureViewer } = await import('@screencapture/live');

        if (!isMounted) return;

        viewer = new ScreenCaptureViewer({
          endpoint: endpoint,
          streamId: streamId,
          viewerToken: viewerToken,
        });

        await viewer.connect();
        const videoElement = document.getElementById(videoId) as HTMLVideoElement;
        if (videoElement) {
          await viewer.attach(videoElement);
          await viewer.setQuality('auto');
        }
      } catch {
        // The PIP stays open without video; the admin can close and retry.
      }
    };

    startStream();

    return () => {
      isMounted = false;
      viewer?.disconnect().catch(() => {});
    };
  }, [streamId, viewerToken, endpoint, videoId]);

  return null; // pure logic component for handling the stream attachment
};

export default MonitoringPage;
