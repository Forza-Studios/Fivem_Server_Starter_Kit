(() => {
  'use strict';
  // Pure deterministic counterpart of PopsAntiLag.Cut in shared/antilag.lua.
  // Eight carrier cycles per phrase; gaps add no exhaust impulse; the native GTA engine remains audible.
  const patterns = {
    launch: [
      [100, 40, 80, 0, 94, 30, 68, 0],
      [70, 54, 0, 86, 0, 40, 96, 36],
      [26, 38, 56, 84, 100, 74, 40, 0],
      [100, 90, 0, 0, 64, 94, 0, 0],
      [35, 48, 32, 55, 40, 62, 36, 48],
      [96, 0, 0, 35, 0, 80, 54, 0]
    ],
    rally: [
      [100, 52, 0, 0, 80, 34, 0, 0],
      [42, 0, 82, 0, 0, 58, 0, 96],
      [28, 40, 64, 90, 62, 0, 34, 0],
      [96, 76, 0, 0, 0, 52, 38, 0],
      [32, 42, 30, 0, 48, 36, 0, 28],
      [100, 0, 0, 0, 58, 0, 0, 34]
    ]
  };
  const clamp = (value, low, high, fallback) => Number.isFinite(value)
    ? Math.max(low, Math.min(high, value)) : fallback;
  function randomFor(seed) {
    let value = Math.floor(seed) % 2147483646 + 1;
    return () => {
      value = value * 48271 % 2147483647;
      return (value - 1) / 2147483646;
    };
  }
  function rawOrder(seed, block, count, salt) {
    const random = randomFor((seed + block * 104729 + salt) % 2147483646);
    const order = Array.from({length: count}, (_, index) => index + 1);
    for (let index = count; index > 1; index--) {
      const other = Math.floor(random() * index);
      [order[index - 1], order[other]] = [order[other], order[index - 1]];
    }
    return order;
  }
  function sequenceChoice(seed, ordinal, count, salt) {
    const block = Math.floor(ordinal / count), slot = ordinal % count;
    const order = rawOrder(seed, block, count, salt);
    if (block > 0 && order[0] === rawOrder(seed, block - 1, count, salt)[count - 1]) {
      [order[0], order[1]] = [order[1], order[0]];
    }
    return order[slot];
  }
  function cut(seed, mode, cycle) {
    if (!Object.hasOwn(patterns, mode)) {
      return {active: false, offsetMs: 0, duty: 0, depth: 0, full: 1, pressure: 0,
        flame: false, energy: 0, texture: 1, accent: false, phrase: 0, phraseIndex: 0};
    }
    seed = Math.floor(clamp(seed, 1, 2147483646, 1));
    cycle = Math.floor(clamp(cycle, 0, 2147483646, 0));
    const phraseIndex = Math.floor(cycle / 8), slot = cycle % 8;
    const salt = mode === 'launch' ? 17431 : 39041;
    const phrase = sequenceChoice(seed, phraseIndex, 6, salt);
    const texture = sequenceChoice(seed, phraseIndex, 6, salt + 601);
    const strength = patterns[mode][phrase - 1][slot] / 100;
    const random = randomFor((seed + cycle * 7919 + salt + 23497) % 2147483646);
    const offsetMs = Math.floor(random() * 11);
    const duty = clamp((mode === 'launch' ? 0.28 : 0.22) + strength * 0.27
      + (random() - 0.5) * 0.10, 0.18, 0.70, 0.3);
    const depth = clamp(0.24 + strength * 0.48 + (random() - 0.5) * 0.18, 0.18, 0.88, 0.5);
    const full = clamp(0.58 + strength * 0.46 + (random() - 0.5) * 0.10, 0.55, 1.10, 1);
    const pressure = clamp(0.20 + strength * 0.75 + (random() - 0.5) * 0.12, 0.20, 1.10, 0.5);
    const energy = clamp(0.22 + strength * 0.75 + (random() - 0.5) * 0.16, 0.20, 1.15, 0.5);
    const flame = strength >= 0.62 && random() < (mode === 'launch' ? 0.62 : 0.55);
    const accent = slot === 0 && strength >= 0.84 && random() < 0.35;
    return {active: strength > 0, offsetMs, duty, depth, full, pressure,
      flame: flame || accent, energy, texture, accent, phrase, phraseIndex};
  }
  window.PopsALSPattern = Object.freeze({cut});
})();
