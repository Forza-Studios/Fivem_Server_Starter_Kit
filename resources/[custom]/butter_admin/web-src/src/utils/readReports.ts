const STORAGE_KEY = 'butter_admin_read_reports';

/** Fired on window whenever a report is marked as read. */
export const REPORTS_READ_EVENT = 'butter_admin:reportsRead';

/** Report ID -> number of messages seen. Null when storage is unavailable. */
export function getReadReports(): Record<string, number> | null {
  try {
    const parsed: unknown = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, number>) : {};
  } catch {
    return null;
  }
}

export function markReportRead(reportId: number, messageCount: number) {
  const readMap = getReadReports();
  if (!readMap) return;

  readMap[reportId] = messageCount;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(readMap));
  } catch {
    return;
  }
  window.dispatchEvent(new Event(REPORTS_READ_EVENT));
}
