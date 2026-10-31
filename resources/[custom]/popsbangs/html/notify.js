/* The resource's own notifications: small cards in the style of the work bar,
 * stacked above it (or at the top, by Config.UI.position). Each has a kind
 * (info, success, warning, error), an optional title and item icon, a hairline
 * that runs down while it lasts, and a quiet sound. No clicks, no focus. */
(() => {
  'use strict';
  const host = document.getElementById('notify');
  if (!host) return;
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const settings = { sounds: true };
  const KINDS = ['info', 'success', 'warning', 'error'];
  const ICONS = {
    info: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.5"/></svg>',
    success: '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.2 4.2L19 7.5"/></svg>',
    warning: '<svg viewBox="0 0 24 24"><path d="M12 4.5L21 19H3L12 4.5z"/><path d="M12 10v4M12 16.5v.5"/></svg>',
    error: '<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7L7 17"/></svg>'
  };
  const SOUND = { success: ['ding', 0.5], warning: ['beep', 0.5], error: ['buzz', 0.6], info: ['click', 0.35] };
  const sfx = (kind, options) => { if (!settings.sounds) return; try { if (window.oxlynWorkshopSound) window.oxlynWorkshopSound(kind, options); } catch (_) {} };
  const rgb = colour => Array.isArray(colour) && colour.length === 3 ? colour.map(v => Math.round(clamp(Number(v) || 0, 0, 1) * 255)) : null;
  const iconFor = item => typeof item === 'string' && /^[a-z0-9_]+$/i.test(item) ? `img/${item}.png` : null;

  function applySettings(s) {
    settings.sounds = s.sounds !== false;
    host.style.zoom = String(clamp(Number(s.scale) || 1, 0.8, 1.4));
    host.classList.toggle('top', s.position === 'top');
  }

  function dismiss(node) {
    if (!node || node.classList.contains('out')) return;
    clearTimeout(node._timer);
    node.classList.add('out');
    setTimeout(() => node.remove(), 260);
  }

  function show(m) {
    const kind = KINDS.includes(m.kind) ? m.kind : 'info';
    const duration = clamp(Number(m.duration) || (kind === 'error' ? 5200 : 4200), 1200, 15000);
    const node = document.createElement('div');
    node.className = `nt nt-${kind}`;
    const colour = rgb(m.colour);
    if (colour) {
      node.style.setProperty('--nt-accent', `rgb(${colour.join(', ')})`);
      node.style.setProperty('--nt-soft', `rgba(${colour.join(', ')}, 0.16)`);
    }
    const icon = iconFor(m.icon);
    node.innerHTML = `
      <div class="nt-icon">${icon ? `<img src="${icon}" alt="" draggable="false">` : ICONS[kind]}</div>
      <div class="nt-text">${m.title ? `<div class="nt-title">${esc(m.title)}</div>` : ''}<div class="nt-msg">${esc(m.message)}</div></div>
      <i class="nt-bar" style="animation-duration:${duration}ms"></i>`;
    host.appendChild(node);
    while (host.children.length > 4) dismiss(host.firstElementChild);
    void node.offsetWidth;
    node.classList.add('in');
    node._timer = setTimeout(() => dismiss(node), duration);
    const sound = SOUND[kind];
    if (sound) sfx(sound[0], { level: sound[1] });
  }

  window.addEventListener('message', event => {
    const m = event.data;
    if (!m || typeof m !== 'object') return;
    if (m.action === 'notify' && typeof m.message === 'string' && m.message) show(m);
    else if (m.action === 'ui' && m.settings && typeof m.settings === 'object') applySettings(m.settings);
    else if (m.action === 'reset') { for (const node of [...host.children]) dismiss(node); }
  });
  if (window.__oxlynTest) window.__notify = { count: () => host.children.length, show };
})();
