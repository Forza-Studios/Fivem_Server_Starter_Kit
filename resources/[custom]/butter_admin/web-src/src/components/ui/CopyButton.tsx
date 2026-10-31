import React, { useEffect, useState } from 'react';
import { Check, Copy } from 'lucide-react';
import { copyTextToClipboard } from '../../utils/misc';
import { cn } from '../../utils/cn';

interface CopyButtonProps {
  text: string;
  title?: string;
  className?: string;
  size?: number;
}

export const CopyButton: React.FC<CopyButtonProps> = ({ text, title, className, size = 12 }) => {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(false), 1200);
    return () => clearTimeout(timer);
  }, [copied]);

  return (
    <button
      type="button"
      title={title ?? text}
      onClick={(e) => {
        e.stopPropagation();
        setCopied(copyTextToClipboard(text));
      }}
      className={cn(
        'p-1 rounded-md transition-colors',
        copied ? 'text-success' : 'text-white/25 hover:text-white hover:bg-white/10',
        className,
      )}
    >
      {copied ? <Check size={size} /> : <Copy size={size} />}
    </button>
  );
};
