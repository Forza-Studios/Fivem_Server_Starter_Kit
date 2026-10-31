import React from 'react';
import { motion } from 'motion/react';
import { useAdminMenu, useChats } from '../providers/AdminMenuContext';
import { useResolutionScale } from '../hooks/useResolutionScale';
import { getReadReports, REPORTS_READ_EVENT } from '../utils/readReports';

const ReportAlertOverlay: React.FC = () => {
  const { opened, pages } = useAdminMenu();
  const { reports } = useChats();
  const dynamicZoom = useResolutionScale();
  const [readTrigger, setReadTrigger] = React.useState(0);

  React.useEffect(() => {
    const handleUpdate = () => setReadTrigger((prev) => prev + 1);
    window.addEventListener(REPORTS_READ_EVENT, handleUpdate);
    return () => window.removeEventListener(REPORTS_READ_EVENT, handleUpdate);
  }, []);

  // Filter for reports that are active and have unread messages
  const unreadActiveReports = React.useMemo(() => {
    const active = reports.filter((r) => r.Status !== 'Closed');
    // Without storage nothing can be marked read, so every active report counts as unread.
    const readMap = getReadReports();
    if (!readMap) return active;

    return active.filter((report) => {
      const readCount = readMap[report.Id];
      return readCount === undefined || (report.Chats?.length ?? 0) > readCount;
    });
    // readTrigger re-reads storage after a report is marked read.
  }, [reports, readTrigger]);

  // Only show if the menu is closed, the user is authorized for reports, and there are unread active reports
  const showOverlay = !opened && pages['Reports'] === true && unreadActiveReports.length > 0;

  if (!showOverlay) return null;

  return (
    <div
      style={{ visibility: 'visible', zoom: dynamicZoom }}
      className="fixed top-8 right-8 z-[9999] pointer-events-none flex flex-col items-end select-none"
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.75 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.75 }}
        transition={{ duration: 0.25, ease: [0.34, 1.56, 0.64, 1] }}
        style={{ backgroundColor: 'rgb(var(--accent))' }}
        className="relative w-12 h-12 rounded-[14px] flex items-center justify-center border border-white/10"
      >
        {/* Support Team / Staff Shield Icon */}
        <i className="fa-solid fa-user-shield text-white text-[24px]"></i>

        {/* Circular Red Badge */}
        <span className="absolute -top-2.5 -right-2.5 bg-[#ff3b30] border-2 border-white/95 text-white font-extrabold text-[11px] w-[23px] h-[23px] rounded-full flex items-center justify-center">
          {unreadActiveReports.length}
        </span>
      </motion.div>
    </div>
  );
};

export default ReportAlertOverlay;
