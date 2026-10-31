import React, { useState, useRef, useEffect } from 'react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';
import { renderChatMessageContent } from '../../../../ui/ChatMessageContent';

interface Player {
  ServerId: number;
  Name: string;
}
interface DmMessage {
  id: number;
  text: string;
  isMe: boolean;
  time: string;
}

interface DmChatWindowProps {
  selectedPlayerId: number;
  players: Player[];
  dmHistories: Record<number, DmMessage[]>;
  dmInput: string;
  setDmInput: (v: string) => void;
  onSend: () => void;
  onKeyPress: (e: React.KeyboardEvent) => void;
  sendTimeout: boolean;
  isSmall: boolean;
  onBack: () => void;
}

export const DmChatWindow: React.FC<DmChatWindowProps> = ({
  selectedPlayerId,
  players,
  dmHistories,
  dmInput,
  setDmInput,
  onSend,
  onKeyPress,
  sendTimeout,
  isSmall,
  onBack,
}) => {
  const { t } = useAdminMenu();
  const player = players.find((p) => p.ServerId === selectedPlayerId);
  const messages = dmHistories[selectedPlayerId] || [];

  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [showAttachmentPicker, setShowAttachmentPicker] = useState(false);
  const [attachmentUrl, setAttachmentUrl] = useState('');

  const emojiPickerRef = useRef<HTMLDivElement>(null);
  const attachmentPickerRef = useRef<HTMLDivElement>(null);
  const emojiButtonRef = useRef<HTMLButtonElement>(null);
  const attachmentButtonRef = useRef<HTMLButtonElement>(null);

  const emojis = ['😊', '😂', '🤣', '❤️', '👍', '🙏', '🔥', '👋', '⚠️', '✅', '❌', '👀', '🤐', '😮'];

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

  return (
    <div className="flex-1 flex flex-col bg-black/10 relative">
      {/* Header */}
      <div className="px-6 py-4 border-b border-white/10 bg-black/30 flex items-center justify-between z-10">
        <div className="flex items-center gap-4">
          {isSmall && (
            <button
              onClick={onBack}
              className="w-10 h-10 rounded-lg flex items-center justify-center text-muted hover:text-white bg-black/40 border border-white/5 hover:border-white/20 transition-all "
            >
              <i className="fa-solid fa-chevron-left text-sm"></i>
            </button>
          )}
          <div className="w-12 h-12 rounded-xl bg-accent/20 flex items-center justify-center font-rajdhani font-bold text-2xl border border-accent/40 text-accent">
            {player?.Name.charAt(0).toUpperCase()}
          </div>
          <div>
            <div className="font-rajdhani font-bold text-primary text-xl leading-none uppercase tracking-wide mb-1">
              {player?.Name}
            </div>
            <div className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></div>
              <span className="text-[10px] font-mono text-muted uppercase tracking-widest">
                Direct Message • ID: {selectedPlayerId}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto custom-scrollbar p-6 flex flex-col gap-5">
        {messages.length === 0
          ? null
          : messages.map((msg) => (
              <div
                key={msg.id}
                className={`flex w-full ${msg.isMe ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2 fade-in duration-300`}
              >
                <div className={`flex max-w-[75%] flex-col ${msg.isMe ? 'items-end' : 'items-start'}`}>
                  <div
                    className={`px-5 py-3 rounded-2xl relative ${msg.isMe ? 'bg-accent text-white rounded-br-sm' : 'bg-black/60 text-primary border border-white/10 rounded-bl-sm'}`}
                  >
                    <div className="font-barlow text-[15px] leading-relaxed whitespace-pre-wrap break-words">
                      {renderChatMessageContent(msg.text, { isMe: msg.isMe })}
                    </div>
                  </div>
                  <div className="flex items-center gap-1 mt-1.5 mx-1 opacity-60">
                    {msg.isMe && <i className="fa-solid fa-check-double text-[8px] text-accent"></i>}
                    <span className="text-[10px] font-mono text-muted tracking-wide">{msg.time}</span>
                  </div>
                </div>
              </div>
            ))}
      </div>

      {/* Input */}
      <div className="p-5 bg-black/40 border-t border-white/10 z-10 relative">
        {/* Emoji Picker Popover */}
        {showEmojiPicker && (
          <div
            ref={emojiPickerRef}
            className="absolute bottom-[calc(100%-8px)] left-4 mb-4 w-64 bg-slate-950 border border-white/10 rounded-xl p-3 z-[100] animate-in slide-in-from-bottom-2 duration-200"
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
                  className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-white/10 transition-all active:scale-90 text-sm"
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
            className="absolute bottom-[calc(100%-8px)] left-4 mb-4 w-72 bg-slate-950 border border-white/10 rounded-xl p-4 z-[100] animate-in slide-in-from-bottom-2 duration-200"
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
                className="w-full bg-black/50 border border-white/10 rounded-lg py-2 px-3 text-sm text-primary font-barlow focus:outline-none focus:border-accent/60"
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
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold text-muted hover:text-white bg-white/5 transition-all"
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
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold text-white bg-accent hover:bg-accent/90 transition-all"
                >
                  Insert
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="relative flex items-center bg-black/50 border border-white/10 rounded-xl focus-within:border-accent/60 focus-within:bg-black/70 transition-all">
          <div className="absolute left-4 flex gap-2 z-20">
            <button
              ref={emojiButtonRef}
              onClick={() => {
                setShowEmojiPicker(!showEmojiPicker);
                setShowAttachmentPicker(false);
              }}
              className={`transition-colors ${showEmojiPicker ? 'text-accent' : 'text-muted/60 hover:text-accent'}`}
            >
              <i className="fa-regular fa-face-smile"></i>
            </button>
            <button
              ref={attachmentButtonRef}
              onClick={() => {
                setShowAttachmentPicker(!showAttachmentPicker);
                setShowEmojiPicker(false);
              }}
              className={`transition-colors ${showAttachmentPicker ? 'text-accent' : 'text-muted/60 hover:text-accent'}`}
            >
              <i className="fa-solid fa-paperclip"></i>
            </button>
          </div>
          <input
            type="text"
            className="w-full bg-transparent py-4 pl-16 pr-14 text-primary font-barlow focus:outline-none placeholder:text-muted/40"
            placeholder={t('ui.pages.chats.message_player_placeholder', player?.Name)}
            spellCheck={false}
            value={dmInput}
            onChange={(e) => setDmInput(e.target.value)}
            onKeyPress={onKeyPress}
            onFocus={() => {
              setShowEmojiPicker(false);
              setShowAttachmentPicker(false);
            }}
          />
          <button
            className={`absolute right-2 w-10 h-10 rounded-lg flex items-center justify-center transition-all duration-300 ${dmInput.trim() ? 'bg-accent text-white hover:scale-105' : 'bg-white/5 text-muted opacity-50 cursor-not-allowed'}`}
            disabled={!dmInput.trim() || sendTimeout}
            onClick={onSend}
          >
            <i className="fa-solid fa-paper-plane text-sm translate-x-[-1px] translate-y-[1px]"></i>
          </button>
        </div>
      </div>
    </div>
  );
};

export const DmEmptyState: React.FC = () => {
  const { t } = useAdminMenu();
  return (
    <div className="flex-1 flex flex-col items-center justify-center text-muted opacity-60 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-black/20 via-black/0 to-transparent">
      <div className="w-24 h-24 rounded-full bg-black/40 border border-white/5 flex items-center justify-center mb-6">
        <i className="fa-solid fa-envelope-open-text text-4xl text-accent/50"></i>
      </div>
      <p className="font-rajdhani text-2xl font-bold tracking-widest uppercase text-primary">
        {t('ui.pages.chats.private_messages')}
      </p>
      <p className="font-barlow mt-2">{t('ui.pages.chats.select_player_desc')}</p>
    </div>
  );
};
