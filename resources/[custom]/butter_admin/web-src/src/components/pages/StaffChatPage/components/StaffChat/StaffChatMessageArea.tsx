import React, { RefObject } from 'react';
import { useAdminMenu } from '../../../../../providers/AdminMenuContext';
import { renderChatMessageContent } from '../../../../ui/ChatMessageContent';

interface StaffChatMessageAreaProps {
  staffchat: { Sender: string; Message: string; Time: string }[];
  myName: string;
  chatListRef: RefObject<HTMLDivElement | null>;
  isFiltered?: boolean;
}

export const StaffChatMessageArea: React.FC<StaffChatMessageAreaProps> = ({
  staffchat,
  myName,
  chatListRef,
  isFiltered,
}) => {
  const { t } = useAdminMenu();
  return (
    <div className="flex-1 overflow-y-auto custom-scrollbar p-6 flex flex-col gap-5" ref={chatListRef}>
      {staffchat.length === 0 ? (
        <div className="flex-1 flex flex-col items-center justify-center text-muted opacity-60">
          <div className="w-20 h-20 rounded-full bg-black/40 border border-white/5 flex items-center justify-center mb-4">
            <i className="fa-solid fa-comments text-3xl text-accent/50"></i>
          </div>
          <p className="font-rajdhani text-lg font-semibold tracking-wider uppercase">
            {isFiltered ? t('ui.pages.chats.no_matching_messages') : t('ui.pages.chats.no_messages')}
          </p>
          {!isFiltered && <p className="font-barlow text-sm mt-1">{t('ui.pages.chats.first_message')}</p>}
        </div>
      ) : (
        staffchat.map((msg, idx) => {
          const isMe = myName === msg.Sender;
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
                    className={`px-4 py-2.5 ${isMe ? 'bg-accent text-white rounded-2xl rounded-br-sm' : 'bg-black/60 text-primary border border-white/5 rounded-2xl rounded-bl-sm'}`}
                  >
                    <div className="font-barlow text-sm leading-relaxed whitespace-pre-wrap break-words">
                      {renderChatMessageContent(msg.Message, { isMe })}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          );
        })
      )}
    </div>
  );
};
