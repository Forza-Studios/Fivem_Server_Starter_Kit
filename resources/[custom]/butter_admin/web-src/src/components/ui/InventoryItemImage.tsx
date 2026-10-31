import React, { useState } from 'react';
import { Package } from 'lucide-react';
import { cn } from '../../utils/cn';

interface InventoryItemImageProps {
  item: { name: string; label?: string; image?: string };
  className?: string;
}

/**
 * Resolves an inventory item's icon from whichever inventory resource is
 * actually serving images (ox_inventory, then qb-inventory), falling back to
 * a neutral placeholder. Deliberately never falls back to an external CDN url,
 * NUI blocks those hosts, so a raw.githubusercontent.com/flaticon.com
 * fallback just renders a broken image in-game.
 */
export const InventoryItemImage: React.FC<InventoryItemImageProps> = ({ item, className }) => {
  const [src, setSrc] = useState(() => {
    if (item.image && item.image.includes('://') && !item.image.includes('nui://')) return item.image;
    return `nui://ox_inventory/web/images/${item.name}.png`;
  });
  const [fallbackStep, setFallbackStep] = useState(0);
  const [failed, setFailed] = useState(false);

  if (failed) {
    const initials = (item.label || item.name)
      .split(/[\s_-]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase();

    return (
      <div
        title={item.label || item.name}
        className={cn(
          className ?? 'w-10 h-10',
          'relative flex items-center justify-center rounded-xl border border-dashed border-white/15 bg-gradient-to-br from-white/[0.06] to-white/[0.01] text-white/25',
        )}
      >
        <Package className="w-1/2 h-1/2" strokeWidth={1.5} />
        {initials && (
          <span className="absolute bottom-0.5 right-1 text-[9px] font-mono font-bold text-white/30 leading-none">
            {initials}
          </span>
        )}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={item.label || item.name}
      className={className ?? 'w-10 h-10 object-contain'}
      onError={() => {
        if (fallbackStep === 0) {
          setSrc(`nui://qb-inventory/html/images/${item.name}.png`);
          setFallbackStep(1);
        } else {
          setFailed(true);
        }
      }}
    />
  );
};
