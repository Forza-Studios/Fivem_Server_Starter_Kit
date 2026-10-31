import React from 'react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';

interface ReportMessageInputProps {
  messageInput: string;
  setMessageInput: (v: string) => void;
  onSend: () => void;
  onKeyPress: (e: React.KeyboardEvent) => void;
  sendTimeout: boolean;
}

export const ReportMessageInput: React.FC<ReportMessageInputProps> = ({
  messageInput,
  setMessageInput,
  onSend,
  onKeyPress,
  sendTimeout,
}) => {
  const { t } = useAdminMenu();
  const [showEmojiPicker, setShowEmojiPicker] = React.useState(false);
  const emojis = ['😊', '😂', '🤣', '❤️', '👍', '🙏', '🔥', '👋', '⚠️', '✅', '❌', '👀', '🤐', '😮'];

  return (
    <div className="p-5 bg-black/30 border-t border-border/50 flex-shrink-0 relative">
      <div className="relative flex items-center">
        {showEmojiPicker && (
          <div className="absolute bottom-full left-0 mb-4 w-64 bg-slate-950 border border-white/10 rounded-xl p-3 z-[100] animate-in slide-in-from-bottom-2 duration-200">
            <div className="text-[10px] font-black text-white/20 uppercase tracking-widest mb-3 border-b border-white/5 pb-2">
              {t('ui.pages.reports.quick_reaction')}
            </div>
            <div className="grid grid-cols-7 gap-1">
              {emojis.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => {
                    setMessageInput(messageInput + emoji);
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

        <div className="absolute left-3 flex gap-2 z-10">
          <button
            onClick={() => setShowEmojiPicker(!showEmojiPicker)}
            className={`transition-colors ${showEmojiPicker ? 'text-accent' : 'text-muted/60 hover:text-accent'}`}
          >
            <i className="fa-regular fa-face-smile text-[15px]"></i>
          </button>
        </div>

        <input
          type="text"
          className="w-full bg-black/60 border border-border/60 rounded-xl py-3.5 pl-11 pr-14 text-primary font-barlow text-sm focus:outline-none focus:border-accent/70 focus:bg-black/80 transition-all placeholder:text-muted/40"
          placeholder={t('ui.pages.reports.send_message_placeholder')}
          spellCheck={false}
          value={messageInput}
          onChange={(e) => setMessageInput(e.target.value)}
          onKeyPress={onKeyPress}
          onFocus={() => setShowEmojiPicker(false)}
          autoFocus
        />

        <button
          className={`absolute right-2 w-9 h-9 rounded-lg flex items-center justify-center transition-all duration-300 ${messageInput.trim() ? 'bg-accent text-white hover:scale-105 hover:bg-accent/90' : 'bg-white/5 text-muted cursor-not-allowed'}`}
          onClick={onSend}
          disabled={!messageInput.trim() || sendTimeout}
        >
          <i className="fa-solid fa-paper-plane text-sm"></i>
        </button>
      </div>
    </div>
  );
};
