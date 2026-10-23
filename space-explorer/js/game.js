// Loop principal, estados do jogo e ajuste de tela.
(function () {
  const C = SE.CONFIG, I = SE.Input, A = SE.Audio, UI = SE.UI, P = SE.Particles;
  const VW = C.VIEW_W, VH = C.VIEW_H;
  const LEVEL = 'saturn';
  const BEST_KEY = 'spaceExplorer.best.' + LEVEL;

  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');
  const touchEl = document.getElementById('touch');
  const voltarEl = document.getElementById('voltar');
  const isTouch = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;

  // ---------- tela ----------
  let scaleX = 1, scaleY = 1;
  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const s = Math.min(window.innerWidth / VW, window.innerHeight / VH);
    const cssW = Math.floor(VW * s), cssH = Math.floor(VH * s);
    canvas.style.width = cssW + 'px';
    canvas.style.height = cssH + 'px';
    canvas.width = Math.round(cssW * dpr);
    canvas.height = Math.round(cssH * dpr);
    scaleX = canvas.width / VW; scaleY = canvas.height / VH;
  }
  window.addEventListener('resize', resize);
  resize();

  function toLogical(cx, cy) {
    const r = canvas.getBoundingClientRect();
    return { x: (cx - r.left) / r.width * VW, y: (cy - r.top) / r.height * VH };
  }

  I.bindTouch(document);
  I.bindCanvas(canvas, toLogical);

  // O áudio só pode começar depois de um gesto do usuário
  I.onGesture(function () {
    A.init();
    A.startMusic();
  });

  function loadBest() { try { const v = parseFloat(localStorage.getItem(BEST_KEY)); return isFinite(v) ? v : 0; } catch (e) { return 0; } }
  function saveBest(v) { try { localStorage.setItem(BEST_KEY, String(v)); } catch (e) { /* sem armazenamento */ } }

  // ---------- estados ----------
  let state = 'title';
  let world = null;
  let best = loadBest();
  let record = false;
  let acc = 0;
  let pendingJump = false;

  function toTitle() {
    P.clear();
    world = SE.createWorld(LEVEL);
    world.titleMode = true;
    state = 'title';
    A.setMusicLevel(0.9);
  }

  function newGame() {
    P.clear();
    world = SE.createWorld(LEVEL);
    state = 'playing';
    acc = 0; pendingJump = false;
    A.setMusicLevel(0.9);
  }

  function pause() {
    if (state !== 'playing') return;
    state = 'paused';
    UI.resetMenu();
    A.play('ui');
    A.setMusicLevel(0.35);
  }

  function resume() {
    state = 'playing';
    acc = 0; pendingJump = false;
    A.setMusicLevel(0.9);
  }

  document.addEventListener('visibilitychange', function () { if (document.hidden) pause(); });

  toTitle();

  // Acesso para depuração pelo console do navegador
  SE.debug = { get world() { return world; }, get state() { return state; } };

  const NEUTRAL = { move: 0, jumpHeld: false, jumpPressed: false, down: false };

  function simulate(dt, inp) {
    acc += dt;
    let n = 0;
    while (acc >= C.STEP && n < 14) {
      if (inp !== NEUTRAL) { inp.jumpPressed = pendingJump; pendingJump = false; }
      world.update(C.STEP, inp);
      acc -= C.STEP; n++;
    }
    if (n >= 14) acc = 0;
  }

  // ---------- loop ----------
  let last = performance.now();
  function frame(now) {
    const dt = Math.min((now - last) / 1000, C.MAX_FRAME);
    last = now;

    if (I.wasHit('mute')) A.toggleMute();
    UI.update(dt);

    if (state === 'title') {
      simulate(dt, NEUTRAL);
      if (!UI.busy && (I.wasHit('confirm') || I.pointer)) {
        A.play('start');
        UI.fadeTo(newGame);
      }
    } else if (state === 'playing') {
      if (!UI.busy && I.wasHit('pause')) {
        pause();
      } else if (!UI.busy && I.wasHit('restart')) {
        UI.fadeTo(newGame);
      } else {
        if (I.wasHit('jump')) pendingJump = true;
        const inp = {
          move: (I.isDown('right') ? 1 : 0) - (I.isDown('left') ? 1 : 0),
          jumpHeld: I.isDown('jump'),
          jumpPressed: false,
          down: I.isDown('down'),
        };
        simulate(dt, inp);
        if (world.complete && world.completeT > 1.6) {
          state = 'complete';
          UI.resetMenu();
          const t = world.stats.time;
          record = !best || t < best;
          if (record) { best = t; saveBest(t); }
        }
      }
    } else if (state === 'paused') {
      let pick = UI.pauseMenu();
      if (I.wasHit('pause') && !UI.busy) pick = 0;
      if (pick === 0) { A.play('ui'); resume(); }
      else if (pick === 1) UI.fadeTo(newGame);
      else if (pick === 2) UI.fadeTo(toTitle);
      else if (pick === 3) UI.fadeTo(function () { location.href = '../'; });
    } else if (state === 'complete') {
      simulate(dt, NEUTRAL);
      const pick = UI.completeMenu();
      if (pick === 0) UI.fadeTo(newGame);
      else if (pick === 1) UI.fadeTo(toTitle);
    }

    // ---------- desenho ----------
    ctx.setTransform(scaleX, 0, 0, scaleY, 0, 0);
    world.render(ctx);
    const touchOn = isTouch && state === 'playing';
    if (state === 'title') UI.drawTitle(ctx, world.time, best, isTouch);
    else UI.drawHUD(ctx, world, touchOn);
    if (state === 'paused') UI.drawPause(ctx, world.time);
    if (state === 'complete') UI.drawComplete(ctx, world, world.time, record);
    UI.drawFade(ctx);

    touchEl.classList.toggle('on', state === 'playing');
    if (voltarEl) voltarEl.classList.toggle('off', state !== 'title');
    I.endFrame();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
