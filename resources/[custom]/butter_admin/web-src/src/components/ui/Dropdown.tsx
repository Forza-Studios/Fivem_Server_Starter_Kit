import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { useAdminMenu } from '../../providers/AdminMenuContext';
import { DropdownChoice, DropdownPosition } from '../../types';

interface DropdownProps {
  options: DropdownChoice[];
  hasSearch: boolean;
  position: DropdownPosition;
  optionName?: string;
  onSelect: (choice: DropdownChoice) => void;
  onClose: () => void;
}

const Dropdown: React.FC<DropdownProps> = ({ options, hasSearch, position, optionName, onSelect, onClose }) => {
  const { opened } = useAdminMenu();
  const [searchText, setSearchText] = useState('');
  const dropdownRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (hasSearch && searchRef.current) {
      searchRef.current.focus();
    }
  }, [hasSearch]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    // Delay to prevent immediate close on the same click that opened it
    const timer = setTimeout(() => {
      document.addEventListener('click', handleClickOutside);
    }, 250);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('click', handleClickOutside);
    };
  }, [onClose]);

  useEffect(() => {
    if (!opened) onClose();
  }, [opened, onClose]);

  if (!opened) return null;

  const filteredOptions = options.filter((opt) => {
    const searchLower = searchText.toLowerCase();
    return opt.Text.toLowerCase().includes(searchLower) || (opt.Label && opt.Label.toLowerCase().includes(searchLower));
  });

  const portalRoot = document.getElementById('dropdown-portal-root');
  if (!portalRoot) return null;

  const rootRect = portalRoot.getBoundingClientRect();

  // ─── Position inside the portal root ───────────────────────────────────────
  // `position` (x/y/width/triggerHeight) is now supplied in LAYOUT px by
  // dropdownPositionFrom(): the trigger's offset within #menu-zoom-layer,
  // measured via offsetLeft/offsetTop/offset* which are immune to the CSS `zoom`
  // layer and to the visual-vs-pre-zoom getBoundingClientRect ambiguity that
  // differs between Chrome and some FiveM CEF builds.
  //
  // The portal root sits OUTSIDE the zoom layer but shares its exact visual
  // origin (both fill the same relative parent). So the trigger's VISUAL offset
  // from the portal root's top-left is simply its layout offset × `zoom`.
  // Multiplying by `zoom` here, with no rect reads on zoomed elements, lands
  // the list correctly on every engine.
  const zoom = position.zoom ?? 1;

  const localX = position.x * zoom;
  const localY = position.y * zoom;
  const localWidth = parseFloat(position.width) * zoom;

  // Clamp horizontally so the dropdown never overflows the panel edges.
  const clampedLeft = Math.min(localX, rootRect.width - localWidth - 4);

  // Flip above the trigger if the dropdown would overflow the bottom of the panel.
  const ITEM_HEIGHT = 30;
  const SEARCH_HEIGHT = hasSearch ? 42 : 0;
  const estimatedHeight = Math.min(filteredOptions.length * ITEM_HEIGHT + SEARCH_HEIGHT + 8, 220);
  const flipUp = localY + estimatedHeight > rootRect.height;
  const triggerHeight = (position.triggerHeight ?? 32) * zoom;
  const finalTop = flipUp ? localY - estimatedHeight - triggerHeight : localY;

  const colorClass = 'text-primary/70';
  const hoverClass = 'hover:bg-accent/15 hover:text-accent';

  return createPortal(
    <div
      ref={dropdownRef}
      className="absolute z-[9999] bg-bg-primary border border-border/40 rounded overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-150 pointer-events-auto"
      style={{
        top: Math.max(4, finalTop),
        left: Math.max(4, clampedLeft),
        maxHeight: '220px',
        width: localWidth,
      }}
    >
      {/* Search bar */}
      {hasSearch && (
        <div className="px-2 pt-1.5 pb-1 border-b border-border/30 bg-bg-primary sticky top-0 z-10">
          <div className="relative">
            <i className="fa-solid fa-magnifying-glass absolute left-2 top-1/2 -translate-y-1/2 text-muted text-[9px] pointer-events-none" />
            <input
              ref={searchRef}
              type="text"
              placeholder="Search..."
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              onClick={(e) => e.stopPropagation()}
              className="w-full bg-bg-secondary border border-border/30 rounded py-1 pl-6 pr-2 text-[11px] text-primary font-barlow focus:outline-none focus:border-accent/50 transition-colors placeholder:text-muted/40"
            />
          </div>
        </div>
      )}

      {/* Options list */}
      <div className="overflow-y-auto custom-scrollbar flex-1 py-0.5">
        {filteredOptions.length === 0 ? (
          <div className="px-3 py-2 text-[11px] text-muted font-barlow text-center opacity-60">No options found</div>
        ) : (
          filteredOptions.map((opt, idx) => (
            <div
              key={idx}
              className={`px-3 py-1.5 text-[11px] font-barlow cursor-pointer transition-colors flex items-center gap-1.5 ${colorClass} ${hoverClass}`}
              onClick={(e) => {
                e.stopPropagation();
                onSelect(opt);
                onClose();
              }}
            >
              {opt.Icon && <i className={`${opt.Icon} w-3 text-center opacity-50 text-[9px] shrink-0`} />}
              <span className="flex-1 truncate leading-tight">{opt.Text}</span>
              {opt.Label && (
                <span className="text-[9px] text-muted bg-bg-secondary px-1 py-0.5 rounded border border-border/30 shrink-0">
                  {opt.Label}
                </span>
              )}
            </div>
          ))
        )}
      </div>
    </div>,
    portalRoot,
  );
};

export default Dropdown;
