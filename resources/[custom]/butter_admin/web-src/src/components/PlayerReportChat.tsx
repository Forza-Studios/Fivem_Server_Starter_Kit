import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useAdminMenu, useChats } from '../providers/AdminMenuContext';
import { fetchNui } from '../utils/fetchNui';
import { openExternalUrl } from '../utils/misc';
import { markReportRead } from '../utils/readReports';
import { MediaModal } from './ui/MediaModal';
import { renderChatMessageContent } from './ui/ChatMessageContent';

const CATEGORIES = [
  {
    id: 'Bug',
    label: 'Bug Report',
    icon: 'fa-bug',
    color: 'text-red-400',
    bg: 'bg-red-400/20',
    border: 'border-red-500/20',
  },
  {
    id: 'Player',
    label: 'Report Player',
    icon: 'fa-user-slash',
    color: 'text-blue-400',
    bg: 'bg-blue-400/20',
    border: 'border-blue-500/20',
  },
  {
    id: 'Staff',
    label: 'Report Staff',
    icon: 'fa-shield-halved',
    color: 'text-amber-400',
    bg: 'bg-amber-400/20',
    border: 'border-amber-500/20',
  },
  {
    id: 'Question',
    label: 'Question',
    icon: 'fa-circle-question',
    color: 'text-emerald-400',
    bg: 'bg-emerald-400/20',
    border: 'border-emerald-500/20',
  },
  {
    id: 'Claim',
    label: 'Claim System',
    icon: 'fa-suitcase-rolling',
    color: 'text-cyan-400',
    bg: 'bg-cyan-400/20',
    border: 'border-cyan-500/20',
  },
  {
    id: 'Other',
    label: 'Other',
    icon: 'fa-ellipsis',
    color: 'text-purple-400',
    bg: 'bg-purple-400/20',
    border: 'border-purple-500/20',
  },
];

const PlayerReportChat: React.FC = () => {
  const { myName, closeMenu, showCheckmark, t } = useAdminMenu();
  const { activeReport } = useChats();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const [reportInput, setReportInput] = useState('');
  const [creationData, setCreationData] = useState({
    category: '',
    title: '',
    description: '',
    clips: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const chatScrollRef = useRef<HTMLDivElement>(null);

  const handleOpenMedia = (url: string) => {
    const isImage = /\.(jpg|jpeg|png|webp|gif)(\?.*)?$/i.test(url);
    const isClip =
      url.includes('medal.tv') ||
      url.includes('streamable.com') ||
      url.includes('youtube.com') ||
      url.includes('youtu.be') ||
      /\.(mp4|webm|ogg)$/i.test(url);

    if (isImage || isClip) {
      setPreviewUrl(url);
    } else {
      openExternalUrl(url);
    }
  };

  useEffect(() => {
    if (chatScrollRef.current) {
      chatScrollRef.current.scrollTop = chatScrollRef.current.scrollHeight;
    }
  }, [activeReport?.Chats]);

  const activeReportId = activeReport?.Id;
  const activeMessageCount = activeReport?.Chats?.length ?? 0;
  useEffect(() => {
    if (activeReportId !== undefined) markReportRead(activeReportId, activeMessageCount);
  }, [activeReportId, activeMessageCount]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    if (dropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [dropdownOpen]);

  const renderMessageContent = (message: string) => renderChatMessageContent(message, { onOpenMedia: handleOpenMedia });

  const handleSend = () => {
    if (!reportInput.trim() || !activeReport) return;
    fetchNui('sendPlayerReportMessage', { message: reportInput }).catch(() => {});
    setReportInput('');
  };

  const handleCreateReport = async () => {
    if (!creationData.description.trim() || !creationData.title.trim() || !creationData.category || isSubmitting)
      return;
    setIsSubmitting(true);

    const formattedData = {
      ...creationData,
      clips: creationData.clips.trim(),
    };

    // The server answers by opening the new report, or with a notification when it refuses.
    await fetchNui('createReport', formattedData).catch(() => {});
    showCheckmark();
    setIsSubmitting(false);
  };

  // ── Creation Form ──
  if (!activeReport) {
    return (
      <div
        className="flex flex-col h-full w-full bg-[#111827] rounded-xl overflow-hidden"
        style={{ fontFamily: "'Inter', sans-serif" }}
      >
        {/* Header */}
        <div className="flex justify-between items-center px-6 py-5 border-b border-white/[0.06]">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-blue-600/20 flex items-center justify-center">
              <i className="fa-solid fa-headset text-blue-400 text-base"></i>
            </div>
            <div>
              <h2 className="text-[20px] font-semibold text-white tracking-tight">
                {t('ui.pages.reports.new_report')}
              </h2>
            </div>
          </div>
          <button
            className="w-8 h-8 rounded-lg text-gray-500 hover:text-white hover:bg-white/[0.06] flex items-center justify-center transition-colors"
            onClick={closeMenu}
          >
            <i className="fa-solid fa-xmark text-sm"></i>
          </button>
        </div>

        {/* Form Body */}
        <div className="flex-1 overflow-y-auto px-6 py-5 custom-scrollbar">
          {/* Category */}
          <div className="mb-6 relative" ref={dropdownRef}>
            <label className="block text-[11px] font-medium text-gray-400 uppercase tracking-wider mb-3">
              {t('ui.pages.reports.category')}
            </label>
            <div className="relative">
              <button
                type="button"
                onClick={() => setDropdownOpen(!dropdownOpen)}
                className={`w-full flex items-center justify-between px-4 py-3 rounded-lg bg-white/[0.03] border transition-all duration-200 ${
                  dropdownOpen ? 'border-blue-500/50 bg-white/[0.06]' : 'border-white/[0.06] hover:bg-white/[0.05]'
                }`}
              >
                <div className="flex items-center gap-3">
                  {creationData.category ? (
                    (() => {
                      const cat = CATEGORIES.find((c) => c.id === creationData.category);
                      return (
                        <>
                          <i className={`fa-solid ${cat?.icon} ${cat?.color} text-sm w-5 text-center`}></i>
                          <span className="text-[13px] text-white font-medium">
                            {t('ui.pages.reports.categories.' + cat?.id.toLowerCase())}
                          </span>
                        </>
                      );
                    })()
                  ) : (
                    <>
                      <i className="fa-solid fa-list-ul text-gray-500 text-sm w-5 text-center"></i>
                      <span className="text-[13px] text-gray-400">{t('ui.pages.reports.select_category')}</span>
                    </>
                  )}
                </div>
                <i
                  className={`fa-solid fa-chevron-down text-[10px] text-gray-500 transition-transform duration-200 ${dropdownOpen ? 'rotate-180' : ''}`}
                ></i>
              </button>

              <AnimatePresence>
                {dropdownOpen && (
                  <motion.div
                    initial={{ opacity: 0, y: -10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: -10, scale: 0.95 }}
                    transition={{ duration: 0.15, ease: 'easeOut' }}
                    className="absolute top-full left-0 right-0 mt-2 z-50 bg-[#1a2133] border border-white/[0.08] rounded-xl overflow-hidden"
                  >
                    <div className="p-1.5 flex flex-col gap-1">
                      {CATEGORIES.map((cat) => (
                        <button
                          key={cat.id}
                          onClick={() => {
                            setCreationData((prev) => ({ ...prev, category: cat.id }));
                            setDropdownOpen(false);
                          }}
                          className={`flex items-center gap-3 w-full px-3 py-2.5 rounded-lg transition-all duration-150 ${
                            creationData.category === cat.id
                              ? `${cat.bg} ${cat.color}`
                              : 'text-gray-400 hover:bg-white/[0.04] hover:text-gray-200'
                          }`}
                        >
                          <i
                            className={`fa-solid ${cat.icon} ${creationData.category === cat.id ? cat.color : 'text-current'} text-sm w-5 text-center`}
                          ></i>
                          <span className="text-[13px] font-medium">
                            {t('ui.pages.reports.categories.' + cat.id.toLowerCase())}
                          </span>
                          {creationData.category === cat.id && (
                            <motion.i
                              initial={{ opacity: 0, scale: 0.5 }}
                              animate={{ opacity: 1, scale: 1 }}
                              className="fa-solid fa-check text-[10px] ml-auto"
                            ></motion.i>
                          )}
                        </button>
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>

          {/* Title */}
          <div className="mb-6">
            <label className="block text-[11px] font-medium text-gray-400 uppercase tracking-wider mb-3">
              {t('ui.pages.reports.report_subject')}
            </label>
            <input
              type="text"
              className="w-full bg-white/[0.03] border border-white/[0.06] rounded-lg py-3 px-4 text-white text-[13px] focus:outline-none focus:border-blue-500/40 transition-colors placeholder:text-gray-600"
              placeholder={t('ui.pages.reports.subject_placeholder')}
              value={creationData.title}
              onChange={(e) => setCreationData((prev) => ({ ...prev, title: e.target.value }))}
            />
          </div>

          {/* Description */}
          <div className="mb-6">
            <label className="block text-[11px] font-medium text-gray-400 uppercase tracking-wider mb-3">
              {t('ui.pages.reports.description')}
            </label>
            <textarea
              className="w-full bg-white/[0.03] border border-white/[0.06] rounded-lg p-4 text-white text-[13px] min-h-[100px] focus:outline-none focus:border-blue-500/40 transition-colors resize-none placeholder:text-gray-600"
              placeholder={t('ui.pages.reports.describe_placeholder')}
              value={creationData.description}
              onChange={(e) => setCreationData((prev) => ({ ...prev, description: e.target.value }))}
            />
          </div>

          {/* Evidence Link */}
          <div>
            <label className="block text-[11px] font-medium text-gray-400 uppercase tracking-wider mb-3">
              {t('ui.pages.reports.evidence_link')}
            </label>
            <div className="relative">
              <i className="fa-solid fa-link absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-600 text-xs"></i>
              <input
                type="text"
                className="w-full bg-white/[0.03] border border-white/[0.06] rounded-lg py-3 pl-9 pr-4 text-white text-[13px] focus:outline-none focus:border-blue-500/40 transition-colors placeholder:text-gray-600"
                placeholder={t('ui.pages.reports.evidence_placeholder')}
                value={creationData.clips}
                onChange={(e) => setCreationData((prev) => ({ ...prev, clips: e.target.value }))}
              />
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-white/[0.06] flex justify-between items-center">
          <div className="flex items-center gap-1.5">
            <span className="text-[11px] text-gray-600">{t('ui.pages.reports.signed_in_as')}</span>
            <span className="text-[11px] font-semibold text-gray-400">{myName}</span>
          </div>
          <div className="flex gap-2.5">
            <button
              className="px-4 py-2 rounded-lg text-[12px] font-medium text-gray-400 hover:text-white transition-colors bg-white/[0.04] border border-white/[0.06] hover:bg-white/[0.08]"
              onClick={closeMenu}
            >
              {t('common.cancel')}
            </button>
            <button
              className={`px-5 py-2 rounded-lg text-[12px] font-semibold transition-all flex items-center gap-2 ${
                creationData.description.trim() && creationData.title.trim() && creationData.category
                  ? 'bg-blue-600 text-white hover:bg-blue-500 active:scale-[0.98]'
                  : 'bg-white/[0.04] text-gray-600 cursor-not-allowed'
              }`}
              disabled={
                !creationData.description.trim() || !creationData.title.trim() || !creationData.category || isSubmitting
              }
              onClick={handleCreateReport}
            >
              {isSubmitting ? (
                <i className="fa-solid fa-circle-notch fa-spin"></i>
              ) : (
                <>
                  {t('ui.pages.reports.submit_report')} <i className="fa-solid fa-paper-plane text-[10px]"></i>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── Active Report Chat ──
  const typingNames = activeReport.TypingAdmins?.filter((name) => name !== myName) || [];

  return (
    <div
      className="flex flex-col h-full w-full bg-[#111827] rounded-xl overflow-hidden"
      style={{ fontFamily: "'Inter', sans-serif" }}
    >
      {/* Header */}
      <div className="flex justify-between items-center px-6 py-4 border-b border-white/[0.06]">
        <div className="flex items-center gap-3">
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors duration-300 ${
              activeReport.Status === 'Closed'
                ? 'bg-red-500/15 text-red-400'
                : (() => {
                    const cat = CATEGORIES.find((c) => c.id === activeReport.Type);
                    return cat ? `${cat.bg} ${cat.color}` : 'bg-blue-600/20 text-blue-400';
                  })()
            }`}
          >
            <i
              className={`fa-solid ${
                activeReport.Status === 'Closed'
                  ? 'fa-lock'
                  : CATEGORIES.find((c) => c.id === activeReport.Type)?.icon || 'fa-headset'
              } text-base`}
            ></i>
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className={`text-[15px] font-semibold text-white tracking-tight`}>
                <span
                  className={
                    activeReport.Status !== 'Closed'
                      ? CATEGORIES.find((c) => c.id === activeReport.Type)?.color || ''
                      : ''
                  }
                >
                  {activeReport.Title || activeReport.Type || t('ui.pages.reports.report_fallback')}
                </span>{' '}
                #{activeReport.Id}
              </h2>
              <span
                className={`text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full ${
                  activeReport.Status === 'Closed' ? 'bg-red-500/15 text-red-400' : 'bg-emerald-500/15 text-emerald-400'
                }`}
              >
                {activeReport.Status === 'Active'
                  ? t('ui.pages.reports.status_open')
                  : t('ui.pages.reports.status_closed')}
              </span>
            </div>
            <p className="text-[11px] text-gray-500 mt-0.5">
              {activeReport.ClaimedBy
                ? t('ui.pages.reports.assigned_to', activeReport.ClaimedByName || 'Staff')
                : t('ui.pages.reports.waiting_for_staff')}
            </p>
          </div>
        </div>
        <button
          className="w-8 h-8 rounded-lg text-gray-500 hover:text-white hover:bg-white/[0.06] flex items-center justify-center transition-colors"
          onClick={closeMenu}
        >
          <i className="fa-solid fa-xmark text-sm"></i>
        </button>
      </div>

      {/* Chat Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-5 custom-scrollbar flex flex-col gap-4" ref={chatScrollRef}>
        {/* Initial Statement Card */}
        <div className="bg-white/[0.03] border border-white/[0.06] rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <i className="fa-solid fa-quote-left text-[10px] text-blue-400"></i>
            <span className="text-[11px] font-semibold text-blue-400 uppercase tracking-wide">
              {activeReport.Title || t('ui.pages.reports.your_report')}
            </span>
          </div>
          <p className="text-[13px] text-gray-300 leading-relaxed italic opacity-80 mb-2 border-b border-white/5 pb-2">
            {t('ui.pages.reports.category_label', activeReport.Type || t('ui.pages.reports.general'))}
          </p>
          <p className="text-[13px] text-gray-300 leading-relaxed">
            {activeReport.Description || activeReport.Chats?.[0]?.Message}
          </p>
          {activeReport.Clips && activeReport.Clips !== 'None' && (
            <button
              onClick={() => handleOpenMedia(activeReport.Clips!)}
              className="inline-flex items-center gap-1.5 mt-3 text-[11px] text-blue-400 hover:text-blue-300 font-medium transition-colors"
            >
              <i className="fa-solid fa-paperclip text-[10px]"></i> {t('ui.pages.reports.view_attachment')}
            </button>
          )}
        </div>

        {/* Messages */}
        {(activeReport.Chats || []).slice(1).map((chat, idx) => {
          const isMe = chat.Sender === myName;
          const initial = chat.Sender ? chat.Sender.charAt(0).toUpperCase() : '?';
          return (
            <div key={idx} className={`flex w-full ${isMe ? 'justify-end' : 'justify-start'}`}>
              <div className={`flex max-w-[80%] gap-2.5 ${isMe ? 'flex-row-reverse' : 'flex-row'}`}>
                <div className="flex-shrink-0 mt-auto mb-1">
                  <div
                    className={`w-7 h-7 rounded-full flex items-center justify-center text-[11px] font-semibold ${
                      isMe ? 'bg-blue-600/25 text-blue-400' : 'bg-white/[0.06] text-gray-400'
                    }`}
                  >
                    {initial}
                  </div>
                </div>
                <div className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}>
                  <div className="flex items-baseline gap-2 mb-1 mx-0.5">
                    <span className="text-[11px] font-medium text-gray-400">{chat.Sender}</span>
                    <span className="text-[10px] text-gray-600">{chat.Time}</span>
                  </div>
                  <div
                    className={`px-3.5 py-2.5 ${
                      isMe
                        ? 'bg-blue-600 text-white rounded-xl rounded-br-sm'
                        : 'bg-white/[0.05] text-gray-200 rounded-xl rounded-bl-sm'
                    }`}
                  >
                    <div className="text-[13px] leading-relaxed break-words whitespace-pre-wrap">
                      {renderMessageContent(chat.Message)}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          );
        })}

        {/* No messages placeholder */}
        {(activeReport.Chats || []).length <= 1 && (
          <div className="flex-1 flex flex-col items-center justify-center text-gray-600 py-10">
            <i className="fa-regular fa-comments text-2xl mb-2"></i>
            <span className="text-[12px]">{t('ui.pages.reports.no_messages_yet')}</span>
          </div>
        )}
      </div>

      {/* Input / Closed State */}
      {activeReport.Status !== 'Closed' ? (
        <div className="px-6 py-4 border-t border-white/[0.06]">
          {typingNames.length > 0 && (
            <div className="mb-2 flex items-center gap-1.5">
              <div className="w-1.5 h-1.5 rounded-full bg-blue-400 animate-pulse"></div>
              <span className="text-[11px] text-blue-400 font-medium">
                {t('ui.pages.reports.is_typing', typingNames[0])}
              </span>
            </div>
          )}
          <div className="relative flex items-center">
            <input
              className="w-full bg-white/[0.03] border border-white/[0.06] rounded-lg py-3 pl-4 pr-12 text-white text-[13px] focus:outline-none focus:border-blue-500/40 transition-colors placeholder:text-gray-600"
              placeholder={t('ui.pages.reports.type_message_placeholder')}
              value={reportInput}
              onChange={(e) => setReportInput(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSend()}
            />
            <button
              className={`absolute right-2 w-8 h-8 rounded-md flex items-center justify-center transition-all ${
                reportInput.trim() ? 'bg-blue-600 text-white hover:bg-blue-500' : 'text-gray-600 cursor-not-allowed'
              }`}
              onClick={handleSend}
              disabled={!reportInput.trim()}
            >
              <i className="fa-solid fa-paper-plane text-xs"></i>
            </button>
          </div>
        </div>
      ) : (
        <div className="px-6 py-5 border-t border-white/[0.06] text-center">
          <div className="flex items-center justify-center gap-2 text-gray-500">
            <i className="fa-solid fa-lock text-xs"></i>
            <span className="text-[12px] font-medium">{t('ui.pages.reports.report_closed')}</span>
          </div>
        </div>
      )}

      <MediaModal isOpen={!!previewUrl} onClose={() => setPreviewUrl(null)} url={previewUrl || ''} />
    </div>
  );
};

export default PlayerReportChat;
