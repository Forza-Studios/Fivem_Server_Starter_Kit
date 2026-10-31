import React from 'react';
import { Report } from '../../../../../types';

interface ReportClosingNotesProps {
  report: Report;
}

export const ReportClosingNotes: React.FC<ReportClosingNotesProps> = ({ report }) => {
  if (!report.ClosingNotes) return null;
  return (
    <div className="mb-4 bg-black/40 border border-border/50 rounded-lg p-3">
      <div className="flex items-center gap-2 mb-1">
        <i className="fa-solid fa-clipboard-check text-accent text-sm"></i>
        <span className="font-rajdhani font-semibold text-primary text-sm">
          Closing Notes (by {report.ClosedBy || 'System'})
        </span>
      </div>
      <p className="font-barlow text-sm text-muted">{report.ClosingNotes}</p>
    </div>
  );
};
