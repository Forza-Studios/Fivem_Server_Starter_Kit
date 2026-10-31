import React, { useState } from 'react';

const IMAGE_RE = /\.(jpg|jpeg|png|webp|gif)(\?.*)?$/i;
const URL_RE = /(https?:\/\/[^\s]+)/g;

export const isImageUrl = (url: string): boolean => IMAGE_RE.test(url);

interface ImageAttachmentProps {
  url: string;
  isMe?: boolean;
  onOpen?: (url: string) => void;
}

// Never sets `src` until the admin deliberately clicks to view it, an eagerly
// rendered <img src={url}> fetches the moment the message scrolls into view,
// which lets a planted URL in a chat/report message beacon the admin's IP/UA
// just from opening the conversation, with no click required.
const ImageAttachment: React.FC<ImageAttachmentProps> = ({ url, isMe, onOpen }) => {
  const [revealed, setRevealed] = useState(false);

  if (revealed) {
    return (
      <img
        src={url}
        alt="attachment"
        className="max-w-full rounded-lg border border-white/10 cursor-pointer hover:opacity-90 transition-opacity"
        onClick={() => (onOpen ? onOpen(url) : window.open(url, '_blank', 'noopener,noreferrer'))}
      />
    );
  }

  return (
    <button
      type="button"
      onClick={() => (onOpen ? onOpen(url) : setRevealed(true))}
      className={`mt-1 inline-flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-barlow border transition-colors ${
        isMe
          ? 'bg-white/10 border-white/20 text-white hover:bg-white/20'
          : 'bg-black/40 border-white/10 text-muted hover:text-white hover:border-white/30'
      }`}
    >
      <i className="fa-solid fa-image"></i> View image attachment
    </button>
  );
};

/**
 * Renders chat/report/DM message text, turning bare URLs into click-to-open
 * links and image URLs into a click-to-reveal attachment (never an eagerly
 * loaded <img>). Shared across StaffChat, Reports, and DM views so the
 * behavior can't drift between them.
 */
export function renderChatMessageContent(
  message: string,
  options?: { isMe?: boolean; onOpenMedia?: (url: string) => void; linkClassName?: string },
): React.ReactNode {
  const isMe = options?.isMe;
  const onOpenMedia = options?.onOpenMedia;
  const linkClassName =
    options?.linkClassName ?? (isMe ? 'text-white hover:text-white/80' : 'text-blue-400 hover:text-blue-300');

  const parts = (message || '').split(URL_RE);

  return parts.map((part, i) => {
    if (part.match(URL_RE)) {
      if (isImageUrl(part)) {
        return <ImageAttachment key={i} url={part} isMe={isMe} onOpen={onOpenMedia} />;
      }
      return (
        <button
          key={i}
          type="button"
          onClick={() => (onOpenMedia ? onOpenMedia(part) : window.open(part, '_blank', 'noopener,noreferrer'))}
          className={`underline text-left break-all transition-colors font-barlow text-sm ${linkClassName}`}
        >
          {part}
        </button>
      );
    }
    return <span key={i}>{part}</span>;
  });
}
