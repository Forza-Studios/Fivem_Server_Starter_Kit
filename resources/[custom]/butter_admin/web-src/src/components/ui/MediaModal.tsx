import React from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useAdminMenu } from '../../providers/AdminMenuContext';

interface MediaModalProps {
  isOpen: boolean;
  onClose: () => void;
  url: string;
}

export const MediaModal: React.FC<MediaModalProps> = ({ isOpen, onClose, url }) => {
  const { t } = useAdminMenu();
  const isImage = /\.(jpg|jpeg|png|webp|gif)(\?.*)?$/i.test(url);

  // Basic clip URL converters for iframes
  const getEmbedUrl = (url: string) => {
    if (url.includes('medal.tv')) {
      const match = url.match(/clip\/([a-zA-Z0-9]+)/);
      if (match) return `https://medal.tv/clip/${match[1]}?autoplay=1&muted=0&loop=1`;
    }
    if (url.includes('streamable.com')) {
      const match = url.match(/streamable\.com\/([a-zA-Z0-9]+)/);
      if (match) return `https://streamable.com/e/${match[1]}?autoplay=1`;
    }
    if (url.includes('youtube.com') || url.includes('youtu.be')) {
      const match = url.match(/(?:v=|youtu\.be\/)([a-zA-Z0-9_-]+)/);
      if (match) return `https://www.youtube.com/embed/${match[1]}?autoplay=1`;
    }
    return url;
  };

  const embedUrl = getEmbedUrl(url);
  const isVideo = embedUrl !== url || /\.(mp4|webm|ogg)$/i.test(url);

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-8 bg-black/90">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 cursor-zoom-out"
            onClick={onClose}
          />

          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            className="relative max-w-7xl max-h-full aspect-video bg-black rounded-2xl overflow-hidden border border-white/5 flex items-center justify-center"
          >
            {isImage ? (
              <img src={url} alt="preview" className="max-w-full max-h-full object-contain" />
            ) : isVideo ? (
              <iframe
                src={embedUrl}
                className="w-full h-full border-none"
                allow="autoplay; fullscreen; picture-in-picture"
                allowFullScreen
              />
            ) : (
              <div className="flex flex-col items-center gap-4 text-white">
                <i className="fa-solid fa-link text-4xl opacity-50"></i>
                <p className="font-rajdhani text-xl font-bold tracking-widest uppercase">{t('common.external_link')}</p>
                <a
                  href={url}
                  target="_blank"
                  rel="noreferrer"
                  className="px-6 py-2 bg-accent text-white rounded-lg font-bold uppercase tracking-wider hover:bg-accent/80 transition-colors"
                >
                  {t('common.open_in_browser')}
                </a>
              </div>
            )}

            <button
              onClick={onClose}
              className="absolute top-4 right-4 w-10 h-10 rounded-full bg-black/50 text-white flex items-center justify-center hover:bg-white/20 transition-colors"
            >
              <i className="fa-solid fa-xmark"></i>
            </button>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
