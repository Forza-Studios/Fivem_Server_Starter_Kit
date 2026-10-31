import React, { RefObject, useState } from 'react';
import { Report } from '../../../../../types';
import { openExternalUrl } from '../../../../../utils/misc';
import { MediaModal } from '../../../../ui/MediaModal';
import { renderChatMessageContent } from '../../../../ui/ChatMessageContent';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';

interface ReportChatViewProps {
  currentReport: Report;
  myName: string;
  chatRef: RefObject<HTMLDivElement | null>;
}

export const ReportChatView: React.FC<ReportChatViewProps> = ({ currentReport, myName, chatRef }) => {
  const { t } = useAdminMenu();
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const handleOpenMedia = (url: string) => {
    // Check if it's a media URL that we can show in-game
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

  return (
    <div className="flex-1 flex flex-col overflow-hidden px-6">
      {/* Initial Statement Card */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2 px-1">
          <div className="flex items-center gap-2">
            <i className="fa-solid fa-quote-left text-[9px] text-accent/70"></i>
            <span className="text-[10px] font-rajdhani font-bold uppercase tracking-widest text-muted">
              {t('ui.pages.reports.initial_comment')}
            </span>
          </div>
          <span className="text-[10px] font-mono text-muted/50">
            {currentReport.Chats?.[0]?.Sender || 'Unknown'} • {currentReport.Chats?.[0]?.Time || '--:--'}
          </span>
        </div>

        <div className="bg-black/30 border border-border/40 rounded-xl p-4">
          <p className="text-[13px] font-barlow text-primary/90 leading-relaxed whitespace-pre-wrap">
            {currentReport.Description ||
              currentReport.Chats?.[0]?.Message ||
              t('ui.pages.reports.no_description_provided')}
          </p>

          {currentReport.Clips && currentReport.Clips !== 'None' && (
            <div className="mt-3 pt-3 border-t border-white/5 flex items-center">
              <button
                onClick={() => handleOpenMedia(currentReport.Clips!)}
                className="text-[11px] text-accent hover:text-accent/80 flex items-center gap-2 font-barlow font-medium transition-colors"
              >
                <i className="fa-solid fa-paperclip text-[10px]"></i> {t('ui.pages.reports.view_proof')}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Message area */}
      <div className="flex-1 overflow-y-auto custom-scrollbar flex flex-col gap-5 pb-6" ref={chatRef}>
        {(currentReport.Chats || []).length <= 1 ? (
          <div className="flex-1 flex flex-col items-center justify-center text-muted opacity-60 select-none">
            <div className="w-20 h-20 rounded-full bg-black/40 border border-white/5 flex items-center justify-center mb-4">
              <i className="fa-solid fa-comments text-3xl text-accent/50"></i>
            </div>
            <p className="font-rajdhani text-lg font-semibold tracking-wider uppercase">
              {t('ui.pages.reports.no_messages')}
            </p>
            <p className="font-barlow text-sm mt-1">{t('ui.pages.reports.start_conversation')}</p>
          </div>
        ) : (
          (currentReport.Chats || []).slice(1).map((msg, idx) => {
            const isMe = msg.Sender === myName;
            const initial = msg.Sender ? msg.Sender.charAt(0).toUpperCase() : '?';
            return (
              <div key={idx} className={`flex w-full ${isMe ? 'justify-end' : 'justify-start'}`}>
                <div className={`flex max-w-[85%] gap-3 ${isMe ? 'flex-row-reverse' : 'flex-row'}`}>
                  <div className="flex-shrink-0 mt-auto mb-1">
                    <div
                      className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold font-rajdhani border ${isMe ? 'bg-accent/20 text-accent border-accent/50' : 'bg-black/60 text-muted border-border/80'}`}
                    >
                      {initial}
                    </div>
                  </div>
                  <div className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}>
                    <div className="flex items-baseline gap-2 mb-1.5 mx-1">
                      <span className="text-[11px] font-rajdhani font-bold tracking-wider text-primary/70 uppercase">
                        {msg.Sender}
                      </span>
                      <span className="text-[10px] font-mono text-muted/50">{msg.Time}</span>
                    </div>
                    <div
                      className={`px-4 py-2.5 ${
                        isMe
                          ? 'bg-accent text-white rounded-2xl rounded-br-sm'
                          : 'bg-black/60 text-primary border border-white/5 rounded-2xl rounded-bl-sm'
                      }`}
                    >
                      <div className="font-barlow text-sm leading-relaxed break-words whitespace-pre-wrap">
                        {renderChatMessageContent(msg.Message, { isMe, onOpenMedia: handleOpenMedia })}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      <MediaModal isOpen={!!previewUrl} onClose={() => setPreviewUrl(null)} url={previewUrl || ''} />
    </div>
  );
};
