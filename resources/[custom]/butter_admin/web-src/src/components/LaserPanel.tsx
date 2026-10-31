import React, { useState, useEffect, useCallback } from 'react';
import ReactDOM from 'react-dom';
import { fetchNui } from '../utils/fetchNui';
import { useResolutionScale } from '../hooks/useResolutionScale';
import { useNuiEvent } from '../hooks/useNuiEvent';

interface EntityInfo {
  type: 'Ped' | 'Vehicle' | 'Object';
  model: string | number;
  label: string;
  coords: { x: number; y: number; z: number };
  heading?: number;
  playerName?: string;
  serverId?: number;
  steamId?: string;
}

interface LaserPanelData {
  visible: boolean;
  entity?: EntityInfo;
  coords?: { x: number; y: number; z: number };
}

interface Action {
  id: string;
  label: string;
  danger?: boolean;
  highlight?: boolean;
}

const COMMON_ACTIONS: Action[] = [
  { id: 'delete', label: 'Delete Entity', danger: true },
  { id: 'explode', label: 'Explode Entity', danger: true },
  { id: 'burn', label: 'Burn Entity' },
  { id: 'freeze', label: 'Freeze Entity' },
  { id: 'teleport', label: 'Teleport To' },
];

const VEHICLE_ACTIONS: Action[] = [
  { id: 'warp', label: 'Warp Into' },
  { id: 'fix', label: 'Fix Vehicle', highlight: true },
  { id: 'flip', label: 'Flip Vehicle' },
  { id: 'engine', label: 'Toggle Engine' },
];

const PLAYER_ACTIONS: Action[] = [
  { id: 'revive', label: 'Revive Player', highlight: true },
  { id: 'kick', label: 'Kick Player', danger: true },
  { id: 'godmode', label: 'Toggle Godmode' },
  { id: 'freeze', label: 'Freeze' },
  { id: 'spectate', label: 'Spectate' },
  { id: 'tp_to', label: 'TP To Player' },
  { id: 'bring', label: 'Bring To Me' },
];

const ACTION_ICONS: Record<string, string> = {
  delete: 'fa-solid fa-trash-can',
  explode: 'fa-solid fa-bomb',
  burn: 'fa-solid fa-fire',
  freeze: 'fa-solid fa-snowflake',
  teleport: 'fa-solid fa-location-dot',
  warp: 'fa-solid fa-right-to-bracket',
  fix: 'fa-solid fa-wrench',
  flip: 'fa-solid fa-rotate',
  engine: 'fa-solid fa-gauge-high',
  revive: 'fa-solid fa-heart-pulse',
  heal: 'fa-solid fa-kit-medical',
  kick: 'fa-solid fa-user-xmark',
  godmode: 'fa-solid fa-shield-halved',
  spectate: 'fa-solid fa-eye',
  tp_to: 'fa-solid fa-angles-right',
  bring: 'fa-solid fa-angles-left',
};

function fmt(n: number) {
  return n.toFixed(2);
}
function coordsStr(c: { x: number; y: number; z: number }) {
  return `${fmt(c.x)}, ${fmt(c.y)}, ${fmt(c.z)}`;
}

function buildAllInfo(ent: EntityInfo, displayName: string | null | undefined) {
  const lines = [
    `Name: ${displayName ?? 'N/A'}`,
    `Type: ${ent.type}`,
    `Model: ${ent.model}`,
    `Coords: ${coordsStr(ent.coords)}`,
  ];
  if (ent.heading !== undefined) lines.push(`Heading: ${fmt(ent.heading)}`);
  if (ent.playerName) lines.push(`Player: ${ent.playerName}`);
  if (ent.serverId !== undefined) lines.push(`Server ID: ${ent.serverId}`);
  return lines.join('\n');
}

const LaserPanel: React.FC = () => {
  const [data, setData] = useState<LaserPanelData>({ visible: false });
  const [copied, setCopied] = useState<string | null>(null);
  const dynamicZoom = useResolutionScale();

  useNuiEvent<LaserPanelData>('laserUpdate', (payload) =>
    setData({ visible: !!payload.visible, entity: payload.entity ?? undefined, coords: payload.coords ?? undefined }),
  );

  useEffect(() => {
    if (!data.visible) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        fetchNui('laserClose');
      } else if (e.key.toLowerCase() === 'e') {
        e.preventDefault();
        fetchNui('laserUnlock');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [data.visible]);

  const copy = useCallback((text: string, field: string) => {
    fetchNui('laserCopy', { text });
    setCopied(field);
    setTimeout(() => setCopied(null), 1500);
  }, []);

  const doAction = useCallback((actionId: string) => {
    fetchNui('laserAction', { action: actionId });
  }, []);

  if (!data.visible) return null;

  const ent = data.entity;
  const isPlayer = ent?.type === 'Ped' && !!ent.playerName;
  const isVehicle = ent?.type === 'Vehicle';

  const actions: Action[] = [
    ...(isPlayer ? PLAYER_ACTIONS : []),
    ...(isVehicle ? VEHICLE_ACTIONS : []),
    ...COMMON_ACTIONS,
  ];

  const displayName = ent
    ? isPlayer
      ? ent.playerName
      : (ent.label || String(ent.model)).replace(/^[•\s\-\.\*]+/g, '')
    : null;
  const panel = (
    <>
      <style>{`
 @keyframes lp-slide-in {
 from { opacity:0; transform: translateY(-50%) translateX(24px); }
 to { opacity:1; transform: translateY(-50%) translateX(0); }
 }
 .lp-container {
 display: flex !important;
 flex-direction: column !important;
 background: rgba(22, 25, 32, 0.96) !important;
 border: 1px solid rgba(255, 255, 255, 0.08) !important;
 border-radius: 8px !important;
 font-family: 'Saira', 'Inter', sans-serif !important;
 overflow: hidden !important;
 width: 330px !important;
 user-select: none !important;
 }
 .lp-container.lp-selected {
 min-height: 580px !important;
 }
 .lp-selected .lp-actions-container {
 flex: 1 !important;
 background: #181b23 !important;
 }
 .lp-header {
 padding: 20px 16px 16px 16px !important;
 text-align: center !important;
 background: linear-gradient(to bottom, rgba(0, 0, 0, 0.25), rgba(0, 0, 0, 0.12)) !important;
 border-bottom: 1px solid rgba(255, 255, 255, 0.05) !important;
 }
 .lp-title {
 color: #38bdf8 !important;
 font-size: 17px !important;
 font-weight: 800 !important;
 letter-spacing: 0.05em !important;
 text-transform: uppercase !important;
 margin-bottom: 16px !important;
 display: flex !important;
 align-items: center !important;
 justify-content: center !important;
 gap: 6px !important;
 }
 .lp-buttons-row {
 display: flex !important;
 gap: 8px !important;
 justify-content: center !important;
 }
 .lp-buttons-row + .lp-buttons-row {
 margin-top: 8px !important;
 }
 .lp-btn-outline {
 flex: 1 !important;
 display: flex !important;
 align-items: center !important;
 justify-content: center !important;
 gap: 8px !important;
 background: transparent !important;
 border: 1px solid rgba(56, 189, 248, 0.2) !important;
 border-radius: 4px !important;
 color: #38bdf8 !important;
 font-size: 11px !important;
 font-weight: 700 !important;
 padding: 9px 12px !important;
 cursor: pointer !important;
 text-transform: uppercase !important;
 letter-spacing: 0.05em !important;
 transition: all 0.2s ease !important;
 }
 .lp-btn-outline:hover {
 background: rgba(56, 189, 248, 0.08) !important;
 border-color: rgba(56, 189, 248, 0.45) !important;
 }
 .lp-btn-outline:active {
 transform: scale(0.97) !important;
 }
 .lp-info-list {
 display: flex !important;
 flex-direction: column !important;
 gap: 10px !important;
 padding: 8px 16px 16px 16px !important;
 }
 .lp-info-row {
 display: flex !important;
 align-items: center !important;
 font-size: 11px !important;
 font-weight: 700 !important;
 color: #9ca3af !important;
 cursor: pointer !important;
 transition: color 0.15s ease !important;
 }
 .lp-info-row:hover {
 color: #ffffff !important;
 }
 .lp-info-row-icon {
 width: 16px !important;
 color: #6b7280 !important;
 font-size: 12px !important;
 margin-right: 8px !important;
 display: flex !important;
 align-items: center !important;
 justify-content: center !important;
 }
 .lp-info-row:hover .lp-info-row-icon {
 color: #9ca3af !important;
 }
 .lp-info-label {
 text-transform: uppercase !important;
 letter-spacing: 0.05em !important;
 }
 .lp-info-value {
 margin-left: auto !important;
 color: #e5e7eb !important;
 font-family: 'Saira', 'Inter', monospace !important;
 font-size: 12px !important;
 font-weight: 700 !important;
 }
 .lp-actions-container {
 border-top: 1px solid rgba(255, 255, 255, 0.06) !important;
 }
 .lp-action-row {
 display: flex !important;
 align-items: center !important;
 padding: 11px 16px !important;
 font-size: 13.5px !important;
 font-weight: 700 !important;
 color: #d1d5db !important;
 background: #181b23 !important;
 border-bottom: 1px solid rgba(255, 255, 255, 0.03) !important;
 cursor: pointer !important;
 transition: all 0.15s ease !important;
 position: relative !important;
 }
 .lp-action-row:last-child {
 border-bottom: none !important;
 }
 .lp-action-icon {
 width: 20px !important;
 font-size: 13.5px !important;
 margin-right: 12px !important;
 color: #6b7280 !important;
 display: flex !important;
 align-items: center !important;
 justify-content: center !important;
 transition: color 0.15s ease !important;
 }
 .lp-action-text {
 flex: 1 !important;
 }
 .lp-action-arrow {
 font-size: 10px !important;
 margin-left: auto !important;
 opacity: 0 !important;
 transform: translateX(-4px) !important;
 transition: all 0.15s ease !important;
 }
 /* Hovering Normal Items - NO LEFT STRIP */
 .lp-action-row:hover {
 background: #1e222d !important;
 color: #ffffff !important;
 }
 .lp-action-row:hover .lp-action-icon {
 color: #ffffff !important;
 }
 .lp-action-row:hover .lp-action-arrow {
 opacity: 0.5 !important;
 transform: translateX(0) !important;
 }
 /* Highlighted (like Fix Vehicle) */
 .lp-action-row.lp-highlight {
 color: #3b82f6 !important;
 }
 .lp-action-row.lp-highlight .lp-action-icon {
 color: #3b82f6 !important;
 }
 .lp-action-row.lp-highlight:hover {
 background: rgba(59, 130, 246, 0.08) !important;
 color: #3b82f6 !important;
 }
 .lp-action-row.lp-highlight:hover .lp-action-icon {
 color: #3b82f6 !important;
 }
 .lp-action-row.lp-highlight:hover .lp-action-arrow {
 color: #3b82f6 !important;
 }
 /* Danger (like Delete Entity, Explode Entity) */
 .lp-action-row.lp-danger {
 color: #f87171 !important;
 }
 .lp-action-row.lp-danger .lp-action-icon {
 color: #f87171 !important;
 }
 .lp-action-row.lp-danger:hover {
 background: rgba(239, 68, 68, 0.12) !important;
 color: #f87171 !important;
 }
 .lp-action-row.lp-danger:hover .lp-action-icon {
 color: #f87171 !important;
 }
 .lp-action-row.lp-danger:hover .lp-action-arrow {
 color: #f87171 !important;
 }
 .lp-footer {
 border-top: 1px solid rgba(255, 255, 255, 0.05) !important;
 padding: 10px 16px !important;
 font-size: 10px !important;
 color: #6b7280 !important;
 text-align: center !important;
 letter-spacing: 0.06em !important;
 background: #111319 !important;
 text-transform: uppercase !important;
 font-weight: 700 !important;
 }
 @keyframes lp-sweep {
 0% { top: 0%; opacity: 0; }
 10% { opacity: 0.15; }
 90% { opacity: 0.15; }
 100% { top: 100%; opacity: 0; }
 }
 `}</style>

      <div
        style={{
          position: 'fixed',
          top: '50%',
          right: 40,
          transform: 'translateY(-50%)',
          zIndex: 99999,
          pointerEvents: 'auto',
          animation: ent ? 'lp-slide-in 0.3s cubic-bezier(0.16, 1, 0.3, 1) both' : 'none',
          zoom: dynamicZoom,
        }}
      >
        <div className={`lp-container ${ent ? 'lp-selected' : 'lp-unselected'}`}>
          {ent && (
            <div className="lp-header">
              {/* Title Entity Header */}
              <div className="lp-title">{displayName}</div>

              <div className="lp-buttons-row">
                <button className="lp-btn-outline" onClick={() => copy(coordsStr(ent.coords), 'coords')}>
                  <i className="fa-solid fa-crosshairs"></i>
                  <span>{copied === 'coords' ? 'Copied!' : 'Copy Coords'}</span>
                </button>
                <button className="lp-btn-outline" onClick={() => copy(String(ent.model), 'model')}>
                  <i className="fa-solid fa-key"></i>
                  <span>{copied === 'model' ? 'Copied!' : 'Copy Model'}</span>
                </button>
              </div>
              <div className="lp-buttons-row">
                <button className="lp-btn-outline" onClick={() => displayName && copy(displayName, 'modelName')}>
                  <i className="fa-solid fa-tag"></i>
                  <span>{copied === 'modelName' ? 'Copied!' : 'Copy Name'}</span>
                </button>
                <button className="lp-btn-outline" onClick={() => copy(buildAllInfo(ent, displayName), 'all')}>
                  <i className="fa-solid fa-copy"></i>
                  <span>{copied === 'all' ? 'Copied!' : 'Copy All Info'}</span>
                </button>
              </div>
            </div>
          )}

          {ent && (
            <>
              <div className="lp-info-list">
                <div className="lp-info-row" onClick={() => copy(coordsStr(ent.coords), 'coords')}>
                  <i className="fa-solid fa-location-dot lp-info-row-icon"></i>
                  <span className="lp-info-label">Coords:</span>
                  <span className="lp-info-value">{copied === 'coords' ? 'COPIED' : coordsStr(ent.coords)}</span>
                </div>
                {ent.heading !== undefined && (
                  <div className="lp-info-row" onClick={() => copy(fmt(ent.heading ?? 0), 'heading')}>
                    <i className="fa-solid fa-compass lp-info-row-icon"></i>
                    <span className="lp-info-label">Heading:</span>
                    <span className="lp-info-value">{copied === 'heading' ? 'COPIED' : fmt(ent.heading ?? 0)}</span>
                  </div>
                )}
                <div className="lp-info-row" onClick={() => copy(String(ent.model), 'model')}>
                  <i className="fa-solid fa-cube lp-info-row-icon"></i>
                  <span className="lp-info-label">Model:</span>
                  <span className="lp-info-value">{copied === 'model' ? 'COPIED' : String(ent.model)}</span>
                </div>
              </div>

              <div className="lp-actions-container">
                {actions.map((action) => {
                  const icon = ACTION_ICONS[action.id] || 'fa-solid fa-circle-question';
                  const isHighlight = action.highlight;
                  const isDanger = action.danger;
                  let rowClass = 'lp-action-row';
                  if (isHighlight) rowClass += ' lp-highlight';
                  else if (isDanger) rowClass += ' lp-danger';

                  return (
                    <div key={action.id} className={rowClass} onClick={() => doAction(action.id)}>
                      <div className="lp-action-icon">
                        <i className={icon} />
                      </div>
                      <span className="lp-action-text">{action.label}</span>
                      <i className="fa-solid fa-chevron-right lp-action-arrow" />
                    </div>
                  );
                })}
              </div>
            </>
          )}

          {!ent && (
            /* No entity locked yet - Extremely simple and clean, no animations */
            <div
              style={{
                padding: '32px 24px',
                textAlign: 'center',
                fontSize: 13,
                color: 'rgba(255, 255, 255, 0.35)',
                position: 'relative',
                overflow: 'hidden',
              }}
            >
              <div style={{ fontSize: 34, marginBottom: 12, opacity: 0.5, color: 'rgba(255, 255, 255, 0.6)' }}>⊕</div>
              <div
                style={{
                  fontWeight: 700,
                  color: 'rgba(255, 255, 255, 0.8)',
                  fontSize: 14.5,
                  letterSpacing: '0.02em',
                  marginBottom: 4,
                }}
              >
                NO ENTITY DETECTED
              </div>
              {data.coords && (
                <div
                  style={{
                    fontWeight: 700,
                    color: 'rgba(56, 189, 248, 0.9)',
                    fontSize: 13.5,
                    letterSpacing: '0.02em',
                    marginBottom: 12,
                  }}
                >
                  {coordsStr(data.coords)}
                </div>
              )}
              <div style={{ opacity: 0.75, fontSize: 12.5 }}>Aim at a ped, vehicle, or object &amp; press **E**</div>
              <div style={{ marginTop: 12, fontSize: 11, opacity: 0.5, letterSpacing: '0.04em' }}>
                ESC TO QUIT SCANNERS
              </div>
            </div>
          )}

          {ent && <div className="lp-footer">Press E to deselect &nbsp;·&nbsp; ESC to close</div>}
        </div>
      </div>
    </>
  );

  return ReactDOM.createPortal(panel, document.body);
};

export default LaserPanel;
