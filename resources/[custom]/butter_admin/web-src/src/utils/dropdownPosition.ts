import { getCurrentZoom } from '../hooks/useResolutionScale';

/**
 * Compute a Dropdown `position` from a trigger element using LAYOUT-space
 * offsets (offsetLeft / offsetTop / offsetWidth / offsetHeight).
 *
 * Why not getBoundingClientRect(): the menu content lives inside a CSS `zoom`
 * layer, and getBoundingClientRect() reports VISUAL (post-zoom) coords in
 * Chrome/CEF-modern but PRE-zoom (layout) coords in some FiveM CEF builds.
 * That ambiguity is impossible to pin down blind and made the floating list
 * land in the wrong place in-game.
 *
 * `offsetLeft/Top/Width/Height` are ALWAYS CSS layout px, never scaled by
 * `zoom` and identical across engines. We sum them up the offsetParent chain to
 * get the trigger's layout offset within `#menu-zoom-layer`, and the Dropdown
 * scales that by `zoom` to land in the un-zoomed `#dropdown-portal-root`, which
 * shares the zoom layer's visual origin. Result: correct positioning on every
 * engine with no convention detection at all.
 *
 * x/y is the trigger's TOP-LEFT within the zoom layer, offset down by the
 * trigger's own height so the list opens flush beneath it (the Dropdown flips
 * it above the trigger when there isn't room below).
 */
export function dropdownPositionFrom(el: HTMLElement) {
  let x = 0;
  let y = 0;
  let node: HTMLElement | null = el;
  while (node && node.id !== 'menu-zoom-layer') {
    x += node.offsetLeft;
    y += node.offsetTop;
    node = node.offsetParent as HTMLElement | null;
  }

  // offsetLeft/Top are layout positions within the offsetParent chain and do
  // NOT account for scrolling of scrollable ancestors (e.g. the command list's
  // overflow-y-auto container) between el and #menu-zoom-layer. Walk the real
  // DOM parent chain and subtract accumulated scroll so the dropdown lands on
  // the trigger's actual visual position even when that list is scrolled.
  let scrollNode: HTMLElement | null = el.parentElement;
  while (scrollNode && scrollNode.id !== 'menu-zoom-layer') {
    x -= scrollNode.scrollLeft;
    y -= scrollNode.scrollTop;
    scrollNode = scrollNode.parentElement;
  }

  return {
    x,
    y: y + el.offsetHeight, // open flush beneath the trigger
    width: `${el.offsetWidth}px`,
    triggerHeight: el.offsetHeight,
    zoom: getCurrentZoom(),
  };
}
