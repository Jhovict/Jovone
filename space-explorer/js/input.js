// Entrada: teclado, mouse (menus), botões touch e controle (Gamepad API).
SE.Input = (function () {
  const MAP = {
    left: ['ArrowLeft', 'KeyA'],
    right: ['ArrowRight', 'KeyD'],
    up: ['ArrowUp', 'KeyW'],
    down: ['ArrowDown', 'KeyS'],
    jump: ['Space', 'ArrowUp', 'KeyW', 'KeyZ', 'KeyK'],
    confirm: ['Enter', 'Space', 'NumpadEnter'],
    pause: ['Escape', 'KeyP'],
    restart: ['KeyR'],
    mute: ['KeyM'],
  };

  const held = {};
  const hits = {};
  const touch = { left: false, right: false, jump: false };
  const touchHits = {};
  let pointer = null; // último clique/toque no canvas (coordenadas lógicas)
  let usedTouch = false;
  let anyGesture = [];

  // Controle: A pula/confirma, Start pausa, Select/Back reinicia; direcional ou analógico move e navega nos menus
  const padHeld = {}, padHits = {};
  function pollPad() {
    const list = navigator.getGamepads ? navigator.getGamepads() : [];
    let gp = null;
    for (let i = 0; i < list.length; i++) if (list[i]) { gp = list[i]; break; }
    const b = function (i) { return !!(gp && gp.buttons[i] && gp.buttons[i].pressed); };
    const ax = gp ? gp.axes[0] || 0 : 0, ay = gp ? gp.axes[1] || 0 : 0;
    const now = {
      left: b(14) || ax < -0.5,
      right: b(15) || ax > 0.5,
      up: b(12) || ay < -0.5,
      down: b(13) || ay > 0.5,
      jump: b(0),
      confirm: b(0),
      pause: b(9),
      restart: b(8),
    };
    let any = false;
    for (const k in now) {
      padHits[k] = now[k] && !padHeld[k];
      if (padHits[k]) any = true;
      padHeld[k] = now[k];
    }
    if (any) gesture();
  }

  function onKeyDown(e) {
    if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Space'].includes(e.code)) e.preventDefault();
    if (!held[e.code]) hits[e.code] = true;
    held[e.code] = true;
    gesture();
  }
  function onKeyUp(e) { held[e.code] = false; }
  function onBlur() { for (const k in held) held[k] = false; touch.left = touch.right = touch.jump = false; }

  function gesture() { anyGesture.forEach(function (f) { f(); }); }

  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', onKeyUp);
  window.addEventListener('blur', onBlur);

  function isDown(action) {
    const codes = MAP[action];
    for (let i = 0; i < codes.length; i++) if (held[codes[i]]) return true;
    return !!touch[action] || !!padHeld[action];
  }

  function wasHit(action) {
    const codes = MAP[action];
    for (let i = 0; i < codes.length; i++) if (hits[codes[i]]) return true;
    return !!touchHits[action] || !!padHits[action];
  }

  function endFrame() {
    for (const k in hits) hits[k] = false;
    for (const k in touchHits) touchHits[k] = false;
    pointer = null;
    pollPad();
  }

  function bindTouch(root) {
    const el = root.querySelector('#touch');
    if (!el) return;
    el.querySelectorAll('[data-act]').forEach(function (btn) {
      const act = btn.getAttribute('data-act');
      const start = function (e) {
        e.preventDefault();
        usedTouch = true;
        btn.classList.add('active');
        if (!touch[act]) touchHits[act] = true;
        touch[act] = true;
        if (act === 'jump') touchHits.confirm = true;
        gesture();
      };
      const end = function (e) {
        e.preventDefault();
        btn.classList.remove('active');
        touch[act] = false;
      };
      btn.addEventListener('touchstart', start, { passive: false });
      btn.addEventListener('touchend', end, { passive: false });
      btn.addEventListener('touchcancel', end, { passive: false });
      btn.addEventListener('mousedown', start);
      btn.addEventListener('mouseup', end);
      btn.addEventListener('mouseleave', end);
    });
  }

  function bindCanvas(canvas, toLogical) {
    const handler = function (e) {
      const t = e.changedTouches ? e.changedTouches[0] : e;
      if (e.changedTouches) usedTouch = true;
      pointer = toLogical(t.clientX, t.clientY);
      gesture();
    };
    canvas.addEventListener('mousedown', handler);
    canvas.addEventListener('touchstart', function (e) { handler(e); }, { passive: true });
  }

  return {
    isDown, wasHit, endFrame, bindTouch, bindCanvas,
    get pointer() { return pointer; },
    get usedTouch() { return usedTouch; },
    onGesture: function (f) { anyGesture.push(f); },
  };
})();
