/* Oxlyn Pops & Bangs: layered exhaust one-shots, anti-lag and turbo, in 3D.
 * GTA (x, y, z-up) -> Web Audio (x, z, -y). No focus or external requests.
 * Dry signal is positioned with HRTF; every voice also feeds one shared
 * environment reverb whose character follows the listener's surroundings.
 * The reverb send is taken before the panner: a room answers from every
 * direction, and its level falls with distance far more slowly than the report.
 *
 * Sources are positioned relative to the listener, which stays at the origin.
 * Moving both through world space with separately smoothed parameters made a
 * fast car's exhaust wander around its own camera.
 *
 * The room belongs to the report, not to the listener's present: each voice
 * feeds the rooms it was fired in, and their tails ring out whatever the
 * listener does next. Which rooms those are comes from the measured space
 * (ceiling height, width, length), around the listener and around the car.
 *
 * No report plays twice the same way. Each one is a take of its family plus
 * smaller layers from other takes, coloured by its own EQ, pitched by the
 * engine and by the motion between car and listener, and duller from ahead
 * of the car than from behind the pipe. All of it derives from the shared
 * pulse, so every listener hears the same report from where they stand.
 */
(() => {
  'use strict';

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  const number = (value, fallback, min, max) => typeof value === 'number' && Number.isFinite(value)
    ? clamp(value, min, max) : fallback;
  const vector = value => value && ['x', 'y', 'z'].every(axis =>
    typeof value[axis] === 'number' && Number.isFinite(value[axis]) && Math.abs(value[axis]) < 100000);
  const web = v => ({ x: v.x, y: v.z, z: -v.y });
  const length = v => Math.hypot(v.x, v.y, v.z);
  const unit = v => { const n = length(v); return { x: v.x / n, y: v.y / n, z: v.z / n }; };
  const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
  const random = seed => {
    let state = (seed >>> 0) || 0x6d2b79f5;
    return () => {
      state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
      return (state >>> 0) / 4294967296;
    };
  };

  // Neighbouring seeds must not give neighbouring draws: pulses of one burst
  // have seeds a fixed step apart.
  const mix = seed => {
    let h = seed >>> 0;
    h ^= h >>> 16; h = Math.imul(h, 0x85ebca6b); h ^= h >>> 13; h = Math.imul(h, 0xc2b2ae35); h ^= h >>> 16;
    return h >>> 0;
  };

  const config = { masterVolume: 0.8, maxVoices: 32, speedOfSound: 343, audioLeadMs: 0, maxLateMs: 140,
    reverb: true, reverbLevel: 1, doppler: 1, colourDb: 3, whoosh: 1, hiss: 1, thump: 1, ticks: 1,
    reflections: 1, flutter: 1 };
  // Reports, and what surrounds them: the rush of the flame, steam, cooling metal.
  const kinds = ['snap', 'crackle', 'bang', 'burble', 'boom', 'pop', 'whoosh', 'hiss', 'tick'];
  const reports = ['snap', 'crackle', 'bang', 'burble', 'boom'];
  // Relative level of each kind at the same energy; body is its EQ weight.
  const loudness = { snap: 0.88, crackle: 0.64, bang: 1.35, burble: 0.74, boom: 1.9 };
  const bodyWeight = { snap: 0.4, crackle: 0.4, bang: 3.0, burble: 1.2, boom: 3.8 };
  const emptyBanks = () => Object.fromEntries(kinds.map(kind => [kind, []]));
  const bundledSamples = Object.fromEntries(kinds.filter(kind => kind !== 'pop').map(kind =>
    [kind, [1, 2, 3, 4, 5, 6].map(index => `sounds/${kind}_0${index}.wav`)]));
  let ctx, master, reverb, warned = false, lastResume = -Infinity, resumePending = false;
  let listener = { position: { x: 0, y: 0, z: 0 }, forward: { x: 0, y: 1, z: 0 }, up: { x: 0, y: 0, z: 1 },
    velocity: { x: 0, y: 0, z: 0 }, muted: true };
  let environment = { enclosure: 0.25, roof: 0, wallMs: 60, interior: false, height: 0, width: 0, length: 0, walls: [] };
  // Room levels. Echo belongs to roofed spaces; streets keep a short, quiet tail
  // and open ground only a late, dark rumble. Calibrated by rendering the graph
  // offline: at 8 m a report's tail sits ~25 dB higher in a tunnel than on open
  // ground, and a street stays as dry as it was in 4.2.
  const roomGain = { open: 0.07, urban: 0.12, tunnel: 2.4, hall: 2.0, booth: 1.7, underpass: 1.05, cabin: 1.1 };
  //   seconds, T60 (s), brightness (Hz), density, build-up (s), echoes [[s, level]]
  const roomSpecs = {
    // Open ground: nothing close, only a late, dark rumble from terrain and far buildings.
    open: { seed: 524, shape: [2.4, 1.8, 1100, 0.25, 0.16, [[0.34, 0.30], [0.78, 0.18], [1.35, 0.10]]] },
    urban: { seed: 655, delay: true, shape: [1.5, 1.2, 3200, 0.65, 0, [[0.09, 0.22], [0.17, 0.14]]] },
    // Tunnel: long, dense and bright, with reflections running down the bore.
    tunnel: { seed: 786, delay: true, shape: [3.6, 3.0, 5600, 1.0, 0, [[0.022, 0.45], [0.048, 0.40], [0.083, 0.36],
      [0.13, 0.32], [0.19, 0.28], [0.27, 0.22], [0.37, 0.17]]] },
    // Workshop, parking level, hall: shorter and denser than a tunnel.
    hall: { seed: 524, delay: true, shape: [2.2, 1.8, 6500, 1.0, 0, [[0.012, 0.5], [0.027, 0.4], [0.045, 0.3], [0.07, 0.22]]] },
    // A garage for one or two cars: the walls answer at once and are done within a second.
    booth: { seed: 1201, delay: true, shape: [1.2, 0.85, 7000, 1.0, 0, [[0.006, 0.55], [0.014, 0.45], [0.023, 0.35],
      [0.034, 0.25]]] },
    // Under a bridge: the deck and the abutments slap back, and the open sides let the rest go.
    underpass: { seed: 1409, delay: true, shape: [1.3, 0.75, 4200, 0.45, 0, [[0.030, 0.55], [0.061, 0.34], [0.095, 0.20],
      [0.14, 0.12]]] },
    // Inside the car, windows shut: small, padded and dark.
    cabin: { seed: 1613, shape: [0.35, 0.16, 2600, 1.0, 0, [[0.003, 0.5], [0.007, 0.4]]] }
  };
  const roomNames = Object.keys(roomSpecs);
  const roomT60 = { booth: 0.85, hall: 1.8, tunnel: 3.0 };
  // Early reflections (4.9): the façades the rays found around the listener,
  // each one a discrete echo from its own side. Two facing façades flutter.
  const reflections = { bus: null, walls: [] };
  // A flag or an amount, as 0..1.
  const amount = (value, flag) => typeof value === 'number' && Number.isFinite(value) ? clamp(value, 0, 1)
    : (value === true || flag === true) ? 1 : 0;
  const track = (voice, node) => { if (voice.nodes.add) voice.nodes.add(node); else voice.nodes.push(node); };
  let hasListener = false, sampleRevision = 0, samplesKey = '', sampleController;
  let samples = emptyBanks();
  const voices = new Set(), epochs = new Map(), buffers = new Map(), antiLagVoices = new Map(), antiLagSequences = new Map();
  const orphans = new Set(), turboVoices = new Map();
  let antiLagSamples = {}, antiLagSamplesKey = '', antiLagRevision = 0, antiLagController, turboNoise;
  const antiLagConfig = { maxVehicles: 8, watchdogMs: 450, volume: 1,
    turbo: { enabled: true, volume: 0.5, flutter: true, blowOff: true } };

  function param(parameter, value, time, smooth = 0) {
    if (!parameter) return;
    parameter.cancelScheduledValues(time);
    if (smooth > 0) parameter.setTargetAtTime(value, time, smooth);
    else parameter.setValueAtTime(value, time);
  }

  function finish(voice) {
    if (!voices.delete(voice)) return;
    clearTimeout(voice.timer);
    try { voice.source.stop(); } catch (_) { /* A source may already have ended. */ }
    for (const layer of voice.layers || []) { try { layer.source.stop(); } catch (_) {} }
    for (const node of voice.nodes) { try { node.disconnect(); } catch (_) {} }
  }

  function clearVoices() {
    for (const voice of Array.from(voices)) finish(voice);
    for (const voice of Array.from(antiLagVoices.values())) finishAntiLag(voice);
    for (const voice of Array.from(orphans)) finishAntiLag(voice);
    for (const voice of Array.from(turboVoices.values())) finishTurbo(voice);
  }

  // World -> listener space (x right, y up, z towards the listener's back).
  function relative(v, offset) {
    const f = listener.forward, u = listener.up;
    const r = { x: f.y * u.z - f.z * u.y, y: f.z * u.x - f.x * u.z, z: f.x * u.y - f.y * u.x };
    const d = offset ? { x: v.x - listener.position.x, y: v.y - listener.position.y, z: v.z - listener.position.z } : v;
    return { x: d.x * r.x + d.y * r.y + d.z * r.z, y: d.x * u.x + d.y * u.y + d.z * u.z,
      z: -(d.x * f.x + d.y * f.y + d.z * f.z) };
  }

  function spatialPosition(voice, position, direction, smooth = 0) {
    voice.position = { ...position };
    const p = relative(position, true), at = ctx.currentTime, panner = voice.panner;
    if (panner.positionX) {
      for (const axis of ['X', 'Y', 'Z']) param(panner[`position${axis}`], p[axis.toLowerCase()], at, smooth);
    } else panner.setPosition(p.x, p.y, p.z);
    if (vector(direction) && length(direction) > 0.01) {
      voice.direction = unit(direction);
      const d = relative(voice.direction, false);
      if (panner.orientationX) {
        for (const axis of ['X', 'Y', 'Z']) param(panner[`orientation${axis}`], d[axis.toLowerCase()], at, smooth);
      } else if (panner.setOrientation) panner.setOrientation(d.x, d.y, d.z);
      panner.coneInnerAngle = 140; panner.coneOuterAngle = 285; panner.coneOuterGain = 0.58;
    } else if (!voice.direction) {
      // Unknown orientation must not point an arbitrary cone at a world axis.
      panner.coneInnerAngle = 360; panner.coneOuterAngle = 360; panner.coneOuterGain = 1;
    }
  }

  // Pitch of a moving source heard by a moving listener. Only the motion along
  // the line between them counts: a car passing by drops in pitch, the driver's
  // own exhaust, travelling with the camera, does not change at all.
  function dopplerFactor(position, velocity) {
    if (config.doppler <= 0 || !vector(velocity)) return 1;
    const d = { x: listener.position.x - position.x, y: listener.position.y - position.y, z: listener.position.z - position.z };
    const n = length(d);
    if (n < 1.5) return 1;
    const approach = (velocity.x * d.x + velocity.y * d.y + velocity.z * d.z) / n;
    const retreat = (listener.velocity.x * d.x + listener.velocity.y * d.y + listener.velocity.z * d.z) / n;
    const factor = (config.speedOfSound - retreat) / Math.max(60, config.speedOfSound - approach);
    return clamp(1 + (factor - 1) * config.doppler, 0.84, 1.19);
  }

  function applyDoppler(voice, velocity, smooth = 0.05) {
    if (velocity !== undefined) voice.velocity = vector(velocity) ? { ...velocity } : null;
    const factor = dopplerFactor(voice.position, voice.velocity);
    voice.doppler = factor;
    if (!voice.source) return;
    const at = ctx.currentTime;
    param(voice.source.playbackRate, voice.rate * factor, at, smooth);
    for (const layer of voice.layers || []) param(layer.source.playbackRate, layer.rate * factor, at, smooth);
  }

  function setupPanner(panner, maxDistance) {
    panner.panningModel = 'HRTF'; panner.distanceModel = 'inverse';
    panner.refDistance = 2.4; panner.rolloffFactor = 0.78; panner.maxDistance = maxDistance;
  }

  function resume() {
    if (!ctx || ctx.state === 'running' || ctx.state === 'closed' || resumePending) return;
    const now = performance.now();
    if (now - lastResume < 500) return;
    lastResume = now; resumePending = true;
    Promise.resolve(ctx.resume()).catch(() => {}).finally(() => {
      resumePending = false;
      if (ctx.state !== 'running' && !warned) {
        warned = true;
        console.warn('[oxlyn-popsbangs] NUI audio is suspended; retrying on subsequent game messages.');
      }
    });
  }

  // Decaying noise that darkens as it decays, plus discrete echoes. Each channel
  // is generated separately, so the tail is wide around a mono send.
  //   seconds, T60 (s), brightness (Hz), density, build-up (s), echoes [[s, level]]
  function impulse(spec, seed) {
    const [seconds, t60, brightness, density, build, echoes] = spec;
    const rate = ctx.sampleRate, n = Math.ceil(seconds * rate);
    const buffer = ctx.createBuffer(2, n, rate);
    for (let channel = 0; channel < 2; channel++) {
      const rng = random(seed * 31 + channel * 977 + 5), data = buffer.getChannelData(channel);
      let low = 0;
      for (let i = 0; i < n; i++) {
        const t = i / rate;
        // Reflections arrive sparsely at first and merge into a diffuse field.
        const chance = Math.min(1, density * (0.04 + t * 3.2));
        const excitation = rng() < chance ? (rng() * 2 - 1) / Math.sqrt(chance) : 0;
        const cutoff = brightness * Math.exp(-t * 1.9) + 420;
        low += (1 - Math.exp(-2 * Math.PI * cutoff / rate)) * (excitation - low);
        const rise = build > 0 ? 1 - Math.exp(-t / build) : Math.min(1, t / 0.012);
        data[i] = low * Math.pow(10, -3 * t / t60) * rise;
      }
      for (const [time, level] of echoes) {
        const start = Math.floor((time * (channel ? 1.09 : 0.94)) * rate), size = Math.floor(0.004 * rate);
        let smooth = 0;
        for (let i = 0; i < size && start + i < n; i++) {
          smooth += 0.28 * ((rng() * 2 - 1) - smooth);
          data[start + i] += smooth * level * 4 * Math.sin(Math.PI * i / size);
        }
      }
      let energy = 0;
      for (let i = 0; i < n; i++) energy += data[i] * data[i];
      const gain = 1 / Math.sqrt(Math.max(1e-9, energy));
      for (let i = 0; i < n; i++) data[i] *= gain;
    }
    return buffer;
  }

  // Every room is always there at its own level. What decides how much of a
  // room is heard is how much each voice sends into it, and that is settled
  // when the report is fired: leaving a tunnel does not cut off its tail.
  function buildReverb() {
    const output = ctx.createGain(), clean = ctx.createBiquadFilter();
    clean.type = 'highpass'; clean.frequency.value = 90; clean.Q.value = 0.6;
    const rooms = {};
    for (const [name, spec] of Object.entries(roomSpecs)) {
      const input = ctx.createGain(), convolver = ctx.createConvolver(), level = ctx.createGain();
      // Sends arrive mono; the stereo room around them comes from the two IR channels.
      input.channelCount = 1; input.channelCountMode = 'explicit'; input.channelInterpretation = 'speakers';
      convolver.normalize = false;
      convolver.buffer = impulse(spec.shape, spec.seed);
      level.gain.value = roomGain[name];
      let delay = null;
      if (spec.delay) {
        // Walls set the pre-delay of a room; open ground has its own late build-up.
        delay = ctx.createDelay(0.5); delay.delayTime.value = 0.03;
        input.connect(delay); delay.connect(convolver);
      } else input.connect(convolver);
      convolver.connect(level); level.connect(clean);
      rooms[name] = { input, delay, level };
    }
    clean.connect(output); output.connect(ctx.oxlynInput);
    reverb = { output, rooms };
    applyEnvironment(true);
  }

  // What the rays measured, as the rooms it sounds like: a weight per room, and
  // `roofed`, how much of a roof there is.
  function roomWeights(env) {
    const weights = { open: 0, urban: 0, tunnel: 0, hall: 0, booth: 0, underpass: 0, cabin: 0, roofed: 0 };
    // Buildings along a street are not a room. Only a roof turns walls into an
    // echo; without one, even a narrow street keeps a short, quiet tail.
    const roofed = clamp((env.roof - 0.35) / 0.65, 0, 1);
    // Walls on most sides make it a room; a roof over open sides is a bridge.
    const walled = env.interior ? 1 : clamp((env.enclosure - 0.30) / 0.35, 0, 1);
    const enclosed = roofed * walled, under = roofed - enclosed;
    if (enclosed > 0) {
      let t60 = env.interior ? roomT60.hall : roomT60.tunnel; // without measurements: as before 4.6
      if (env.height > 0 && env.width > 0) {
        const h = clamp(env.height, 2, 22), w = clamp(env.width, 2, 90), l = clamp(Math.max(env.length, w), 2, 60);
        // The mean free path between two reflections sets how long a space rings.
        t60 = clamp(0.45 * 4 * h * w * l / (2 * (h * w + h * l + w * l)), 0.7, 3.2);
        // What is open to the sides lets the sound out instead of sending it back.
        t60 = 0.8 + (t60 - 0.8) * walled;
      }
      const [small, large, mix] = t60 <= roomT60.hall
        ? ['booth', 'hall', (t60 - roomT60.booth) / (roomT60.hall - roomT60.booth)]
        : ['hall', 'tunnel', (t60 - roomT60.hall) / (roomT60.tunnel - roomT60.hall)];
      // Two rooms of unrelated reflections add in power, not in level.
      const angle = clamp(mix, 0, 1) * Math.PI / 2;
      weights[small] = enclosed * Math.cos(angle); weights[large] = enclosed * Math.sin(angle);
    }
    // A deck between abutments slaps back; a cover standing alone in the open much less.
    weights.underpass = under * (0.45 + 0.55 * clamp(env.enclosure / 0.30, 0, 1));
    const outside = 1 - enclosed - 0.5 * under, street = clamp((env.enclosure - 0.6) / 0.4, 0, 1);
    weights.urban = outside * street;
    // Buildings hide the distant terrain that makes the open-ground rumble.
    weights.open = outside * (1 - street);
    weights.roofed = roofed;
    return weights;
  }

  // A report fired somewhere else: a room answers fully to what is fired inside
  // it and less to what comes in from outside, and a listener outside still
  // hears the room around the car ring.
  function sharedWeights(own, source) {
    const weights = { ...own };
    for (const name of ['tunnel', 'hall', 'booth', 'underpass']) {
      weights[name] = own[name] * (0.4 + 0.6 * source.roofed) + source[name] * 0.5 * (1 - own.roofed);
    }
    return weights;
  }

  // The walls the rays hit: direction (0-7), distance, how much and how brightly
  // they answer, how tall they are, and the point on them.
  function readWalls(value) {
    if (!Array.isArray(value)) return [];
    const walls = [];
    for (const wall of value.slice(0, 8)) {
      if (!wall || !Number.isSafeInteger(wall.a) || wall.a < 0 || wall.a > 7 || !vector(wall)) continue;
      const d = number(wall.d, 0, 0, 60);
      if (d < 0.5 || walls.some(other => other.a === wall.a)) continue;
      walls.push({ a: wall.a, d, hard: number(wall.h, 0.75, 0, 1), bright: number(wall.b, 0.85, 0.2, 1.3),
        tall: Math.floor(number(wall.t, 0, 0, 2)), point: { x: wall.x, y: wall.y, z: wall.z } });
    }
    return walls;
  }

  function readEnvironment(value, fallback) {
    return { enclosure: number(value.enclosure, fallback.enclosure, 0, 1), roof: number(value.roof, fallback.roof, 0, 1),
      wallMs: number(value.wallMs, fallback.wallMs, 5, 400), interior: value.interior === true,
      height: number(value.height, 0, 0, 60), width: number(value.width, 0, 0, 200), length: number(value.length, 0, 0, 200),
      walls: 'walls' in value ? readWalls(value.walls) : (fallback.walls || []) };
  }

  // Eight echo paths, one per direction the rays look in. A path is a delay
  // (there and back), the air and the surface (a lowpass), its level and a
  // panner at the point on the wall, so the slap comes from that side. Facing
  // walls are joined by a loop as long as the street is wide: the bang runs
  // between them and dies out, as it does between buildings.
  function buildReflections() {
    const bus = ctx.createGain();
    bus.channelCount = 1; bus.channelCountMode = 'explicit'; bus.channelInterpretation = 'speakers';
    const walls = [];
    for (let index = 0; index < 8; index++) {
      const delay = ctx.createDelay(0.6), filter = ctx.createBiquadFilter(), level = ctx.createGain();
      const panner = ctx.createPanner(), feedback = ctx.createGain(), loop = ctx.createDelay(0.7);
      filter.type = 'lowpass'; filter.Q.value = 0.5; filter.frequency.value = 6000;
      delay.delayTime.value = 0.05; loop.delayTime.value = 0.1; level.gain.value = 0; feedback.gain.value = 0;
      // The level is set here; the panner only gives the echo its side.
      panner.panningModel = 'HRTF'; panner.distanceModel = 'inverse'; panner.refDistance = 1;
      panner.rolloffFactor = 0; panner.maxDistance = 1000;
      panner.coneInnerAngle = 360; panner.coneOuterAngle = 360; panner.coneOuterGain = 1;
      bus.connect(delay); delay.connect(filter); filter.connect(level); level.connect(panner); panner.connect(ctx.oxlynInput);
      filter.connect(feedback); feedback.connect(loop); loop.connect(filter);
      walls.push({ delay, filter, level, panner, feedback, loop, point: null, active: false, gain: 0, flutter: 0 });
    }
    reflections.bus = bus; reflections.walls = walls;
    applyReflections(true);
  }

  function positionReflections(smooth = 0) {
    if (!reflections.bus) return;
    const at = ctx.currentTime;
    for (const wall of reflections.walls) {
      if (!wall.point) continue;
      const p = relative(wall.point, true), panner = wall.panner;
      if (panner.positionX) {
        for (const axis of ['X', 'Y', 'Z']) param(panner[`position${axis}`], p[axis.toLowerCase()], at, smooth);
      } else panner.setPosition(p.x, p.y, p.z);
    }
  }

  function applyReflections(immediate = false) {
    if (!reflections.bus) return;
    const at = ctx.currentTime, smooth = immediate ? 0 : 0.25;
    const walls = environment.walls || [];
    // Inside a room the convolver already carries the early reflections.
    const roofed = clamp((environment.roof - 0.35) / 0.65, 0, 1);
    const walled = environment.interior ? 1 : clamp((environment.enclosure - 0.30) / 0.35, 0, 1);
    const open = 1 - 0.6 * roofed * walled;
    for (let index = 0; index < 8; index++) {
      const node = reflections.walls[index], wall = walls.find(w => w.a === index);
      if (!wall || config.reflections <= 0) {
        node.active = false; node.gain = 0; node.flutter = 0;
        param(node.level.gain, 0, at, smooth); param(node.feedback.gain, 0, at, smooth);
        continue;
      }
      node.active = true; node.point = wall.point;
      // There and back: the listener stands about where the report is fired.
      param(node.delay.delayTime, clamp(2 * wall.d / config.speedOfSound, 0.012, 0.55), at, smooth);
      // Against the direct report: a hard wall 8 m away answers about 15 dB under it.
      node.gain = config.reflections * wall.hard * Math.min(0.5, 3.0 / (2 * wall.d)) * open;
      param(node.level.gain, node.gain, at, smooth);
      // The air and the surface take the crack first; a hedge keeps almost none of it.
      param(node.filter.frequency, clamp(300 + wall.bright * wall.bright * 9000 * Math.exp(-2 * wall.d / 120), 300, 12000), at, smooth);
      // A façade facing another one: the bang runs across the street and back.
      const facing = walls.find(w => w.a === (index + 4) % 8);
      let gain = 0;
      if (facing && config.flutter > 0 && wall.hard >= 0.4 && facing.hard >= 0.4) {
        const width = wall.d + facing.d;
        if (width <= 60) {
          gain = clamp(config.flutter * wall.hard * facing.hard * (0.40 + 0.12 * (wall.tall + facing.tall)) *
            Math.exp(-width / 200), 0, 0.68);
          param(node.loop.delayTime, clamp(2 * width / config.speedOfSound, 0.02, 0.65), at, smooth);
        }
      }
      node.flutter = gain;
      param(node.feedback.gain, gain, at, smooth);
    }
    positionReflections(smooth);
  }

  // A voice feeds the façades at the level its report reaches the listener with:
  // the same fall with distance as the direct sound, so an echo is always heard
  // relative to it, and half as much from inside a shut cabin.
  function connectReflections(voice, weight, d) {
    if (!reflections.bus || config.reflections <= 0 || weight <= 0.01) return;
    const send = ctx.createGain();
    send.gain.value = weight * 2.4 / (2.4 + 0.78 * Math.max(0, d - 2.4)) * (1 - 0.5 * (voice.cabin || 0));
    (voice.sendFrom || voice.gain).connect(send); send.connect(reflections.bus);
    track(voice, send);
    voice.reflect = send;
  }

  function applyEnvironment(immediate = false) {
    applyReflections(immediate);
    if (!reverb) return;
    const at = ctx.currentTime, smooth = immediate ? 0 : 0.25;
    const wall = clamp(environment.wallMs / 1000, 0.008, 0.28);
    for (const name of ['urban', 'tunnel', 'hall', 'booth']) param(reverb.rooms[name].delay.delayTime, wall, at, smooth);
    // Under a bridge the first answer comes from the deck overhead.
    param(reverb.rooms.underpass.delay.delayTime, environment.height > 0
      ? clamp(2 * Math.max(0, environment.height - 1.6) / config.speedOfSound, 0.008, 0.12) : wall, at, smooth);
    param(reverb.output.gain, config.reverb ? config.reverbLevel : 0, at, smooth);
    // Reports already fired keep the rooms they were fired in. What sounds
    // continuously moves through the surroundings with its car.
    for (const voice of antiLagVoices.values()) if (voice.send) routeSend(voice, voiceWeights(voice), immediate);
  }

  function voiceWeights(voice) {
    const own = roomWeights(environment);
    const weights = voice.sourceEnv ? sharedWeights(own, roomWeights(voice.sourceEnv)) : own;
    weights.cabin = voice.cabin || 0;
    return weights;
  }

  function routeSend(voice, weights, immediate) {
    for (const name of roomNames) {
      const weight = weights[name] || 0;
      let node = voice.rooms[name];
      if (!node) {
        if (weight <= 0.004) continue;
        node = ctx.createGain(); node.gain.value = immediate ? weight : 0;
        voice.send.connect(node); node.connect(reverb.rooms[name].input);
        voice.rooms[name] = node; track(voice, node);
        if (immediate) continue;
      }
      param(node.gain, weight, ctx.currentTime, immediate ? 0 : 0.2);
    }
  }

  function ensureContext() {
    if (ctx) { resume(); return ctx; }
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;
    try {
      ctx = new AudioContextClass({ latencyHint: 'interactive' });
      // Slow enough an attack that the first millisecond of a report passes intact.
      const compressor = ctx.createDynamicsCompressor();
      compressor.threshold.value = -5; compressor.knee.value = 6;
      compressor.ratio.value = 3; compressor.attack.value = 0.006; compressor.release.value = 0.12;
      const limiter = ctx.createWaveShaper();
      const curve = new Float32Array(2049);
      for (let i = 0; i < curve.length; i++) {
        const x = i / 1024 - 1, a = Math.abs(x);
        curve[i] = Math.sign(x) * (a <= 0.74 ? a : 0.74 + 0.22 * Math.tanh((a - 0.74) / 0.22));
      }
      limiter.curve = curve; limiter.oversample = '2x';
      master = ctx.createGain(); master.gain.value = listener.muted ? 0 : config.masterVolume;
      compressor.connect(limiter); limiter.connect(master); master.connect(ctx.destination);
      ctx.oxlynInput = compressor;
      ctx.onstatechange = () => { if (ctx.state !== 'running') clearVoices(); };
      try { buildReverb(); } catch (error) {
        reverb = null;
        console.warn('[oxlyn-popsbangs] Environment reverb unavailable:', error.message);
      }
      try { buildReflections(); } catch (error) {
        reflections.bus = null; reflections.walls = [];
        console.warn('[oxlyn-popsbangs] Wall reflections unavailable:', error.message);
      }
      applyListener(); resume();
      return ctx;
    } catch (error) {
      ctx = null;
      if (!warned) { warned = true; console.warn('[oxlyn-popsbangs] Web Audio unavailable:', error.message); }
      return null;
    }
  }

  function applyListener() {
    if (!ctx) return;
    const at = ctx.currentTime;
    param(master.gain, listener.muted ? 0 : config.masterVolume, at, 0.01);
    positionReflections(0.02);
    for (const voice of [...voices, ...antiLagVoices.values(), ...turboVoices.values()]) {
      spatialPosition(voice, voice.position, voice.direction, 0.02);
      updateDistance(voice);
      if (voice.velocity) applyDoppler(voice);
    }
  }

  function updateDistance(voice, immediate = false) {
    const d = distance(listener.position, voice.position);
    if (d >= voice.maxDistance || listener.muted) {
      if (voice.turbo) finishTurbo(voice); else if (voice.continuous) finishAntiLag(voice); else finish(voice);
      return;
    }
    // Inverse PannerNode attenuation has no hard maximum; fade explicitly to zero.
    const fade = 1 - clamp((d / voice.maxDistance - 0.8) / 0.2, 0, 1);
    // Walking behind a wall is not a switch: what is in the way arrives over a few frames.
    const target = voice.occlusion || 0;
    if (immediate || voice.occlusionNow === undefined) voice.occlusionNow = target;
    else voice.occlusionNow += clamp(target - voice.occlusionNow, -0.15, 0.15);
    const occlusion = voice.occlusionNow, cabin = voice.cabin || 0;
    const at = ctx.currentTime;
    param(voice.gain.gain, voice.volume * fade * (1 - 0.57 * occlusion) * (1 - 0.27 * cabin), at, immediate ? 0 : 0.02);
    // An exhaust fires backwards: behind the pipe the crack is whole, ahead of
    // the car its body is in the way. (Inside the cabin that is already counted.)
    let aim = 1;
    if (voice.direction && cabin < 0.5 && !voice.bay && d > 0.5) {
      const cos = (voice.direction.x * (listener.position.x - voice.position.x) +
        voice.direction.y * (listener.position.y - voice.position.y) +
        voice.direction.z * (listener.position.z - voice.position.z)) / d;
      aim = 0.60 + 0.40 * clamp((cos + 1) / 2, 0, 1);
    }
    // Distance removes the crack first and leaves the thump.
    const cutoff = clamp(16000 * Math.exp(-d / 110) * (1 - 0.67 * occlusion) *
      (1 - 0.42 * cabin) * aim, 480, 16000);
    param(voice.filter.frequency, cutoff * voice.brightness, at, immediate ? 0 : 0.035);
    // Close to the pipe a bang is felt in the chest; the weight goes with distance.
    if (voice.thump) {
      param(voice.thump.gain, voice.thumpDb * clamp(1 - d / 35, 0, 1) * (1 - 0.6 * occlusion) * (1 - 0.4 * cabin),
        at, immediate ? 0 : 0.05);
    }
    if (voice.send) {
      // The send is taken before the panner. A room answers from everywhere, so
      // its level falls slowly with distance while the direct report falls fast.
      const wet = voice.wet / (1 + d / 60) * (1 - 0.5 * cabin) * (1 + 0.5 * occlusion);
      param(voice.send.gain, wet, at, immediate ? 0 : 0.04);
    }
  }

  // `weights`: the rooms this voice is heard in. They are taken once for a
  // report; a continuous voice has them brought up to date as its car moves.
  function connectSend(voice, wet, weights) {
    if (!reverb || wet <= 0.001) return;
    voice.send = ctx.createGain(); voice.wet = wet; voice.send.gain.value = wet;
    (voice.sendFrom || voice.gain).connect(voice.send);
    track(voice, voice.send);
    voice.rooms = {};
    routeSend(voice, weights || voiceWeights(voice), true);
  }

  function synthesize(kind, engine, seed) {
    // Fallback, only heard while the bank is missing: turbulent pressure and a
    // short crack. Nothing in it rings at a fixed pitch.
    // Every audible combustion is an explicit scheduled pulse. No hidden secondary
    // pops are baked into this buffer, so the flame timeline cannot drift from it.
    const variation = (seed >>> 0) % 24;
    const key = `${kind}:${engine}:${variation}`;
    if (buffers.has(key)) return buffers.get(key);
    const type = { snap: [0.19, 0.029, 0.005, 0.74], crackle: [0.12, 0.014, 0.0024, 0.51],
      bang: [0.36, 0.080, 0.007, 0.98], burble: [0.25, 0.051, 0.009, 0.62] }[kind === 'boom' ? 'bang' : kind];
    const rng = random(variation * 7919 + kind.charCodeAt(0) * 104729 + engine.charCodeAt(0) * 65537);
    const rate = 48000, duration = type[0];
    const buffer = ctx.createBuffer(1, Math.ceil(rate * duration), rate);
    const data = buffer.getChannelData(0);
    const engineScale = { sport: 1, muscle: 0.78, rotary: 1.22 }[engine];
    let low = 0, mid = 0, dc = 0, peak = 0;
    for (let i = 0; i < data.length; i++) {
      const t = i / rate, noise = rng() * 2 - 1;
      low += (0.020 * engineScale) * (noise - low);
      mid += 0.19 * (noise - mid);
      const crack = (noise - mid) * Math.exp(-t / type[2]);
      const pressure = (low * 4.1 + mid * 0.54) * Math.exp(-t / type[1]);
      const value = pressure + crack * (kind === 'burble' ? 0.22 : 0.95);
      dc += 0.006 * (value - dc);
      const envelope = Math.min(1, t / 0.00065) * Math.min(1, (duration - t) / 0.016);
      data[i] = Math.tanh((value - dc) * 1.15) * envelope;
      peak = Math.max(peak, Math.abs(data[i]));
    }
    for (let i = 0; i < data.length; i++) data[i] *= type[3] * 0.84 / Math.max(0.2, peak);
    if (buffers.size >= 96) buffers.delete(buffers.keys().next().value);
    buffers.set(key, buffer);
    return buffer;
  }

  function validVehicle(value) { return Number.isSafeInteger(value) && value > 0 && value <= 65535; }
  function validEpoch(value) { return Number.isSafeInteger(value) && value >= 0; }
  function markEpoch(vehicle, epoch) {
    if (epochs.size >= 8192 && !epochs.has(vehicle)) epochs.delete(epochs.keys().next().value);
    epochs.set(vehicle, epoch);
  }

  // Every car has its own exhaust: deeper or sharper, fuller or thinner. The
  // game client derives it from the model; a name keeps the three older profiles.
  const namedVoices = { sport: { pitch: 1, body: 280, bright: 1, weight: 0 },
    muscle: { pitch: 0.92, body: 155, bright: 0.84, weight: 0 }, rotary: { pitch: 1.06, body: 430, bright: 1, weight: 0 } };
  function voiceOf(message) {
    const engine = ['sport', 'muscle', 'rotary'].includes(message.engine) ? message.engine : 'sport';
    const named = namedVoices[engine], own = message.voice;
    if (!own || typeof own !== 'object') return { engine, ...named };
    return { engine, pitch: number(own.pitch, named.pitch, 0.8, 1.25), body: number(own.body, named.body, 110, 600),
      bright: number(own.bright, named.bright, 0.7, 1.2), weight: number(own.weight, 0, -3, 3) };
  }

  function soundKind(message) {
    if (reports.includes(message.kind)) return message.kind;
    if (message.heavy === true) return 'bang';
    const alias = { shift: 'snap', downshift: 'crackle', overrun: 'burble', limiter: 'crackle', antilag: 'crackle' }[message.kind];
    return typeof alias === 'string' ? alias : 'snap';
  }

  function play(message) {
    if (!validVehicle(message.vehicle) || !validEpoch(message.epoch) ||
      !Number.isSafeInteger(message.level) || message.level < 1 || message.level > 9 || !vector(message.position)) return;
    const floor = epochs.get(message.vehicle) ?? -1;
    if (message.epoch < floor) return;
    if (message.epoch > floor) {
      markEpoch(message.vehicle, message.epoch);
      for (const old of Array.from(voices)) if (old.vehicle === message.vehicle && old.epoch < message.epoch) finish(old);
      const old = antiLagVoices.get(message.vehicle);
      if (old && old.epoch < message.epoch) finishAntiLag(old);
    }
    if (!hasListener || listener.muted || !ensureContext() || ctx.state !== 'running') return;
    const maxDistance = number(message.maxDistance, 250, 10, 900);
    const d = distance(listener.position, message.position);
    if (d >= maxDistance) return;
    const volume = number(message.volume, 0.8, 0, 1.5);
    if (volume <= 0) return;
    const seed = number(message.seed, 1, 0, 4294967295) >>> 0;
    const kind = soundKind(message), profile = voiceOf(message), engine = profile.engine;
    const rpm = number(message.rpm, 0.65, 0, 1), temperature = number(message.temperature, 0.65, 0, 1);
    const energy = number(message.energy ?? message.intensity, 0.7, 0, 1.5);
    // Phrase timbre comes from the shared pulse, never client-local randomness.
    const tone = number(message.tone, 1, 0.7, 1.25);
    const bodyDb = number(message.bodyDb, 0, -2, 4);
    const tail = number(message.tail, 1, 0.65, 1.25);
    const echoScale = number(message.echoScale, 1, 0.5, 1.15);
    // A server without a boom bank plays its biggest bangs from the bang bank.
    const bank = samples[kind].length ? samples[kind] : kind === 'boom' && samples.bang.length ? samples.bang : samples.pop;
    // The shared combustion engine selects recordings independently of its pulse
    // seed. Sequential seed increments can otherwise select the same six-sample
    // residue repeatedly and collapse a whole phrase onto one recording.
    const sampleIndex = Number.isSafeInteger(message.sampleIndex) && message.sampleIndex >= 1 && message.sampleIndex <= 32
      ? message.sampleIndex - 1 : seed;
    const buffer = bank.length ? bank[sampleIndex % bank.length] : synthesize(kind, engine, seed);
    const enginePitch = profile.pitch;
    // Every report is re-pitched a little, so a take never returns exactly as it was heard.
    const pitchVariation = 1 + (number(message.pitch, 1, 0.7, 1.45) - 1) * 0.55;
    const pitch = clamp(pitchVariation * enginePitch * (0.98 + rpm * 0.03), 0.78, 1.24);
    const velocity = vector(message.velocity) ? { ...message.velocity } : null;
    const doppler = dopplerFactor(message.position, velocity);
    // The pulse's ignition is the shared origin. Travel delay applies once only.
    // A late packet consumes elapsed samples instead of replaying a fresh bang.
    const ignitionDelay = number(message.delayMs, 0, -5000, 3000) / 1000;
    const arrivalDelay = ignitionDelay + (number(message.soundDelayMs, 16, 0, 100) - config.audioLeadMs) / 1000 +
      d / config.speedOfSound;
    const late = Math.max(0, -arrivalDelay);
    const offset = late * pitch;
    // Short phrases release earlier without resampling or moving the ignition.
    // A long tail retains the recording's natural decay; it never loops/extends it.
    const audibleDuration = buffer.duration / pitch * Math.min(1, tail);
    const releaseDuration = tail < 1 ? Math.min(0.045, audibleDuration * 0.30) : 0;
    const releaseAt = audibleDuration - releaseDuration;
    const releaseGain = elapsed => releaseDuration > 0
      ? clamp((audibleDuration - elapsed) / releaseDuration, 0, 1) : 1;
    if (late * 1000 > config.maxLateMs || offset >= buffer.duration - 0.008 ||
      (tail < 1 && late >= audibleDuration - 0.008)) return;
    while (voices.size >= config.maxVoices) finish(voices.values().next().value);
    const source = ctx.createBufferSource(), filter = ctx.createBiquadFilter();
    const body = ctx.createBiquadFilter(), colour = ctx.createBiquadFilter(), gate = ctx.createGain();
    const gain = ctx.createGain(), panner = ctx.createPanner();
    const loud = kind === 'bang' || kind === 'boom';
    const thump = loud && config.thump > 0 ? ctx.createBiquadFilter() : null;
    source.buffer = buffer; source.playbackRate.value = pitch * doppler;
    filter.type = 'lowpass'; filter.Q.value = 0.55;
    body.type = 'peaking'; body.frequency.value = profile.body;
    body.Q.value = 0.7;
    body.gain.value = bodyWeight[kind] + bodyDb + profile.weight;
    if (thump) { thump.type = 'lowshelf'; thump.frequency.value = 100; thump.gain.value = 0; }
    // One broad band, placed and weighted by the pulse seed: the same take
    // never has quite the same colour. Too broad and too shallow to ring.
    const shade = random(mix(seed ^ 0x9e3779b9));
    colour.type = 'peaking'; colour.Q.value = 0.8;
    colour.frequency.value = 350 * Math.pow(3200 / 350, shade());
    colour.gain.value = (shade() * 2 - 1) * config.colourDb;
    setupPanner(panner, maxDistance);
    source.connect(filter); filter.connect(body); body.connect(colour);
    if (thump) { colour.connect(thump); thump.connect(gate); } else colour.connect(gate);
    gate.connect(gain); gain.connect(panner);
    panner.connect(ctx.oxlynInput);
    const voice = { source, filter, gain, panner, vehicle: message.vehicle, epoch: message.epoch,
      burstId: typeof message.burstId === 'string' ? message.burstId.slice(0, 96) : null,
      ignitionTime: ctx.currentTime + ignitionDelay,
      emissionEnd: ctx.currentTime + ignitionDelay + number(message.durationMs, 100, 20, 650) / 1000,
      position: { ...message.position }, maxDistance, occlusion: amount(message.occlusion, message.occluded),
      cabin: amount(message.cabin),
      outlet: Number.isSafeInteger(message.outlet) && message.outlet >= 1 && message.outlet <= 16 ? message.outlet : 1,
      rate: pitch, doppler, velocity, layers: [],
      // Where it was fired, when that is somewhere else than where it is heard.
      sourceEnv: message.env && typeof message.env === 'object' ? readEnvironment(message.env, environment) : null,
      thump, thumpDb: config.thump * (kind === 'boom' ? 4.0 : 2.5),
      brightness: (0.78 + temperature * 0.22) * profile.bright * tone,
      // Counter the extra EQ peak gain before mixing: body changes colour, not headroom.
      volume: volume * (0.32 + 0.36 * energy) * loudness[kind] *
        Math.pow(10, -Math.max(0, bodyDb) / 20),
      nodes: [source, filter, body, colour, gate, gain, panner], timer: null };
    if (thump) voice.nodes.push(thump);
    spatialPosition(voice, message.position, message.direction);
    // Levels above Extreme bang more often; the room answers them as it answers Extreme.
    const echo = clamp(number(message.echo, 0.16, 0, 0.65) * (0.70 + Math.min(3, message.level) * 0.10) * echoScale, 0, 0.65);
    connectSend(voice, echo * ({ boom: 1.25, bang: 1.1, crackle: 0.8 }[kind] ?? 1));
    // The façades answer the report: the louder and sharper it is, the more comes back.
    connectReflections(voice, ({ boom: 1.0, bang: 0.85, snap: 0.55, crackle: 0.35, burble: 0.30 }[kind] ?? 0.4) *
      clamp(energy, 0.4, 1.2), d);
    voices.add(voice); updateDistance(voice, true);
    const start = ctx.currentTime + Math.max(0, arrivalDelay);
    gate.gain.setValueAtTime(late > 0 ? 0 : 1, start);
    const fadeIn = late > 0 ? 0.003 : 0;
    if (late > 0) gate.gain.linearRampToValueAtTime(releaseGain(late + fadeIn), start + fadeIn);
    if (releaseDuration > 0) {
      if (releaseAt > late + fadeIn) gate.gain.setValueAtTime(1, start + releaseAt - late);
      gate.gain.linearRampToValueAtTime(0, start + audibleDuration - late);
    }
    source.start(start, offset);
    // Smaller reports around the main one, from other takes. They pass through
    // the same chain, so they sit at the same pipe and end with the same gate.
    const mainEnd = Math.max(0, arrivalDelay) + audibleDuration - late;
    let end = mainEnd;
    for (const layer of Array.isArray(message.layers) ? message.layers.slice(0, 4) : []) {
      if (!layer || !reports.includes(layer.kind) || !samples[layer.kind].length ||
        !Number.isSafeInteger(layer.take) || layer.take < 1 || layer.take > 32) continue;
      const at = arrivalDelay + number(layer.delay, 0, 0, 400) / 1000;
      if (at < -0.004) continue; // Its moment passed with a late packet.
      const layerBank = samples[layer.kind], layerBuffer = layerBank[(layer.take - 1) % layerBank.length];
      const rate = clamp(number(layer.pitch, 1, 0.6, 1.6) * enginePitch, 0.6, 1.7);
      const layerSource = ctx.createBufferSource(), level = ctx.createGain();
      layerSource.buffer = layerBuffer; layerSource.playbackRate.value = rate * doppler;
      level.gain.value = Math.pow(10, number(layer.gain, -12, -30, 0) / 20);
      layerSource.connect(level); level.connect(filter);
      layerSource.start(ctx.currentTime + Math.max(0, at));
      voice.layers.push({ source: layerSource, rate });
      voice.nodes.push(layerSource, level);
      const layerEnd = Math.max(0, at) + layerBuffer.duration / rate;
      end = Math.max(end, releaseDuration > 0 ? Math.min(layerEnd, mainEnd) : layerEnd);
    }
    // What surrounds a big report. Drawn from its own seed, so every listener hears the same.
    const around = (bank, level, at, low, high, salt) => {
      if (!bank.length || level <= 0.01 || late > 0.02) return;
      const draw = random(mix(seed ^ salt));
      const buffer = bank[Math.floor(draw() * bank.length) % bank.length];
      const rate = clamp((low + draw() * (high - low)) * enginePitch, 0.6, 1.7);
      const start = Math.max(0, arrivalDelay) + at + draw() * 0.015;
      const extra = ctx.createBufferSource(), level_ = ctx.createGain();
      extra.buffer = buffer; extra.playbackRate.value = rate * doppler;
      level_.gain.value = level;
      extra.connect(level_); level_.connect(filter);
      extra.start(ctx.currentTime + start);
      voice.layers.push({ source: extra, rate });
      voice.nodes.push(extra, level_);
      end = Math.max(end, start + buffer.duration / rate);
    };
    if (loud && (kind === 'boom' || energy >= 0.85)) {
      // The flame has a sound of its own: gas igniting and rushing out, under the report.
      around(samples.whoosh, config.whoosh * (kind === 'boom' ? 0.80 : 0.55) * clamp(energy / 1.2, 0.5, 1.15),
        0.010, 0.90, 1.20, 0x51ed270b);
      // Rain on a pipe that hot flashes to steam.
      around(samples.hiss, config.hiss * 0.90 * number(message.wet, 0, 0, 1), 0.050, 0.92, 1.12, 0x2545f491);
    }
    voice.timer = setTimeout(() => finish(voice), (end + 0.05) * 1000);
  }

  // Hot metal contracting as the pipe cools: a tick now and then, heard from close by.
  function playTick(message) {
    if (!validVehicle(message.vehicle) || !vector(message.position) || config.ticks <= 0 || !samples.tick.length ||
      !hasListener || listener.muted || !ensureContext() || ctx.state !== 'running') return;
    const maxDistance = number(message.maxDistance, 14, 4, 40);
    if (distance(listener.position, message.position) >= maxDistance) return;
    while (voices.size >= config.maxVoices) finish(voices.values().next().value);
    const seed = number(message.seed, 1, 0, 4294967295) >>> 0, draw = random(mix(seed ^ 0x7ed55d16));
    const buffer = samples.tick[Math.floor(draw() * samples.tick.length) % samples.tick.length];
    const source = ctx.createBufferSource(), filter = ctx.createBiquadFilter(), gain = ctx.createGain(), panner = ctx.createPanner();
    const rate = 0.88 + draw() * 0.30;
    source.buffer = buffer; source.playbackRate.value = rate;
    filter.type = 'lowpass'; filter.Q.value = 0.5;
    setupPanner(panner, maxDistance);
    panner.refDistance = 1.2;
    source.connect(filter); filter.connect(gain); gain.connect(panner); panner.connect(ctx.oxlynInput);
    const start = ctx.currentTime + distance(listener.position, message.position) / config.speedOfSound;
    const voice = { source, filter, gain, panner, vehicle: message.vehicle, epoch: epochs.get(message.vehicle) ?? 0,
      burstId: null, ignitionTime: start, emissionEnd: start + buffer.duration / rate, position: { ...message.position },
      maxDistance, occlusion: amount(message.occlusion, message.occluded), cabin: amount(message.cabin), brightness: 1,
      // The hotter the pipe still is, the harder it ticks.
      volume: config.ticks * 0.45 * number(message.level, 0.6, 0, 1) * (0.6 + draw() * 0.4),
      nodes: [source, filter, gain, panner], timer: null, rate, layers: [] };
    spatialPosition(voice, message.position, null);
    connectSend(voice, 0.05);
    voices.add(voice); updateDistance(voice, true);
    if (!voices.has(voice)) return;
    source.start(start);
    voice.timer = setTimeout(() => finish(voice), (start - ctx.currentTime + buffer.duration / rate + 0.05) * 1000);
  }

  // Turbo one-shots (compressor flutter, blow-off) share the pop voice list, so
  // emitter tracking, cancel and distance handling apply to them unchanged.
  function playTurbo(kind, host, level) {
    const bank = antiLagSamples[kind];
    if (!antiLagConfig.turbo.enabled || !bank?.length || level <= 0.01) return;
    while (voices.size >= config.maxVoices) finish(voices.values().next().value);
    const buffer = bank[mix(host.seed) % bank.length];
    const source = ctx.createBufferSource(), filter = ctx.createBiquadFilter(), shape = ctx.createGain();
    const gain = ctx.createGain(), panner = ctx.createPanner();
    source.buffer = buffer; source.playbackRate.value = 0.94 + (host.seed % 13) * 0.01;
    const bay = host.bay === true;
    filter.type = 'lowpass'; filter.Q.value = 0.5;
    setupPanner(panner, host.maxDistance * 0.45);
    source.connect(filter); filter.connect(shape); shape.connect(gain); gain.connect(panner); panner.connect(ctx.oxlynInput);
    const travel = distance(listener.position, host.position) / config.speedOfSound;
    const start = ctx.currentTime + travel;
    // It vents for as long as there was pressure: a little boost is let go in a breath.
    const pressure = clamp(level, 0, 1);
    shape.gain.setValueAtTime(1, start);
    shape.gain.setTargetAtTime(0, start + 0.06 + 0.30 * pressure, 0.09 + 0.10 * pressure);
    const voice = { source, filter, gain, panner, vehicle: host.vehicle, epoch: host.epoch, burstId: null,
      ignitionTime: start, emissionEnd: start + buffer.duration, position: { ...host.position },
      maxDistance: host.maxDistance * 0.45, occlusion: host.occlusion, cabin: host.cabin, brightness: 1,
      volume: level * antiLagConfig.turbo.volume, nodes: [source, filter, shape, gain, panner], timer: null, bay,
      rate: source.playbackRate.value, layers: [] };
    spatialPosition(voice, host.position, bay ? null : host.direction);
    connectSend(voice, 0.06);
    voices.add(voice); updateDistance(voice, true);
    if (!voices.has(voice)) return;
    source.start(start);
    voice.timer = setTimeout(() => finish(voice), (travel + buffer.duration + 0.05) * 1000);
  }

  // Anti-lag adds exhaust combustion and turbo air only. GTA already supplies
  // the vehicle motor, so the gaps of the cut pattern contain no added engine.
  function finishAntiLag(voice) {
    if (orphans.delete(voice)) { /* replaced while ringing out */ }
    else if (antiLagVoices.get(voice.vehicle) === voice) antiLagVoices.delete(voice.vehicle);
    else return;
    clearTimeout(voice.watchdog); clearTimeout(voice.releaseTimer);
    for (const source of voice.sources) { try { source.stop(); } catch (_) {} }
    for (const source of voice.beds) { try { source.stop(); } catch (_) {} }
    for (const node of voice.nodes) { try { node.disconnect(); } catch (_) {} }
  }

  function releaseAntiLag(voice, preserveTravel = false, ageMs = 0, vent = false) {
    if (!voice || voice.releasing) return;
    voice.releasing = true;
    clearTimeout(voice.watchdog);
    const travel = preserveTravel ? Math.max(0, distance(listener.position, voice.position) / config.speedOfSound - ageMs / 1000) : 0;
    voice.releaseAt = ctx.currentTime + travel;
    // Reports that already fired ring out; only ignitions after the release are dropped.
    for (const grain of voice.retired) if (grain.startAt >= voice.releaseAt) {
      try { grain.source.stop(voice.releaseAt); } catch (_) {}
      discardGrain(voice, grain);
    }
    let tail = 0.08;
    for (const grain of voice.retired) tail = Math.max(tail, grain.stopAt - voice.releaseAt);
    voice.releaseTimer = setTimeout(() => finishAntiLag(voice), (travel + Math.min(0.6, tail) + 0.35) * 1000);
  }

  function cutNoise(seed, cycle) {
    let value = (seed ^ Math.imul(cycle + 1, 0x45d9f3b)) >>> 0;
    value ^= value >>> 16; value = Math.imul(value, 0x45d9f3b) >>> 0;
    return (value >>> 0) / 4294967296;
  }

  function discardGrain(voice, grain) {
    if (!voice.sources.delete(grain.source)) return;
    for (const node of [grain.source, grain.fade]) {
      voice.nodes.delete(node);
      try { node.disconnect(); } catch (_) {}
    }
  }

  function emitAntiLagCut(voice, descriptor, at, cycle) {
    if (!descriptor.active || (voice.releasing && at >= voice.releaseAt)) return;
    const launch = voice.mode === 'launch';
    // The more boost there is to burn, the more cuts go off as full bangs.
    const heavy = descriptor.accent || descriptor.energy >= (launch ? 0.97 : 0.90) - voice.boost * 0.10;
    const bank = heavy && antiLagSamples.bang?.length ? antiLagSamples.bang : antiLagSamples.hit;
    // A step coprime with the bank size visits every take before one returns.
    const index = (cycle * (bank.length % 5 === 0 ? 3 : 5) + descriptor.texture) % bank.length;
    const source = ctx.createBufferSource(), fade = ctx.createGain();
    const noise = cutNoise(voice.seed, cycle);
    const rate = (0.93 + voice.rpm * 0.09 + (noise - 0.5) * 0.11 - (heavy ? 0.04 : 0)) * (voice.doppler || 1);
    const natural = bank[index].duration / rate;
    // A full report lasts longer than one cut of the two-step. Let it decay
    // under the next ignition instead of chopping it into a buzz.
    const hold = launch ? 0.045 : 0.070, decay = heavy ? 0.085 : (launch ? 0.036 : 0.060);
    const duration = Math.min(natural, hold + decay * 5);
    const grain = { source, fade, startAt: at, stopAt: at + duration + 0.004 };
    source.buffer = bank[index]; source.playbackRate.value = rate;
    source.connect(fade); fade.connect(voice.bus);
    const level = descriptor.energy * (0.50 + 0.50 * voice.boost) * (heavy ? 1.12 : 0.84) * (0.92 + noise * 0.16);
    fade.gain.setValueAtTime(level, at);
    fade.gain.setTargetAtTime(0, at + hold, decay);
    voice.sources.add(source); voice.nodes.add(source); voice.nodes.add(fade);
    voice.retired.push(grain);
    source.onended = () => discardGrain(voice, grain);
    source.start(at, 0); source.stop(grain.stopAt);
  }

  function scheduleAntiLag(voice) {
    if (!ctx || (voice.releasing && ctx.currentTime >= voice.releaseAt)) return;
    const now = ctx.currentTime;
    if (!voice.releasing && now - voice.lastUpdate > antiLagConfig.watchdogMs / 1000) { releaseAntiLag(voice); return; }
    const period = (voice.mode === 'launch' ? 54 : 72) / 1000;
    const horizon = Math.min(now + 0.13, voice.releasing ? voice.releaseAt : Infinity);
    voice.retired = voice.retired.filter(grain => {
      if (grain.stopAt > now) return true;
      discardGrain(voice, grain); return false;
    });
    if (!window.PopsALSPattern?.cut) return;
    let cycle = Math.max(voice.nextCycle, 0, Math.floor((now - voice.phaseOrigin) / period));
    for (; voice.phaseOrigin + cycle * period < horizon; cycle++) {
      const cut = window.PopsALSPattern.cut(voice.seed, voice.mode, cycle);
      const start = voice.phaseOrigin + cycle * period + cut.offsetMs / 1000;
      if (start >= horizon) break;
      voice.nextCycle = cycle + 1;
      if (start < now + 0.001) continue;
      // Native flames use the same cut time + 2 ms; acoustic travel is in phaseOrigin.
      emitAntiLagCut(voice, cut, start + 0.002, cycle);
    }
  }

  function updateAntiLagTone(voice) {
    const at = ctx.currentTime, launch = voice.mode === 'launch';
    param(voice.bus.gain, (launch ? 0.86 : 0.94) * (0.72 + voice.load * 0.28), at, 0.03);
    voice.brightness = 0.80 + voice.temperature * 0.20;
    updateDistance(voice);
  }

  function noiseLoop() {
    if (turboNoise) return turboNoise;
    const rng = random(0x7f4a7c15);
    turboNoise = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const data = turboNoise.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = rng() * 2 - 1;
    return turboNoise;
  }

  // The turbo belongs to the car, not to an anti-lag event: it spools with
  // throttle and revs whenever the car is driven, and anti-lag keeps it spinning.
  function finishTurbo(voice) {
    if (turboVoices.get(voice.vehicle) !== voice) return;
    turboVoices.delete(voice.vehicle);
    clearTimeout(voice.watchdog);
    for (const source of voice.beds) { try { source.stop(); } catch (_) {} }
    for (const node of voice.nodes) { try { node.disconnect(); } catch (_) {} }
  }

  function playTurboState(message) {
    if (!validVehicle(message.vehicle) || !vector(message.position)) return;
    let voice = turboVoices.get(message.vehicle);
    const boost = number(message.boost, 0, 0, 1);
    if (!antiLagConfig.turbo.enabled || antiLagConfig.turbo.volume <= 0 || boost <= 0.01) {
      if (voice) {
        param(voice.level.gain, 0, ctx.currentTime, 0.12);
        clearTimeout(voice.watchdog);
        voice.watchdog = setTimeout(() => finishTurbo(voice), 700);
      }
      return;
    }
    if (!hasListener || listener.muted || !ensureContext() || ctx.state !== 'running') return;
    const maxDistance = number(message.maxDistance, 70, 10, 300);
    if (distance(listener.position, message.position) >= maxDistance) { if (voice) finishTurbo(voice); return; }
    const now = ctx.currentTime;
    if (!voice) {
      while (turboVoices.size >= 4) finishTurbo(turboVoices.values().next().value);
      const bed = ctx.createBufferSource(), air = ctx.createBiquadFilter(), airLevel = ctx.createGain();
      const hiss = ctx.createBiquadFilter(), hissLevel = ctx.createGain();
      const whistle = ctx.createOscillator(), whistleLevel = ctx.createGain();
      const wobble = ctx.createOscillator(), wobbleDepth = ctx.createGain();
      const level = ctx.createGain(), filter = ctx.createBiquadFilter(), gain = ctx.createGain(), panner = ctx.createPanner();
      bed.buffer = noiseLoop(); bed.loop = true;
      // A narrow band of air around the whistle gives it breath; on its own a sine reads as a test tone.
      air.type = 'bandpass'; air.Q.value = 7; air.frequency.value = 3000;
      hiss.type = 'bandpass'; hiss.Q.value = 0.8; hiss.frequency.value = 2500;
      whistle.type = 'sine'; whistle.frequency.value = 3000;
      wobble.type = 'sine'; wobble.frequency.value = 6.1; wobbleDepth.gain.value = 22;
      wobble.connect(wobbleDepth); wobbleDepth.connect(whistle.frequency);
      airLevel.gain.value = 0; hissLevel.gain.value = 0; whistleLevel.gain.value = 0; level.gain.value = 0;
      filter.type = 'lowpass'; filter.Q.value = 0.5;
      bed.connect(air); air.connect(airLevel); airLevel.connect(level);
      bed.connect(hiss); hiss.connect(hissLevel); hissLevel.connect(level);
      whistle.connect(whistleLevel); whistleLevel.connect(level);
      level.connect(filter); filter.connect(gain); gain.connect(panner); panner.connect(ctx.oxlynInput);
      setupPanner(panner, maxDistance);
      voice = { turbo: true, vehicle: message.vehicle, beds: new Set([bed, whistle, wobble]), air, airLevel, hiss, hissLevel,
        whistle, whistleLevel, level, filter, gain, panner, maxDistance, position: { ...message.position }, brightness: 1,
        nodes: new Set([bed, air, airLevel, hiss, hissLevel, whistle, whistleLevel, wobble, wobbleDepth, level, filter, gain, panner]),
        watchdog: null };
      for (const source of voice.beds) source.start(now);
      turboVoices.set(message.vehicle, voice);
    }
    voice.maxDistance = maxDistance;
    voice.volume = number(message.volume, 1, 0, 1.5) * antiLagConfig.turbo.volume;
    voice.occlusion = amount(message.occlusion, message.occluded); voice.cabin = amount(message.cabin);
    spatialPosition(voice, message.position, null, 0.018);
    // Shaft speed sets the pitch; pressure sets how much air is moving.
    const pitch = 2400 + 6200 * Math.pow(boost, 0.8);
    // Follow the game state closely: a slow glide here keeps the whistle
    // climbing after the driver has already lifted.
    param(voice.whistle.frequency, pitch, now, 0.045);
    param(voice.air.frequency, pitch, now, 0.045);
    param(voice.hiss.frequency, 1800 + boost * 2600, now, 0.05);
    param(voice.whistleLevel.gain, 0.10 * Math.pow(boost, 1.6), now, 0.045);
    param(voice.airLevel.gain, 0.85 * Math.pow(boost, 1.5), now, 0.045);
    param(voice.hissLevel.gain, 0.10 * Math.pow(boost, 1.3), now, 0.045);
    param(voice.level.gain, 1, now, 0.05);
    updateDistance(voice);
    clearTimeout(voice.watchdog);
    voice.watchdog = setTimeout(() => finishTurbo(voice), 900);
  }

  function playTurboShot(message) {
    if (!validVehicle(message.vehicle) || !vector(message.position) || !['flutter', 'blowOff'].includes(message.kind) ||
      !hasListener || listener.muted || !ensureContext() || ctx.state !== 'running') return;
    if ((message.kind === 'flutter' && !antiLagConfig.turbo.flutter) ||
      (message.kind === 'blowOff' && !antiLagConfig.turbo.blowOff)) return;
    const maxDistance = number(message.maxDistance, 70, 10, 300) / 0.45;
    if (distance(listener.position, message.position) >= maxDistance * 0.45) return;
    playTurbo(message.kind, { vehicle: message.vehicle, epoch: epochs.get(message.vehicle) ?? 0,
      seed: number(message.seed, 1, 0, 2147483646) >>> 0, maxDistance, position: message.position,
      bay: true, occlusion: amount(message.occlusion, message.occluded), cabin: amount(message.cabin) },
    number(message.level, 0.5, 0, 1.5));
  }

  function playAntiLag(message) {
    if (!validVehicle(message.vehicle) || !validEpoch(message.epoch) ||
      !['rally', 'launch', 'off'].includes(message.mode)) return;
    const floor = epochs.get(message.vehicle) ?? -1;
    if (message.epoch < floor) return;
    let voice = antiLagVoices.get(message.vehicle);
    if (message.epoch > floor) {
      markEpoch(message.vehicle, message.epoch);
      for (const old of Array.from(voices)) if (old.vehicle === message.vehicle && old.epoch < message.epoch) finish(old);
      if (voice) { finishAntiLag(voice); voice = null; }
    }
    const sequenceValue = message.sequence ?? message.seq;
    const sequence = Number.isSafeInteger(sequenceValue) && sequenceValue >= 0 ? sequenceValue : null;
    const sender = Number.isSafeInteger(message.sender) && message.sender >= 0 ? message.sender : (voice?.sender ?? 0);
    const previous = antiLagSequences.get(message.vehicle);
    if (previous && previous.epoch === message.epoch && previous.sender === sender && sequence !== null &&
      (sequence < previous.sequence || (sequence === previous.sequence && message.mode !== 'off'))) return;
    if (voice && voice.sender !== sender) { finishAntiLag(voice); voice = null; }
    if (message.mode === 'off') {
      if (sequence !== null) antiLagSequences.set(message.vehicle, { epoch: message.epoch, sender, sequence });
      releaseAntiLag(voice, message.immediate !== true, number(message.ageMs, 0, 0, 5000), message.vent === true); return;
    }
    const ageMs = number(message.ageMs, 0, 0, 5000);
    if (ageMs > antiLagConfig.watchdogMs || !vector(message.position) || !hasListener || listener.muted ||
      !ensureContext() || ctx.state !== 'running' || !antiLagSamples.hit?.length ||
      !window.PopsALSPattern?.cut) return;
    const maxDistance = number(message.maxDistance, 260, 10, 900);
    if (distance(listener.position, message.position) >= maxDistance) return;
    const phaseMs = number(message.phaseMs, 0, 0, 600000) + ageMs;
    const seed = number(message.seed, 1, 1, 2147483646) >>> 0;
    const now = ctx.currentTime;
    const propagation = distance(listener.position, message.position) / config.speedOfSound;
    if (sequence !== null) {
      if (antiLagSequences.size >= 8192 && !antiLagSequences.has(message.vehicle)) antiLagSequences.delete(antiLagSequences.keys().next().value);
      antiLagSequences.set(message.vehicle, { epoch: message.epoch, sender, sequence });
    }
    if (voice && (voice.releasing || voice.seed !== seed)) {
      // A new activation replaces the previous one, whose reports keep ringing.
      if (voice.releasing) { antiLagVoices.delete(voice.vehicle); orphans.add(voice); } else finishAntiLag(voice);
      voice = null;
    }
    if (!voice) {
      while (antiLagVoices.size >= antiLagConfig.maxVehicles) finishAntiLag(antiLagVoices.values().next().value);
      const bus = ctx.createGain(), filter = ctx.createBiquadFilter(), gain = ctx.createGain();
      const panner = ctx.createPanner(), envelope = ctx.createGain();
      filter.type = 'lowpass'; filter.Q.value = 0.50;
      setupPanner(panner, maxDistance);
      bus.connect(filter); filter.connect(gain); gain.connect(envelope); envelope.connect(panner);
      panner.connect(ctx.oxlynInput);
      // The first packet may describe an activation already in progress. Account
      // for its whole elapsed phase, not only this packet's network transit.
      const arrival = Math.max(0, propagation - phaseMs / 1000);
      voice = { continuous: true, vehicle: message.vehicle, epoch: message.epoch, mode: message.mode, seed, sender,
        sources: new Set(), beds: new Set(), retired: [], bus, filter, gain, panner, envelope, maxDistance,
        position: { ...message.position }, phaseOrigin: now - phaseMs / 1000 + propagation, nextCycle: 0,
        lastUpdate: now, rpm: number(message.rpm, 0.65, 0, 1.1), boost: number(message.boost, 0.5, 0, 1),
        nodes: new Set([bus, filter, gain, panner, envelope]), watchdog: null, releaseTimer: null, releasing: false,
        sendFrom: envelope };
      // A cut every 54-72 ms would turn a full room into one continuous roar.
      connectSend(voice, message.mode === 'launch' ? 0.10 : 0.13);
      connectReflections(voice, 0.40, distance(listener.position, message.position));
      envelope.gain.setValueAtTime(0, now);
      envelope.gain.setValueAtTime(0, now + arrival);
      envelope.gain.linearRampToValueAtTime(1, now + arrival + 0.012);
      antiLagVoices.set(message.vehicle, voice);
    } else if (voice.mode !== message.mode) {
      voice.mode = message.mode;
      voice.phaseOrigin = now - phaseMs / 1000 + propagation;
      voice.nextCycle = 0;
      // Drop old-mode lookahead before scheduling the new cadence.
      for (const grain of voice.retired) if (grain.startAt >= now) {
        try { grain.source.stop(now); } catch (_) {}
        discardGrain(voice, grain);
      }
    }
    voice.sequence = sequence; voice.lastUpdate = now;
    voice.rpm = number(message.rpm, 0.65, 0, 1.1); voice.load = number(message.load, 0.5, 0, 1);
    voice.boost = number(message.boost, 0.5, 0, 1); voice.temperature = number(message.temperature, 0.5, 0, 1);
    voice.volume = number(message.volume, 0.8, 0, 1.25) * antiLagConfig.volume * 0.78;
    voice.occlusion = amount(message.occlusion, message.occluded); voice.cabin = amount(message.cabin);
    if (message.env && typeof message.env === 'object') voice.sourceEnv = readEnvironment(message.env, environment);
    if (voice.send) routeSend(voice, voiceWeights(voice), false);
    spatialPosition(voice, message.position, message.direction, 0.018);
    applyDoppler(voice, message.velocity);
    clearTimeout(voice.watchdog);
    voice.watchdog = setTimeout(() => releaseAntiLag(voice), Math.max(30, antiLagConfig.watchdogMs - ageMs));
    updateAntiLagTone(voice); scheduleAntiLag(voice);
  }

  function updateEmitters(message) {
    if (!ctx || !Array.isArray(message.items)) return;
    for (const item of message.items.slice(0, 96)) {
      if (!item || !validVehicle(item.vehicle) || !validEpoch(item.epoch) || !vector(item.position)) continue;
      for (const voice of voices) {
        if (voice.vehicle !== item.vehicle || voice.epoch !== item.epoch) continue;
        // Turbo air comes from the engine bay; combustion from the exhaust.
        if (voice.bay) { if (vector(item.engine)) spatialPosition(voice, item.engine, null, 0.012); }
        else {
          // Each report stays with the pipe it came out of.
          const pipe = Array.isArray(item.outlets) ? item.outlets[(voice.outlet || 1) - 1] : null;
          spatialPosition(voice, vector(pipe) ? pipe : item.position, item.direction, 0.012);
        }
        voice.occlusion = amount(item.occlusion, item.occluded); voice.cabin = amount(item.cabin); updateDistance(voice);
        applyDoppler(voice, item.velocity);
      }
      const turbo = turboVoices.get(item.vehicle);
      if (turbo && vector(item.engine)) {
        spatialPosition(turbo, item.engine, null, 0.018);
        turbo.occlusion = amount(item.occlusion, item.occluded); turbo.cabin = amount(item.cabin); updateDistance(turbo);
      }
      const voice = antiLagVoices.get(item.vehicle);
      if (voice && voice.epoch === item.epoch && !voice.releasing) {
        spatialPosition(voice, item.position, item.direction, 0.018);
        voice.occlusion = amount(item.occlusion, item.occluded); voice.cabin = amount(item.cabin); updateDistance(voice);
        applyDoppler(voice, item.velocity);
        scheduleAntiLag(voice);
      }
    }
  }

  function localPaths(paths) {
    return Array.isArray(paths) ? paths.filter(path => typeof path === 'string' &&
      /^sounds\/[a-zA-Z0-9_\-/]+\.(ogg|wav|mp3)$/i.test(path) && !path.includes('..')).slice(0, 32) : [];
  }

  async function decode(path, controller, maxSeconds) {
    try {
      const response = await fetch(path, { signal: controller.signal });
      if (!response.ok || Number(response.headers.get('Content-Length')) > 8388608) return null;
      const bytes = await response.arrayBuffer();
      if (bytes.byteLength > 8388608) return null;
      const decoded = await ctx.decodeAudioData(bytes);
      if (!decoded || decoded.duration <= 0 || decoded.duration > maxSeconds || decoded.numberOfChannels > 8) return null;
      // Mono point source is necessary for predictable HRTF placement.
      const mono = ctx.createBuffer(1, decoded.length, decoded.sampleRate), data = mono.getChannelData(0);
      for (let c = 0; c < decoded.numberOfChannels; c++) {
        const channel = decoded.getChannelData(c);
        for (let i = 0; i < data.length; i++) data[i] += channel[i] / decoded.numberOfChannels;
      }
      let peak = 0;
      for (let i = 0; i < data.length; i++) {
        if (!Number.isFinite(data[i])) return null;
        peak = Math.max(peak, Math.abs(data[i]));
      }
      if (peak > 0.89) for (let i = 0; i < data.length; i++) data[i] *= 0.89 / peak;
      return mono;
    } catch (_) { return null; /* A missing/invalid local file falls back or stays silent. */ }
  }

  async function loadAntiLagSamples(value) {
    if (!value || typeof value !== 'object') return;
    antiLagConfig.maxVehicles = Math.floor(number(value.maxVehicles, antiLagConfig.maxVehicles, 1, 8));
    antiLagConfig.watchdogMs = number(value.watchdogMs, antiLagConfig.watchdogMs, 250, 500);
    antiLagConfig.volume = number(value.volume, antiLagConfig.volume, 0, 1.25);
    if (value.turbo && typeof value.turbo === 'object') {
      antiLagConfig.turbo = { enabled: value.turbo.enabled !== false,
        volume: number(value.turbo.volume, 0.5, 0, 1.5), flutter: value.turbo.flutter !== false,
        blowOff: value.turbo.blowOff !== false };
    }
    while (antiLagVoices.size > antiLagConfig.maxVehicles) finishAntiLag(antiLagVoices.values().next().value);
    const paths = Object.fromEntries(['hit', 'bang', 'flutter', 'blowOff'].map(kind => {
      const configured = value.samples?.[kind];
      return [kind, localPaths(Array.isArray(configured) ? configured : [configured]).slice(0, 16)];
    }));
    const key = JSON.stringify(paths);
    if (key === antiLagSamplesKey) return;
    antiLagSamplesKey = key; antiLagSamples = {};
    for (const voice of Array.from(antiLagVoices.values())) finishAntiLag(voice);
    const revision = ++antiLagRevision;
    if (antiLagController) antiLagController.abort();
    antiLagController = new AbortController();
    const controller = antiLagController;
    if (!ensureContext()) return;
    await Promise.all(Object.entries(paths).map(async ([kind, bank]) => {
      const loaded = await Promise.all(bank.map(path => decode(path, controller, 3)));
      if (revision === antiLagRevision) antiLagSamples[kind] = loaded.filter(Boolean);
    }));
  }

  async function loadSamples(value) {
    if (!value || typeof value !== 'object') return;
    const paths = Object.fromEntries(kinds.map(kind => [kind, localPaths(value[kind])]));
    const key = JSON.stringify(paths);
    if (key === samplesKey) return;
    samplesKey = key; samples = emptyBanks();
    const revision = ++sampleRevision;
    if (sampleController) sampleController.abort();
    sampleController = new AbortController();
    if (!ensureContext()) return;
    const controller = sampleController;
    await Promise.all(kinds.map(async type => {
      const results = await Promise.all(paths[type].map(path => decode(path, controller, 3)));
      if (revision === sampleRevision) samples[type] = results.filter(Boolean);
    }));
  }

  function receive(message) {
    if (!message || typeof message !== 'object') return;
    switch (message.action) {
      case 'configure':
        config.masterVolume = number(message.masterVolume, config.masterVolume, 0, 1);
        config.maxVoices = Math.floor(number(message.maxVoices, config.maxVoices, 1, 64));
        config.speedOfSound = number(message.speedOfSound, config.speedOfSound, 100, 500);
        config.audioLeadMs = number(message.audioLeadMs, config.audioLeadMs, -100, 100);
        config.maxLateMs = number(message.maxLateMs, config.maxLateMs, 20, 300);
        config.reverb = message.reverb !== false;
        config.reverbLevel = number(message.reverbLevel, config.reverbLevel, 0, 2);
        config.doppler = message.doppler === false ? 0 : number(message.doppler, config.doppler, 0, 1);
        config.colourDb = number(message.colourDb, config.colourDb, 0, 6);
        for (const name of ['whoosh', 'hiss', 'thump', 'ticks', 'reflections', 'flutter']) {
          config[name] = message[name] === false ? 0 : number(message[name], config[name], 0, 2);
        }
        while (voices.size > config.maxVoices) finish(voices.values().next().value);
        ensureContext(); applyListener(); if (ctx) applyEnvironment();
        void loadSamples(message.samples || bundledSamples);
        void loadAntiLagSamples(message.antiLag);
        break;
      case 'listener': {
        if (!vector(message.position) || !vector(message.forward) || !vector(message.up) ||
          length(message.forward) < 0.01 || length(message.up) < 0.01) return;
        const forward = unit(message.forward), up = unit(message.up);
        if (Math.abs(forward.x * up.x + forward.y * up.y + forward.z * up.z) > 0.98) return;
        listener = { position: { ...message.position }, forward, up, muted: message.muted === true,
          velocity: vector(message.velocity) ? { ...message.velocity } : { x: 0, y: 0, z: 0 } };
        hasListener = true;
        ensureContext(); applyListener();
        if (message.env && typeof message.env === 'object') {
          environment = readEnvironment(message.env, environment);
          if (ctx) applyEnvironment();
        }
        break;
      }
      case 'pop': play(message); break;
      case 'antilag': playAntiLag(message); break;
      case 'turbo': playTurboState(message); break;
      case 'turboShot': playTurboShot(message); break;
      case 'tick': playTick(message); break;
      case 'emitters': updateEmitters(message); break;
      case 'cancelBurst': {
        if (typeof message.burstId !== 'string' || !ctx) return;
        const cutoff = ctx.currentTime + number(message.cutoffDelayMs, 0, -3000, 300) / 1000;
        for (const voice of Array.from(voices)) {
          if (voice.burstId === message.burstId && (message.vehicle === undefined || voice.vehicle === message.vehicle) &&
            (message.futureOnly === false || voice.ignitionTime > cutoff)) finish(voice);
        }
        break;
      }
      case 'cancel': {
        if (!validVehicle(message.vehicle) || !validEpoch(message.epoch)) return;
        if (message.epoch < (epochs.get(message.vehicle) ?? -1)) return;
        markEpoch(message.vehicle, message.epoch);
        for (const voice of Array.from(voices)) if (voice.vehicle === message.vehicle && voice.epoch <= message.epoch) finish(voice);
        const voice = antiLagVoices.get(message.vehicle);
        if (voice && voice.epoch <= message.epoch) finishAntiLag(voice);
        for (const old of Array.from(orphans)) if (old.vehicle === message.vehicle) finishAntiLag(old);
        if (turboVoices.has(message.vehicle)) finishTurbo(turboVoices.get(message.vehicle));
        break;
      }
      case 'reset':
        clearVoices(); epochs.clear(); buffers.clear(); antiLagSequences.clear();
        listener.muted = true; listener.velocity = { x: 0, y: 0, z: 0 }; hasListener = false;
        if (master) param(master.gain, 0, ctx.currentTime);
        break;
    }
  }

  // The workshop screen's sounds: the ratchet, a part set down, a connector
  // clicking home, the jack, a beep from the laptop, the turbo spooling for the
  // test. Made of noise bursts and envelopes here, at the listener; only the
  // blow-off and the test report come from the banks.
  const bench = { whistle: null, ratchet: null };
  function benchBurst({ at = 0, seconds, level, low, high, q = 0.7, decay, attack = 0.0008, pitchDrop = 0 }) {
    if (!ensureContext() || ctx.state !== 'running') return;
    const now = ctx.currentTime + at, source = ctx.createBufferSource(), band = ctx.createBiquadFilter();
    const top = ctx.createBiquadFilter(), gain = ctx.createGain();
    source.buffer = noiseLoop(); source.loop = true;
    source.playbackRate.value = 0.7 + Math.random() * 0.6;
    band.type = 'highpass'; band.frequency.value = low; band.Q.value = q;
    top.type = 'lowpass'; top.frequency.value = high; top.Q.value = q;
    if (pitchDrop > 0) { top.frequency.setValueAtTime(high, now); top.frequency.exponentialRampToValueAtTime(Math.max(120, high / pitchDrop), now + seconds); }
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(level * config.masterVolume, now + attack);
    gain.gain.setTargetAtTime(0, now + attack, decay);
    source.connect(band); band.connect(top); top.connect(gain); gain.connect(ctx.oxlynInput);
    source.start(now); source.stop(now + seconds + 0.05);
    source.onended = () => { for (const node of [source, band, top, gain]) { try { node.disconnect(); } catch (_) {} } };
  }
  function benchTone(frequency, seconds, level, at = 0, type = 'sine') {
    if (!ensureContext() || ctx.state !== 'running') return;
    const now = ctx.currentTime + at, osc = ctx.createOscillator(), gain = ctx.createGain();
    osc.type = type; osc.frequency.value = frequency;
    gain.gain.setValueAtTime(0, now); gain.gain.linearRampToValueAtTime(level * config.masterVolume, now + 0.004);
    gain.gain.setTargetAtTime(0, now + seconds * 0.6, seconds * 0.18);
    osc.connect(gain); gain.connect(ctx.oxlynInput);
    osc.start(now); osc.stop(now + seconds + 0.1);
    osc.onended = () => { try { osc.disconnect(); gain.disconnect(); } catch (_) {} };
  }
  // One click of a ratchet: a sharp tick with a little steel behind it.
  function benchClick(level, at = 0, bright = 1) {
    benchBurst({ at, seconds: 0.03, level: 0.55 * level, low: 2200 * bright, high: 9000, decay: 0.004 });
    benchBurst({ at, seconds: 0.05, level: 0.28 * level, low: 500, high: 2400, decay: 0.010 });
  }
  function benchRatchet(on, level) {
    if (!on) { if (bench.ratchet) { clearInterval(bench.ratchet); bench.ratchet = null; } return; }
    if (bench.ratchet) return;
    const step = () => { benchClick(clamp(level, 0.2, 1.2) * (0.8 + Math.random() * 0.4), 0, 0.9 + Math.random() * 0.3); };
    step();
    bench.ratchet = setInterval(step, 62 + Math.random() * 10);
  }
  function benchWhistle(level) {
    if (!ensureContext() || ctx.state !== 'running') return;
    const now = ctx.currentTime;
    if (level <= 0.01) {
      const w = bench.whistle;
      if (!w) return;
      bench.whistle = null;
      param(w.gain.gain, 0, now, 0.08);
      setTimeout(() => { for (const node of w.nodes) { try { node.stop?.(); node.disconnect(); } catch (_) {} } }, 600);
      return;
    }
    let w = bench.whistle;
    if (!w) {
      const bed = ctx.createBufferSource(), air = ctx.createBiquadFilter(), airLevel = ctx.createGain();
      const whistle = ctx.createOscillator(), whistleLevel = ctx.createGain(), gain = ctx.createGain();
      bed.buffer = noiseLoop(); bed.loop = true;
      air.type = 'bandpass'; air.Q.value = 6; air.frequency.value = 2400;
      whistle.type = 'sine'; whistle.frequency.value = 2400;
      airLevel.gain.value = 0; whistleLevel.gain.value = 0; gain.gain.value = 0;
      bed.connect(air); air.connect(airLevel); airLevel.connect(gain);
      whistle.connect(whistleLevel); whistleLevel.connect(gain);
      gain.connect(ctx.oxlynInput);
      bed.start(now); whistle.start(now);
      w = { air, airLevel, whistle, whistleLevel, gain, nodes: [bed, air, airLevel, whistle, whistleLevel, gain] };
      bench.whistle = w;
    }
    const pitch = 2400 + 6200 * Math.pow(clamp(level, 0, 1), 0.8);
    param(w.whistle.frequency, pitch, now, 0.05); param(w.air.frequency, pitch, now, 0.05);
    param(w.whistleLevel.gain, 0.06 * Math.pow(level, 1.6), now, 0.05);
    param(w.airLevel.gain, 0.50 * Math.pow(level, 1.5), now, 0.05);
    param(w.gain.gain, 0.9 * config.masterVolume, now, 0.05);
  }
  function benchSample(bank, seed, level, rate) {
    if (!Array.isArray(bank) || !bank.length || !ensureContext() || ctx.state !== 'running') return;
    const buffer = bank[mix(seed >>> 0) % bank.length], source = ctx.createBufferSource(), gain = ctx.createGain();
    source.buffer = buffer; source.playbackRate.value = rate;
    gain.gain.value = clamp(level, 0, 1.5) * config.masterVolume;
    source.connect(gain); gain.connect(ctx.oxlynInput);
    source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch (_) {} };
    source.start(ctx.currentTime);
  }
  window.oxlynWorkshopSound = function (kind, options) {
    const o = options && typeof options === 'object' ? options : {};
    const seed = Number.isFinite(o.seed) ? Math.floor(o.seed) : Math.floor(Math.random() * 1e9);
    const level = clamp(Number.isFinite(o.level) ? o.level : 1, 0, 2);
    try {
      switch (kind) {
        case 'ratchet': benchRatchet(o.on !== false, level); break;
        case 'click': benchClick(level); break;
        // a part set down on steel: a clank, dull and short
        case 'clank': benchBurst({ seconds: 0.09, level: 0.5 * level, low: 180, high: 2600, decay: 0.022, pitchDrop: 3 }); benchClick(0.5 * level, 0, 0.7); break;
        // a connector home: the latch and the seat
        case 'plug': benchClick(0.7 * level, 0, 1.1); benchBurst({ at: 0.035, seconds: 0.05, level: 0.35 * level, low: 300, high: 1800, decay: 0.012 }); break;
        // a plug pulled out: the latch letting go, then the drag of the pins
        case 'unplug': benchBurst({ seconds: 0.07, level: 0.3 * level, low: 900, high: 5000, decay: 0.02 }); benchClick(0.5 * level, 0.06, 1.2); break;
        // the terminal coming off: a scrape and a spark
        case 'spark': benchBurst({ seconds: 0.12, level: 0.35 * level, low: 3000, high: 12000, decay: 0.03, attack: 0.004 }); benchClick(0.4 * level, 0, 1.3); break;
        // a bolt seating at the end of its thread
        case 'seat': benchBurst({ seconds: 0.08, level: 0.45 * level, low: 250, high: 3200, decay: 0.018, pitchDrop: 2 }); break;
        // a stroke of the jack: hydraulics and the car creeping up
        case 'jack': benchBurst({ seconds: 0.28, level: 0.30 * level, low: 200, high: 1400, decay: 0.09, attack: 0.03 }); benchBurst({ at: 0.18, seconds: 0.06, level: 0.2 * level, low: 400, high: 2200, decay: 0.015 }); break;
        // the laptop
        case 'beep': benchTone(1240, 0.07, 0.12 * level); break;
        case 'beep2': benchTone(1240, 0.06, 0.12 * level); benchTone(1660, 0.09, 0.12 * level, 0.09); break;
        case 'buzz': benchTone(220, 0.14, 0.10 * level, 0, 'square'); break;
        case 'ding': benchTone(1660, 0.12, 0.10 * level); benchTone(2220, 0.18, 0.08 * level, 0.10); break;
        case 'spool': benchWhistle(level); break;
        case 'air': benchSample(antiLagSamples.blowOff, seed, 0.6 * level, 0.95 + (seed % 5) * 0.03); break;
        case 'flutter': benchSample(antiLagSamples.flutter, seed, 0.5 * level, 1); break;
        case 'whoosh': benchSample(samples.whoosh, seed, 0.6 * level, 1); break;
        case 'hiss': benchSample(samples.hiss, seed, 0.4 * level, 1); break;
        case 'boom': benchSample(samples.boom, seed, 0.7 * level, 1); break;
        case 'bang': benchSample(samples.bang, seed, 0.7 * level, 1); break;
        case 'snap': benchSample(samples.snap, seed, 0.6 * level, 1); break;
        case 'stop': benchRatchet(false); benchWhistle(0); break;
        default: break;
      }
    } catch (_) { /* A screen without sound is still a screen. */ }
  };

  if (window.__oxlynTest) {
    window.__voices = voices; window.__rooms = () => reverb && reverb.rooms; window.__roomWeights = roomWeights;
    window.__reflections = () => reflections; window.__environment = () => environment;
    window.__continuous = () => [...antiLagVoices.values(), ...turboVoices.values()];
  }
  window.addEventListener('message', event => receive(event.data));
  window.addEventListener('beforeunload', () => {
    clearVoices(); if (sampleController) sampleController.abort(); if (antiLagController) antiLagController.abort();
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) resume(); });
  async function ready() {
    if (typeof GetParentResourceName !== 'function') return;
    const resource = GetParentResourceName();
    if (typeof resource !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(resource)) return;
    for (let attempt = 0; attempt < 15; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 1800);
      try {
        // FiveM routes this URL to the local RegisterNUICallback, not the internet.
        const response = await fetch(`https://${resource}/ready`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}', signal: controller.signal
        });
        if (response.ok) return;
      } catch (_) { /* Client callback may not have registered yet. */ }
      finally { clearTimeout(timeout); }
      await new Promise(resolve => setTimeout(resolve, Math.min(1500, 300 + attempt * 150)));
    }
    console.warn('[oxlyn-popsbangs] NUI ready callback unavailable; check the resource/client startup.');
  }
  void ready();
  // CEF typically permits game-driven playback; retries never capture game focus.
  let retries = 0;
  const startupRetry = setInterval(() => {
    if (++retries > 30 || (ctx && ctx.state === 'running')) clearInterval(startupRetry);
    else resume();
  }, 1000);
  setInterval(() => { for (const voice of antiLagVoices.values()) scheduleAntiLag(voice); }, 32);
})();
