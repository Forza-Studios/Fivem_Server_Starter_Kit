import React from 'react';
import { useAdminMenu, useChats } from '../providers/AdminMenuContext';
import { isEnvBrowser } from '../utils/misc';
import { useResolutionScale } from '../hooks/useResolutionScale';
import { Report } from '../types';

const BUTTON_CLASS =
  'hover:opacity-90 text-white px-4 py-2 rounded-lg border border-white/10 font-rajdhani font-bold tracking-widest uppercase text-xs transition-all duration-300 transform hover:scale-105 active:scale-95 whitespace-nowrap text-left';

/** Sends a message to the UI the same way the client does. */
const sendUiMessage = (action: string, data: unknown) => {
  window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
};

/** Browser development helpers; renders nothing in-game. */
const DevOverlay: React.FC = () => {
  const { playerReportMode, setPlayerReportMode, updatePlayerReport, setActiveReport, setOpened, opened } =
    useAdminMenu();
  const { reports } = useChats();
  const [laserVisible, setLaserVisible] = React.useState(false);
  const [coordsVisible, setCoordsVisible] = React.useState(false);
  const [textUIVisible, setTextUIVisible] = React.useState(false);
  const dynamicZoom = useResolutionScale();

  if (!isEnvBrowser()) return null;

  const toggleLaser = () => {
    const nextState = !laserVisible;
    setLaserVisible(nextState);
    // The laser replaces the menu while it is open.
    setOpened(!nextState);
    sendUiMessage('laserUpdate', {
      visible: nextState,
      entity: nextState
        ? {
            type: 'Vehicle',
            model: 'elegy',
            label: 'Elegy RH8',
            coords: { x: 1440.93, y: -585.97, z: 29.97 },
            heading: 104.86,
          }
        : undefined,
    });
  };

  const toggleMenu = () => {
    const nextOpened = !opened;
    setOpened(nextOpened);
    sendUiMessage('setVisible', nextOpened);
  };

  const simulateReport = () => {
    const randomId = Math.floor(Math.random() * 900000) + 100000;
    const categories = ['Bug', 'Player', 'Staff', 'Question', 'Claim', 'Other'];
    const message = `Simulated active report ${randomId} for testing the top-right overlay panel!`;
    const newReport: Report = {
      Id: randomId,
      Type: categories[Math.floor(Math.random() * categories.length)],
      Status: 'Active',
      Priority: 'Urgent',
      OpenBy: 'Dev Tester',
      OpenById: Math.floor(Math.random() * 99) + 1,
      Description: message,
      Chats: [
        {
          Sender: 'Dev Tester',
          Message: message,
          Time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        },
      ],
    };
    sendUiMessage('updateChats', { Reports: [...reports, newReport] });
  };

  const toggleCoords = () => {
    const nextState = !coordsVisible;
    setCoordsVisible(nextState);
    sendUiMessage('coordsUpdate', {
      visible: nextState,
      vec3: 'vec3(-1045.23, -2750.81, 21.36)',
      vec4: 'vec4(-1045.23, -2750.81, 21.36, 185.00)',
    });
  };

  const toggleTextUi = () => {
    const nextState = !textUIVisible;
    setTextUIVisible(nextState);
    sendUiMessage('textUiUpdate', {
      visible: nextState,
      text: '[SCROLL] Adjust Distance \n[Q/E] Rotate \n[ENTER] Confirm \n[BACKSPACE] Cancel',
      icon: 'cube',
    });
  };

  return (
    <div className="fixed top-4 left-4 z-[9999] flex flex-col gap-2 pointer-events-auto" style={{ zoom: dynamicZoom }}>
      <button
        className={`bg-accent ${BUTTON_CLASS}`}
        onClick={() => {
          if (playerReportMode) return setPlayerReportMode(false);
          // The creation form shows when there is no active report.
          setActiveReport(null);
          setPlayerReportMode(true);
        }}
      >
        {playerReportMode ? 'Back to Admin Menu' : 'Open Report Menu'}
      </button>

      {!playerReportMode && (
        <button
          className={`bg-blue-600 ${BUTTON_CLASS}`}
          onClick={() =>
            import('../utils/mockData').then(({ MOCK_REPORTS }) => updatePlayerReport({ ReportData: MOCK_REPORTS[0] }))
          }
        >
          Open Active Chat
        </button>
      )}

      <button className={`bg-purple-600 ${BUTTON_CLASS}`} onClick={toggleLaser}>
        {laserVisible ? 'Close Laser Menu' : 'Open Laser Menu'}
      </button>

      <button className={`bg-yellow-600 ${BUTTON_CLASS}`} onClick={toggleMenu}>
        {opened ? 'Close Menu (Test Alert Overlay)' : 'Open Menu'}
      </button>

      <button className={`bg-emerald-600 ${BUTTON_CLASS}`} onClick={simulateReport}>
        Simulate New Report
      </button>

      <button className={`bg-indigo-600 ${BUTTON_CLASS}`} onClick={toggleCoords}>
        {coordsVisible ? 'Hide Coords Panel' : 'Show Coords Panel'}
      </button>

      <button className={`bg-rose-600 ${BUTTON_CLASS}`} onClick={toggleTextUi}>
        {textUIVisible ? 'Hide Generic Text UI' : 'Show Generic Text UI'}
      </button>
    </div>
  );
};

export default DevOverlay;
