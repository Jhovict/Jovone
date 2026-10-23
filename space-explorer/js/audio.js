// Áudio sintetizado com Web Audio (sem arquivos externos).
SE.Audio = (function () {
  let ctx = null, master = null, sfxBus = null, musicBus = null;
  let muted = false;
  let musicOn = false, nextNoteTime = 0, step = 0, schedTimer = null;
  let noiseBuf = null;

  function init() {
    if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = muted ? 0 : 0.8;
    master.connect(ctx.destination);
    sfxBus = ctx.createGain(); sfxBus.gain.value = 0.55; sfxBus.connect(master);
    musicBus = ctx.createGain(); musicBus.gain.value = 0.0; musicBus.connect(master);

    // Eco espacial leve para a música
    const delay = ctx.createDelay(1.0); delay.delayTime.value = 0.42;
    const fb = ctx.createGain(); fb.gain.value = 0.35;
    const wet = ctx.createGain(); wet.gain.value = 0.35;
    musicBus.connect(delay); delay.connect(fb); fb.connect(delay); delay.connect(wet); wet.connect(master);

    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 1.0, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }

  function env(g, t, a, peak, dur) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  }

  function tone(type, f0, f1, dur, vol, delay, dest) {
    if (!ctx) return;
    const t = ctx.currentTime + (delay || 0);
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(f0, t);
    if (f1 && f1 !== f0) o.frequency.exponentialRampToValueAtTime(f1, t + dur);
    env(g, t, 0.008, vol, dur);
    o.connect(g); g.connect(dest || sfxBus);
    o.start(t); o.stop(t + dur + 0.05);
  }

  function noise(dur, vol, freq, q, delay, type) {
    if (!ctx) return;
    const t = ctx.currentTime + (delay || 0);
    const s = ctx.createBufferSource(); s.buffer = noiseBuf;
    const f = ctx.createBiquadFilter(); f.type = type || 'bandpass'; f.frequency.value = freq; f.Q.value = q || 1;
    const g = ctx.createGain();
    env(g, t, 0.005, vol, dur);
    s.connect(f); f.connect(g); g.connect(sfxBus);
    s.start(t); s.stop(t + dur + 0.05);
  }

  let crystalCombo = 0, lastCrystal = 0;

  const sfx = {
    jump: function () { tone('square', 260, 520, 0.12, 0.10); tone('sine', 520, 900, 0.12, 0.08); },
    land: function (h) { noise(0.09, 0.12 + 0.15 * (h || 0), 300, 0.8, 0, 'lowpass'); },
    step: function () { noise(0.04, 0.035, 900, 2); },
    crystal: function () {
      const now = ctx ? ctx.currentTime : 0;
      crystalCombo = (now - lastCrystal < 0.9) ? Math.min(crystalCombo + 1, 10) : 0;
      lastCrystal = now;
      const base = 880 * Math.pow(2, crystalCombo / 12 * 1.0);
      tone('sine', base, base, 0.25, 0.14);
      tone('triangle', base * 1.5, base * 1.5, 0.18, 0.06, 0.05);
    },
    core: function () {
      [523, 659, 784, 1047, 1319].forEach(function (f, i) { tone('triangle', f, f, 0.35, 0.12, i * 0.07); tone('sine', f * 2, f * 2, 0.3, 0.04, i * 0.07); });
    },
    stomp: function () { tone('square', 400, 120, 0.14, 0.09); noise(0.1, 0.12, 1500, 1.5); },
    pad: function () { tone('sine', 180, 900, 0.35, 0.16); tone('triangle', 360, 1400, 0.3, 0.05); noise(0.3, 0.06, 2500, 0.7, 0, 'highpass'); },
    hurt: function () { tone('sawtooth', 600, 70, 0.45, 0.10); noise(0.35, 0.18, 800, 0.6); },
    checkpoint: function () { [659, 880, 1175].forEach(function (f, i) { tone('sine', f, f, 0.4, 0.12, i * 0.09); }); },
    crumble: function () { noise(0.25, 0.08, 600, 0.7); },
    laser: function () { tone('sawtooth', 120, 140, 0.15, 0.025); },
    win: function () {
      const seq = [523, 659, 784, 1047, 784, 1047, 1319, 1568];
      seq.forEach(function (f, i) { tone('triangle', f, f, 0.45, 0.12, i * 0.11); tone('sine', f / 2, f / 2, 0.5, 0.06, i * 0.11); });
    },
    ui: function () { tone('sine', 700, 1000, 0.08, 0.08); },
    uiMove: function () { tone('sine', 520, 560, 0.05, 0.05); },
    start: function () { [392, 523, 784].forEach(function (f, i) { tone('triangle', f, f * 1.01, 0.3, 0.1, i * 0.08); }); },
  };

  // Música ambiente: acordes suaves e arpejo cristalino, agendados com antecedência.
  const CHORDS = [
    [220.0, 261.6, 329.6, 392.0],  // Am7
    [174.6, 220.0, 261.6, 329.6],  // Fmaj7
    [196.0, 246.9, 293.7, 392.0],  // G
    [164.8, 207.7, 246.9, 329.6],  // E
  ];
  const BEAT = 0.42;

  function scheduleMusic() {
    if (!ctx || !musicOn) return;
    while (nextNoteTime < ctx.currentTime + 0.6) {
      const bar = Math.floor(step / 8) % CHORDS.length;
      const ch = CHORDS[bar];
      const t0 = nextNoteTime - ctx.currentTime;
      if (step % 8 === 0) {
        ch.forEach(function (f) { pad(f / 2, BEAT * 8.4, nextNoteTime); });
        tone('sine', ch[0] / 4, ch[0] / 4, BEAT * 7, 0.09, t0, musicBus);
      }
      const pattern = [0, 2, 1, 3, 2, 1, 3, 2];
      if (step % 2 === 0 || Math.random() < 0.35) {
        const f = ch[pattern[step % 8]] * 2;
        tone('sine', f, f, 0.5, 0.045, t0, musicBus);
      }
      nextNoteTime += BEAT;
      step++;
    }
  }

  function pad(f, dur, t) {
    const o = ctx.createOscillator();
    const o2 = ctx.createOscillator();
    const fl = ctx.createBiquadFilter();
    const g = ctx.createGain();
    o.type = 'sawtooth'; o2.type = 'triangle';
    o.frequency.value = f; o2.frequency.value = f * 1.004;
    fl.type = 'lowpass'; fl.frequency.value = 700; fl.Q.value = 0.5;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(0.022, t + dur * 0.35);
    g.gain.linearRampToValueAtTime(0.0001, t + dur);
    o.connect(fl); o2.connect(fl); fl.connect(g); g.connect(musicBus);
    o.start(t); o2.start(t); o.stop(t + dur + 0.1); o2.stop(t + dur + 0.1);
  }

  function startMusic() {
    if (!ctx || musicOn) return;
    musicOn = true;
    nextNoteTime = ctx.currentTime + 0.1;
    musicBus.gain.cancelScheduledValues(ctx.currentTime);
    musicBus.gain.setTargetAtTime(0.9, ctx.currentTime, 0.8);
    schedTimer = setInterval(scheduleMusic, 120);
  }

  function setMusicLevel(v) {
    if (!ctx) return;
    musicBus.gain.setTargetAtTime(v, ctx.currentTime, 0.3);
  }

  function toggleMute() {
    muted = !muted;
    if (master) master.gain.setTargetAtTime(muted ? 0 : 0.8, ctx.currentTime, 0.05);
    return muted;
  }

  function play(name, arg) {
    if (!ctx || muted) return;
    const f = sfx[name];
    if (f) f(arg);
  }

  return { init, play, startMusic, setMusicLevel, toggleMute, get muted() { return muted; } };
})();
