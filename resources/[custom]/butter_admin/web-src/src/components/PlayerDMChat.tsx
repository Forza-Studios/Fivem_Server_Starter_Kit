import React, { useState, useRef, useEffect } from 'react';
import { useAdminMenu } from '../providers/AdminMenuContext';
import { fetchNui } from '../utils/fetchNui';
import { renderChatMessageContent } from './ui/ChatMessageContent';

const PlayerDMChat: React.FC = () => {
  const { dmHistories, lastAdminId, closeMenu, setPlayerDMMode, setPlayerReportMode, addDM, t } = useAdminMenu();
  const [dmInput, setDmInput] = useState('');
  const chatScrollRef = useRef<HTMLDivElement>(null);

  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [showAttachmentPicker, setShowAttachmentPicker] = useState(false);
  const [attachmentUrl, setAttachmentUrl] = useState('');

  const emojiPickerRef = useRef<HTMLDivElement>(null);
  const attachmentPickerRef = useRef<HTMLDivElement>(null);
  const emojiButtonRef = useRef<HTMLButtonElement>(null);
  const attachmentButtonRef = useRef<HTMLButtonElement>(null);

  const emojis = ['😊', '😂', '🤣', '❤️', '👍', '🙏', '🔥', '👋', '⚠️', '✅', '❌', '👀', '🤐', '😮'];

  // Handle clicking outside to close the pickers
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        showEmojiPicker &&
        emojiPickerRef.current &&
        !emojiPickerRef.current.contains(target) &&
        emojiButtonRef.current &&
        !emojiButtonRef.current.contains(target)
      ) {
        setShowEmojiPicker(false);
      }
      if (
        showAttachmentPicker &&
        attachmentPickerRef.current &&
        !attachmentPickerRef.current.contains(target) &&
        attachmentButtonRef.current &&
        !attachmentButtonRef.current.contains(target)
      ) {
        setShowAttachmentPicker(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showEmojiPicker, showAttachmentPicker]);

  const history = lastAdminId ? dmHistories[lastAdminId] || [] : [];

  // Auto-scroll on new messages
  useEffect(() => {
    if (chatScrollRef.current) {
      chatScrollRef.current.scrollTop = chatScrollRef.current.scrollHeight;
    }
  }, [history]);

  const renderMessageContent = (message: string) => renderChatMessageContent(message);

  const handleSend = () => {
    if (!dmInput.trim() || !lastAdminId) return;

    const now = new Date();
    const timeString = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    // Players answer through their own event, so the server never treats it as an admin action.
    fetchNui('replyDirectMessage', { targetId: lastAdminId, message: dmInput }).catch(() => {});

    addDM(lastAdminId, {
      id: Date.now(),
      text: dmInput.trim(),
      isMe: true,
      time: timeString,
    });

    setDmInput('');
  };

  const handleOpenReport = () => {
    setPlayerDMMode(false);
    setPlayerReportMode(true);
    fetchNui('openPlayerReport').catch(() => {});
  };

  const handleClose = () => {
    closeMenu();
  };

  return (
    <div className="flex flex-col h-full w-full bg-[#020617]/95 border border-white/5 rounded-2xl overflow-hidden relative">
      {/* Header */}
      <div className="flex justify-between items-center p-5 bg-[#0f172a]/80 border-b border-white/5">
        <div className="flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-slate-800/50 text-slate-300 flex items-center justify-center border border-white/10 outline outline-4 outline-slate-900/50">
            <i className="fa-solid fa-user-shield text-xl"></i>
          </div>
          <div>
            <h2 className="font-rajdhani font-bold text-white text-xl leading-tight tracking-wide uppercase">
              {t('ui.pages.chats.admin_dm')}
            </h2>
            <div className="flex items-center gap-2 mt-0.5">
              <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
              <p className="font-mono text-[10px] text-slate-400 tracking-tighter uppercase">
                {t('ui.pages.chats.secure_channel')}
              </p>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleOpenReport}
            className="flex items-center gap-2 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-lg border border-white/5 transition-all group"
            title={t('ui.pages.chats.open_support')}
          >
            <i className="fa-solid fa-headset text-xs"></i>
            <span className="text-[10px] font-rajdhani font-bold uppercase tracking-wider">{t('ui.tabs.reports')}</span>
          </button>
          <button
            className="w-9 h-9 rounded-xl bg-white/5 text-slate-400 hover:text-white hover:bg-white/10 flex items-center justify-center transition-all border border-white/5"
            onClick={handleClose}
          >
            <i className="fa-solid fa-xmark text-lg"></i>
          </button>
        </div>
      </div>

      {/* Chat Messages */}
      <div className="flex-1 overflow-y-auto p-6 custom-scrollbar flex flex-col gap-5" ref={chatScrollRef}>
        {history.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-slate-600">
            <i className="fa-solid fa-comment-slash text-5xl mb-4 opacity-20"></i>
            <span className="font-rajdhani font-bold uppercase tracking-[0.2em] text-xs">
              {t('ui.pages.chats.no_messages_yet')}
            </span>
          </div>
        ) : (
          history.map((chat, idx) => {
            const isMe = chat.isMe;
            return (
              <div
                key={chat.id || idx}
                className={`flex flex-col ${isMe ? 'items-end' : 'items-start'} w-full animate-in fade-in slide-in-from-bottom-2 duration-300`}
              >
                <div className={`flex items-baseline gap-2 mb-1.5 ${isMe ? 'flex-row-reverse mr-1' : 'ml-1'}`}>
                  <span className="text-[11px] font-rajdhani font-bold text-slate-400 uppercase tracking-wider">
                    {isMe ? t('ui.pages.chats.you') : t('ui.pages.chats.admin')}
                  </span>
                  <span className="text-[9px] font-mono text-slate-600">{chat.time}</span>
                </div>
                <div
                  className={`max-w-[80%] rounded-2xl px-5 py-3 border ${
                    isMe
                      ? 'bg-[#334155] text-white border-white/10 rounded-tr-none'
                      : 'bg-[#1e293b] text-slate-100 border-white/5 rounded-tl-none'
                  }`}
                >
                  <div className="font-barlow text-sm break-words leading-relaxed">
                    {renderMessageContent(chat.text)}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Input Area */}
      <div className="p-5 pt-2 bg-[#0f172a]/40 border-t border-white/5 relative z-10">
        {/* Emoji Picker Popover */}
        {showEmojiPicker && (
          <div
            ref={emojiPickerRef}
            className="absolute bottom-[calc(100%-8px)] left-5 mb-4 w-64 bg-slate-950 border border-white/10 rounded-xl p-3 z-[100] animate-in slide-in-from-bottom-2 duration-200"
          >
            <div className="text-[10px] font-black text-white/20 uppercase tracking-widest mb-3 border-b border-white/5 pb-2">
              {t('ui.pages.chats.quick_reaction')}
            </div>
            <div className="grid grid-cols-7 gap-1">
              {emojis.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => {
                    setDmInput(dmInput + emoji);
                    setShowEmojiPicker(false);
                  }}
                  className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-white/10 transition-all active:scale-90 text-sm text-white"
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Attachment Picker Popover */}
        {showAttachmentPicker && (
          <div
            ref={attachmentPickerRef}
            className="absolute bottom-[calc(100%-8px)] left-5 mb-4 w-72 bg-slate-950 border border-white/10 rounded-xl p-4 z-[100] animate-in slide-in-from-bottom-2 duration-200"
          >
            <div className="text-[10px] font-black text-white/20 uppercase tracking-widest mb-3 border-b border-white/5 pb-2">
              {t('ui.pages.chats.insert_attachment')}
            </div>
            <div className="flex flex-col gap-3">
              <input
                type="text"
                placeholder={t('ui.pages.chats.insert_attachment_placeholder')}
                value={attachmentUrl}
                onChange={(e) => setAttachmentUrl(e.target.value)}
                className="w-full bg-slate-900 border border-white/10 rounded-lg py-2 px-3 text-sm text-white font-barlow focus:outline-none focus:border-slate-500/50"
                autoFocus
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    if (attachmentUrl.trim()) {
                      setDmInput(dmInput + (dmInput.trim() ? ' ' : '') + attachmentUrl.trim());
                      setAttachmentUrl('');
                      setShowAttachmentPicker(false);
                    }
                  }
                }}
              />
              <div className="flex gap-2 justify-end">
                <button
                  onClick={() => {
                    setShowAttachmentPicker(false);
                    setAttachmentUrl('');
                  }}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-400 hover:text-white bg-white/5 transition-all"
                >
                  {t('common.cancel')}
                </button>
                <button
                  onClick={() => {
                    if (attachmentUrl.trim()) {
                      setDmInput(dmInput + (dmInput.trim() ? ' ' : '') + attachmentUrl.trim());
                      setAttachmentUrl('');
                      setShowAttachmentPicker(false);
                    }
                  }}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold text-white bg-slate-700 hover:bg-slate-600 transition-all"
                >
                  Insert
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="relative flex items-center">
          <div className="absolute left-4 flex gap-2 z-20">
            <button
              ref={emojiButtonRef}
              onClick={() => {
                setShowEmojiPicker(!showEmojiPicker);
                setShowAttachmentPicker(false);
              }}
              className={`transition-colors ${showEmojiPicker ? 'text-slate-400' : 'text-slate-500 hover:text-slate-300'}`}
            >
              <i className="fa-regular fa-face-smile text-[15px]"></i>
            </button>
            <button
              ref={attachmentButtonRef}
              onClick={() => {
                setShowAttachmentPicker(!showAttachmentPicker);
                setShowEmojiPicker(false);
              }}
              className={`transition-colors ${showAttachmentPicker ? 'text-slate-400' : 'text-slate-500 hover:text-slate-300'}`}
            >
              <i className="fa-solid fa-paperclip text-[15px]"></i>
            </button>
          </div>
          <input
            className="w-full bg-slate-900/80 border border-white/5 rounded-xl py-3.5 pl-16 pr-14 text-white font-barlow text-sm focus:outline-none focus:border-slate-500/50 transition-all "
            type="text"
            placeholder={t('ui.pages.chats.reply_to_staff')}
            value={dmInput}
            onChange={(e) => setDmInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleSend();
            }}
            onFocus={() => {
              setShowEmojiPicker(false);
              setShowAttachmentPicker(false);
            }}
            autoFocus
          />
          <button
            className={`absolute right-2 top-1/2 transform -translate-y-1/2 w-10 h-10 rounded-lg flex items-center justify-center transition-all ${
              dmInput.trim()
                ? 'bg-slate-700 text-white hover:bg-slate-600 scale-100'
                : 'bg-slate-800 text-slate-500 opacity-50 scale-95'
            }`}
            onClick={handleSend}
            disabled={!dmInput.trim()}
          >
            <i className="fa-solid fa-paper-plane text-xs"></i>
          </button>
        </div>
      </div>
    </div>
  );
};

export default PlayerDMChat;
