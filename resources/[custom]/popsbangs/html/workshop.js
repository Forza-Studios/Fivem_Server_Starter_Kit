/* The work bar (4.10): one card at the bottom of the screen with a soft glow
 * of the part's colour behind it. It shows the part going on, phase by phase,
 * over the seconds the server gave (a ring around the item fills with it);
 * then the level selector for the anti-lag; then the outcome with what was
 * spent and what came back. It takes no clicks: the game keeps the controls,
 * the client's thread keeps the time and tells this page what to show. */
(() => {
  'use strict';
  const root = document.getElementById('workshop');
  if (!root) return;
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const rgb = colour => Array.isArray(colour) && colour.length === 3 ? colour.map(v => Math.round(clamp(Number(v) || 0, 0, 1) * 255)) : null;
  const settings = { sounds: true, preview: true };
  // The texts, in the server's language (a `locale` message from the game); English until then.
  const EN = {
    ui_title_install: 'Installing the anti-lag', ui_title_remove: 'Removing the anti-lag', ui_title_tune: 'Anti-lag tuning', ui_title_exhaust: 'Fitting the %s exhaust',
    ph_install_1: 'Opening the engine bay', ph_install_2: 'Fixing the anti-lag module', ph_install_3: 'Connecting the sensors and the valve', ph_install_4: 'Tightening the terminals', ph_install_5: 'Testing the turbo',
    ph_remove_1: 'Disconnecting the battery', ph_remove_2: 'Loosening the terminals', ph_remove_3: 'Taking the module out', ph_remove_4: 'Closing the engine bay',
    ph_exhaust_1: 'Loosening the clamps', ph_exhaust_2: 'Taking the exhaust off', ph_exhaust_3: 'Seating the new exhaust', ph_exhaust_4: 'Tightening the clamps', ph_exhaust_5: 'Checking for leaks',
    ui_power_level: 'Power level', ui_installed: 'installed', ui_installed_is: 'Installed: %s.', ui_choose: 'Choose the pops and bangs level.', ui_is_installed: 'This is the level installed.',
    ui_applying: 'Applying level %d', ui_saving: '%s: saving the tune to the car.', ui_done: 'Done', ui_failed: 'Not possible', ui_exhaust_done: 'Exhaust fitted. Rev it to hear it.',
    ui_remove_done: 'The car is back on its stock exhaust.', ui_antilag_ready: 'Anti-lag ready at level %d.', ui_ready: 'Ready.', ui_nothing_spent: 'Nothing was spent.',
    ui_spent: 'Spent: %s', ui_received: 'Received: %s', ui_you_receive: 'You receive: %s', ui_spends: 'Spends: %s', ui_cancel: 'cancel', ui_choose_key: 'choose', ui_confirm: 'confirm', ui_or: 'or',
    ui_bangs_rare: 'rare bangs', ui_bangs_some: 'occasional bangs', ui_bangs_limiter: 'bangs on the limiter', ui_bangs_constant: 'constant bangs', ui_reach: 'up to %d m', ui_decimal: '.'
  };
  let strings = { ...EN };
  const T = (key, ...args) => {
    let text = typeof strings[key] === 'string' ? strings[key] : (EN[key] || key);
    for (const arg of args) text = text.replace(/%[sd]/, String(arg));
    return text;
  };
  const sfx = (kind, options) => { if (!settings.sounds) return; try { if (window.oxlynWorkshopSound) window.oxlynWorkshopSound(kind, options); } catch (_) {} };
  const easeInOut = t => t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  const LEVEL_NAMES = ['Street', 'Sport', 'Extreme', 'Brutal'];
  const RING = 2 * Math.PI * 21;

  // What the mechanic does, in order: label, share of the time, the sound of it.
  // `ratchet` runs for the whole phase, `spool` winds the turbo up and lets it
  // go at the end; the rest sound once when the phase starts.
  const PHASES = {
    install: [['ph_install_1', 0.14, 'clank'], ['ph_install_2', 0.24, 'seat'], ['ph_install_3', 0.22, 'plug'], ['ph_install_4', 0.22, 'ratchet'], ['ph_install_5', 0.18, 'spool']],
    remove: [['ph_remove_1', 0.16, 'spark'], ['ph_remove_2', 0.26, 'ratchet'], ['ph_remove_3', 0.30, 'unplug'], ['ph_remove_4', 0.28, 'clank']],
    exhaust: [['ph_exhaust_1', 0.24, 'ratchet'], ['ph_exhaust_2', 0.18, 'clank'], ['ph_exhaust_3', 0.20, 'seat'], ['ph_exhaust_4', 0.24, 'ratchet'], ['ph_exhaust_5', 0.14, 'hiss']]
  };
  // Hearing a level before choosing it: a report of its size, for the driver only.
  const PREVIEW = { 1: [['snap', 0.6]], 2: [['bang', 0.6]], 3: [['boom', 0.7]], 4: [['boom', 0.75], ['bang', 0.6, 140]] };

  let state = null, frame = 0, hideTimer = 0, previewTimers = [];

  function applySettings(s) {
    settings.sounds = s.sounds !== false;
    settings.preview = s.preview !== false;
    root.style.zoom = String(clamp(Number(s.scale) || 1, 0.8, 1.4));
    root.classList.toggle('top', s.position === 'top');
  }

  const iconFor = item => typeof item === 'string' && /^[a-z0-9_]+$/i.test(item) ? `img/${item}.png` : null;
  function iconHtml(item, ring) {
    const src = iconFor(item);
    const circle = ring ? `<svg class="wb-ring" viewBox="0 0 48 48" aria-hidden="true"><circle class="wb-ring-bg" cx="24" cy="24" r="21"/>
      <circle class="wb-ring-fg" cx="24" cy="24" r="21" style="stroke-dasharray:${RING.toFixed(2)};stroke-dashoffset:${RING.toFixed(2)}"/></svg>` : '';
    return `<div class="wb-icon ${ring ? 'ringed' : ''}">${circle}${src ? `<img src="${src}" alt="" draggable="false">` : '<i class="wb-dot"></i>'}</div>`;
  }
  function titleFor(m) {
    if (m.mode === 'install') return T('ui_title_install');
    if (m.mode === 'remove') return T('ui_title_remove');
    if (m.mode === 'tune') return T('ui_title_tune');
    return m.exhaustLabel ? T('ui_title_exhaust', m.exhaustLabel) : (m.label || T('ui_title_exhaust', ''));
  }
  function describe(level) {
    const heavy = Number(level.heavyChance), radius = Number(level.radius);
    const odds = !Number.isFinite(heavy) ? '' : heavy < 0.2 ? T('ui_bangs_rare') : heavy < 0.45 ? T('ui_bangs_some')
      : heavy < 0.7 ? T('ui_bangs_limiter') : T('ui_bangs_constant');
    return { odds, reach: Number.isFinite(radius) ? T('ui_reach', Math.round(radius)) : '' };
  }
  const seconds = ms => `${(Math.max(0, ms) / 1000).toFixed(1).replace('.', T('ui_decimal'))} s`;
  const key = k => `<kbd class="wb-key">${esc(k)}</kbd>`;

  function card(html, cls) {
    root.innerHTML = `<div class="wb-glow"></div><div class="wb ${cls || ''}">${html}</div>`;
    root.hidden = false;
    void root.offsetWidth;
    root.classList.add('shown');
  }
  function stopWork() {
    cancelAnimationFrame(frame); frame = 0;
    for (const timer of previewTimers) clearTimeout(timer);
    previewTimers = [];
    sfx('ratchet', { on: false }); sfx('spool', { level: 0 });
  }
  function setAccent(colour, fallback) {
    const parts = rgb(colour);
    root.style.setProperty('--accent', parts ? `rgb(${parts.join(', ')})` : fallback);
    root.style.setProperty('--accent-soft', parts ? `rgba(${parts.join(', ')}, 0.16)` : fallback.replace('rgb(', 'rgba(').replace(')', ', 0.16)'));
  }

  // The bar. Its progress is the sum of the phases, each eased on its own, so
  // the fill works in strokes and still lands on 100% exactly when the time is up.
  function open(m) {
    clearTimeout(hideTimer); stopWork();
    const total = Number(m.seconds) > 0 ? Number(m.seconds) * 1000 : 0;
    state = { token: m.token, mode: m.mode, seconds: total / 1000, share: 0, item: m.item, phase: -1, returned: m.returned, consumed: m.consumed };
    setAccent(m.colour, m.mode === 'remove' ? 'rgb(255, 84, 98)' : 'rgb(55, 214, 122)');
    if (total === 0) return; // the tuning goes straight to the levels
    const phases = PHASES[m.mode] || PHASES.exhaust;
    const sum = phases.reduce((acc, phase) => acc + phase[1], 0);
    const bounds = []; let acc = 0;
    for (const phase of phases) { bounds.push([acc / sum, (acc + phase[1]) / sum]); acc += phase[1]; }
    const note = m.returned ? esc(T('ui_you_receive', m.returned)) : (m.consumed ? esc(T('ui_spends', m.consumed)) : '');
    card(`
      <div class="wb-head">${iconHtml(m.item, true)}
        <div class="wb-text"><div class="wb-title">${esc(titleFor(m))}</div>
          <div class="wb-phase"><span class="wb-step">1/${phases.length}</span><span class="wb-phase-text">${esc(T(phases[0][0]))}</span></div></div>
        <div class="wb-num"><b class="wb-pct">0<i>%</i></b><span class="wb-eta">${seconds(total)}</span></div></div>
      <div class="wb-track"><div class="wb-ticks">${bounds.slice(1).map(b => `<i style="left:${(b[0] * 100).toFixed(2)}%"></i>`).join('')}</div><div class="wb-fill"></div></div>
      <div class="wb-foot"><span class="wb-note">${note}</span><span class="wb-keys">${key('Backspace')} ${esc(T('ui_cancel'))}</span></div>`);
    const fill = root.querySelector('.wb-fill'), pct = root.querySelector('.wb-pct'), eta = root.querySelector('.wb-eta');
    const step = root.querySelector('.wb-step'), text = root.querySelector('.wb-phase-text'), ring = root.querySelector('.wb-ring-fg');
    const started = performance.now();
    let lastSpool = 0;
    const enter = index => {
      const [label, , sound] = phases[index];
      step.textContent = `${index + 1}/${phases.length}`;
      text.textContent = T(label);
      text.classList.remove('wb-phase-text'); void text.offsetWidth; text.classList.add('wb-phase-text');
      sfx('ratchet', { on: sound === 'ratchet', level: 0.55 });
      if (sound === 'spool') sfx('spool', { level: 0.05 });
      else if (sound !== 'ratchet') sfx(sound, { level: 0.9 });
    };
    const leave = index => {
      if (phases[index][2] === 'spool') { sfx('spool', { level: 0 }); sfx('air', { level: 0.8 }); }
    };
    const loop = now => {
      if (!state) return;
      const t = clamp((now - started) / total, 0, 1);
      let index = Math.min(phases.length - 1, bounds.findIndex(b => t < b[1]));
      if (index < 0) index = phases.length - 1;
      if (index !== state.phase) {
        if (state.phase >= 0) leave(state.phase);
        state.phase = index; enter(index);
      }
      const [from, to] = bounds[index];
      const inside = to > from ? clamp((t - from) / (to - from), 0, 1) : 1;
      const share = t >= 1 ? 1 : from + (to - from) * easeInOut(inside);
      state.share = share;
      fill.style.width = `${(share * 100).toFixed(2)}%`;
      if (ring) ring.style.strokeDashoffset = (RING * (1 - share)).toFixed(2);
      pct.innerHTML = `${Math.floor(share * 100)}<i>%</i>`;
      eta.textContent = seconds(total - (now - started));
      if (phases[index][2] === 'spool' && now - lastSpool > 60) { lastSpool = now; sfx('spool', { level: 0.05 + 0.95 * inside }); }
      if (t < 1) frame = requestAnimationFrame(loop);
      else { frame = 0; leave(index); sfx('ratchet', { on: false }); root.classList.add('done'); }
    };
    frame = requestAnimationFrame(loop);
  }

  // The level selector. The game reads the keys: the number keys or the arrows
  // move through the levels, Enter (or the same number again) confirms.
  function pick(m) {
    if (!state || m.token !== state.token) return;
    stopWork();
    const levels = Array.isArray(m.levels) && m.levels.length 
      ? m.levels.map((item, idx) => {
          if (typeof item === 'object' && item !== null) {
            return {
              level: Number(item.level) || (idx + 1),
              name: item.name || LEVEL_NAMES[idx] || String(idx + 1),
              heavyChance: item.heavyChance != null ? item.heavyChance : [0.12, 0.35, 0.58, 0.85][idx],
              radius: item.radius != null ? item.radius : [90, 175, 300, 320][idx]
            };
          }
          return {
            level: idx + 1,
            name: typeof item === 'string' && item ? item : (LEVEL_NAMES[idx] || String(idx + 1)),
            heavyChance: [0.12, 0.35, 0.58, 0.85][idx] || 0.5,
            radius: [90, 175, 300, 320][idx] || 200
          };
        })
      : [1, 2, 3, 4].map((n, idx) => ({ level: n, name: LEVEL_NAMES[n - 1], heavyChance: [0.12, 0.35, 0.58, 0.85][idx], radius: [90, 175, 300, 320][idx] }));
    const current = Number(m.level) >= 1 ? Number(m.level) : null;
    state.levels = levels; state.current = current; state.selected = null;
    const count = levels.length;
    card(`
      <div class="wb-head">${iconHtml(state.item, false)}
        <div class="wb-text"><div class="wb-title">${esc(T('ui_power_level'))}</div>
          <div class="wb-phase"><span class="wb-phase-text">${current ? esc(T('ui_installed_is', levels.find(l => l.level === current)?.name || current)) + ' ' : ''}${esc(T('ui_choose'))}</span></div></div></div>
      <div class="wb-levels" style="grid-template-columns: repeat(${count}, 1fr)">${levels.map(l => {
        const { odds, reach } = describe(l);
        return `<div class="wb-level ${current === l.level ? 'on' : ''}" data-level="${esc(l.level)}">
          <div class="wb-level-top">${key(l.level)}${current === l.level ? `<span class="wb-tag">${esc(T('ui_installed'))}</span>` : ''}</div>
          <b>${esc(l.name)}</b>
          <i class="wb-meter">${levels.map((_, k) => `<s class="${k < l.level ? 'on' : ''}"></s>`).join('')}</i>
          <small>${esc(odds)}</small><small class="dim">${esc(reach)}</small></div>`; }).join('')}</div>
      <div class="wb-foot"><span class="wb-note"></span><span class="wb-keys">${key('←')}${key('→')} ${esc(T('ui_or'))} ${key('1')}–${key(count)} ${esc(T('ui_choose_key'))} · ${key('Enter')} ${esc(T('ui_confirm'))} · ${key('Backspace')} ${esc(T('ui_cancel'))}</span></div>`, 'wb-pick');
    sfx('beep', { level: 0.6 });
  }

  // The selection moved (from the game's keys): light it, say what it is, let it be heard.
  function select(m) {
    if (!state || m.token !== state.token || !state.levels) return;
    const level = Number(m.level);
    if (!Number.isFinite(level)) return;
    state.selected = level;
    for (const node of root.querySelectorAll('.wb-level')) node.classList.toggle('sel', Number(node.dataset.level) === level);
    const chosen = state.levels.find(l => l.level === level);
    const sub = root.querySelector('.wb-phase-text'), note = root.querySelector('.wb-note');
    if (chosen && sub) {
      const { odds, reach } = describe(chosen);
      sub.textContent = `${chosen.name}${odds ? `: ${odds}` : ''}${reach ? `, ${reach}` : ''}.`;
      sub.classList.remove('wb-phase-text'); void sub.offsetWidth; sub.classList.add('wb-phase-text');
    }
    if (note) note.textContent = state.current === level ? T('ui_is_installed') : '';
    if (m.preview === true) {
      for (const timer of previewTimers) clearTimeout(timer);
      previewTimers = [];
      sfx('click', { level: 0.5 });
      if (settings.preview) {
        for (const [sound, level_, at] of PREVIEW[Math.min(4, Math.max(1, level))] || []) {
          previewTimers.push(setTimeout(() => sfx(sound, { level: level_ }), 40 + (at || 0)));
        }
      }
    }
  }

  // Enter was pressed: the chosen level lights up while the server applies it.
  function wait(m) {
    if (!state || m.token !== state.token) return;
    const selected = Number(m.selected);
    const picked = root.querySelector('.wb-pick');
    if (picked && Number.isFinite(selected)) {
      picked.classList.add('wait');
      for (const node of picked.querySelectorAll('.wb-level')) {
        node.classList.toggle('pick', Number(node.dataset.level) === selected); node.classList.remove('sel');
      }
      const title = picked.querySelector('.wb-title'), sub = picked.querySelector('.wb-phase-text'), foot = picked.querySelector('.wb-foot');
      const name = state.levels?.find(l => l.level === selected)?.name || selected;
      if (title) title.textContent = T('ui_applying', selected);
      if (sub) sub.textContent = T('ui_saving', name);
      if (foot) foot.innerHTML = '<span class="wb-note"></span><span class="wb-spin"></span>';
      sfx('beep2', { level: 0.6 });
      return;
    }
    card(`<div class="wb-head">${iconHtml(state.item, false)}<div class="wb-text"><div class="wb-title">${esc(T('ui_applying', selected || ''))}</div></div><div class="wb-num"><span class="wb-spin"></span></div></div>`);
  }

  function result(m) {
    if (!state) return;
    stopWork();
    root.classList.remove('done');
    const ok = m.result === true;
    const mark = ok
      ? '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.2 4.2L19 7.5"/></svg>'
      : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7l10 10M17 7L7 17"/></svg>';
    const details = m.details && typeof m.details === 'object' ? m.details : {};
    const sub = esc(ok
      ? (details.mode === 'exhaust' ? T('ui_exhaust_done')
        : details.mode === 'remove' ? T('ui_remove_done')
          : details.level ? T('ui_antilag_ready', details.level) : T('ui_ready'))
      : T('ui_nothing_spent'));
    const receipt = ok ? [details.consumed ? esc(T('ui_spent', details.consumed)) : '', details.returned ? esc(T('ui_received', details.returned)) : ''].filter(Boolean).join(' · ') : '';
    card(`
      <div class="wb-head">${iconHtml(state.item, false)}
        <div class="wb-text"><div class="wb-title">${esc(m.message || (ok ? T('ui_done') : T('ui_failed')))}</div>
          <div class="wb-phase"><span class="wb-phase-text">${sub}</span></div></div>
        <div class="wb-mark">${mark}</div></div>
      ${receipt ? `<div class="wb-foot"><span class="wb-note">${receipt}</span></div>` : ''}`, ok ? 'ok' : 'bad');
    sfx(ok ? 'ding' : 'buzz', { level: 1 });
    if (ok && (details.mode === 'install' || details.mode === 'tune')) sfx('air', { level: 0.6 });
    hideTimer = setTimeout(hide, 1700);
  }

  function hide() {
    clearTimeout(hideTimer); stopWork();
    state = null;
    root.classList.remove('shown', 'done');
    setTimeout(() => { if (!state) { root.hidden = true; root.innerHTML = ''; } }, 220);
  }

  window.addEventListener('message', event => {
    const m = event.data;
    if (!m || typeof m !== 'object') return;
    if (m.action === 'ui') { if (m.settings && typeof m.settings === 'object') applySettings(m.settings); return; }
    if (m.action === 'locale') { if (m.strings && typeof m.strings === 'object') strings = { ...EN, ...m.strings }; return; }
    if (m.action !== 'workshop') return;
    if (m.open === true) open(m);
    else if (m.open === false) hide();
    else if (m.pick === true) pick(m);
    else if (m.select === true) select(m);
    else if (m.wait === true) wait(m);
    else if ('result' in m) result(m);
  });
  if (window.__oxlynTest) window.__workshop = { state: () => state, phases: PHASES, settings, T };
})();
