// Estado em tempo real da fase: objetos, perigos, coleta, checkpoints, objetivo e câmera.
SE.createWorld = function (levelKey) {
  const C = SE.CONFIG, U = SE.U, P = SE.Particles, A = SE.Audio, Art = SE.Art;
  const TAU = Math.PI * 2;
  const L = SE.LEVELS[levelKey].build();
  const VW = C.VIEW_W, VH = C.VIEW_H;

  function copy(o, extra) { return Object.assign({}, o, extra); }

  const W = {
    L: L,
    time: 0,
    titleMode: false,
    solids: L.solids.filter(function (s) { return !s.oneWay; }),
    ledges: L.solids.filter(function (s) { return s.oneWay; }).map(function (s) { return copy(s, { off: false }); }),
    movers: L.movers.map(function (m) { return copy(m, { kind: 'mover', x: m.x0, y: m.y0, mdx: 0, mdy: 0, off: false }); }),
    crumbles: L.crumbles.map(function (c) { return copy(c, { kind: 'crumble', x: c.x0, y: c.y0, state: 'idle', t: 0, vy: 0, alpha: 1, off: false }); }),
    pads: L.pads.map(function (p) { return copy(p, { fx: 0 }); }),
    spikes: L.spikes,
    lasers: L.lasers.map(function (l) { return copy(l, { isOn: false, warn: false }); }),
    mites: L.mites.map(function (m) { return copy(m, { x: (m.x1 + m.x2) / 2, dir: 1, alive: true, deadT: 0 }); }),
    crystals: L.crystals.map(function (c) { return copy(c, { taken: false }); }),
    cores: L.cores.map(function (c) { return copy(c, { taken: false }); }),
    checkpoints: L.checkpoints.map(function (c) { return copy(c, { active: false }); }),
    signs: L.signs, decor: L.decor, goal: L.goal,
    stats: { crystals: 0, cores: 0, falls: 0, time: 0 },
    bump: { crystal: 0, core: 0 },
    respawn: { x: L.spawn.x, y: L.spawn.y },
    respawnT: 0, flash: 0, shake: 0,
    complete: false, completeT: 0,
    cam: { x: 0, y: 0 }, lookX: 0, camBase: L.spawn.y,
  };
  W.platforms = W.ledges.concat(W.movers, W.crumbles);
  W.totalCrystals = W.crystals.length;
  W.totalCores = W.cores.length;

  const player = SE.createPlayer();
  player.reset(L.spawn.x, L.spawn.y);
  player.sx = 1; player.sy = 1;
  W.player = player;

  // ---------------- câmera ----------------
  function camTarget() {
    const cc = C.camera;
    const tx = player.cx - VW * cc.anchorX + W.lookX;
    if (player.ground) W.camBase = player.bottom;
    let ref = W.camBase;
    if (player.bottom < W.camBase - 200) ref = player.bottom + 200;
    if (player.bottom > W.camBase + 60) ref = player.bottom - 60;
    return {
      x: U.clamp(tx, L.left, L.right - VW),
      y: U.clamp(ref - 540, cc.minY, cc.maxY),
    };
  }
  function snapCamera() {
    W.lookX = player.facing * C.camera.lookAhead;
    const t = camTarget();
    W.cam.x = t.x; W.cam.y = t.y;
  }
  snapCamera();

  function updateCamera(dt) {
    if (W.titleMode) {
      W.cam.x = 40 + (1 - Math.cos(W.time * 0.045)) * 650;
      W.cam.y = -20 + Math.sin(W.time * 0.08) * 20;
      return;
    }
    if (player.dead) return;
    W.lookX = U.damp(W.lookX, player.facing * C.camera.lookAhead, 2.2, dt);
    const t = camTarget();
    W.cam.x = U.damp(W.cam.x, t.x, C.camera.smoothX, dt);
    W.cam.y = U.damp(W.cam.y, t.y, C.camera.smoothY, dt);
  }

  // ---------------- objetos ----------------
  function updateMovers() {
    for (let i = 0; i < W.movers.length; i++) {
      const m = W.movers[i];
      const k = 0.5 - 0.5 * Math.cos(TAU * (W.time / m.period + m.phase));
      const nx = m.x0 + m.dx * k, ny = m.y0 + m.dy * k;
      m.mdx = nx - m.x; m.mdy = ny - m.y;
      m.x = nx; m.y = ny;
    }
  }

  W.touchCrumble = function (c) {
    if (c.state === 'idle' && c.alpha > 0.9) { c.state = 'shake'; c.t = 0; A.play('crumble'); }
  };

  function updateCrumbles(dt) {
    for (let i = 0; i < W.crumbles.length; i++) {
      const c = W.crumbles[i];
      c.t += dt;
      if (c.state === 'idle') {
        c.alpha = Math.min(1, c.alpha + dt * 3);
        if (player.ground === c) W.touchCrumble(c);
      } else if (c.state === 'shake') {
        if (Math.random() < 0.25) P.spawn({ x: c.x + Math.random() * c.w, y: c.y + c.h, vy: 60, life: 0.4, size: 2, color: '#cdf3ff', grav: 600 });
        if (c.t >= 0.55) {
          c.state = 'fall'; c.t = 0; c.vy = 0;
          A.play('crumble');
          P.fx.debris(c.x + c.w / 2, c.y + c.h / 2, ['#e3f8ff', '#9fdcf5', '#5aa6d6'], 10);
        }
      } else if (c.state === 'fall') {
        c.vy += 1800 * dt; c.y += c.vy * dt;
        c.alpha = Math.max(0, 1 - c.t / 0.6);
        if (c.t > 0.7) { c.state = 'gone'; c.t = 0; }
      } else if (c.state === 'gone') {
        if (c.t > 2.5) { c.state = 'idle'; c.t = 0; c.x = c.x0; c.y = c.y0; c.alpha = 0; }
      }
      c.off = !(c.state === 'idle' || c.state === 'shake') || c.alpha < 0.6;
      if (c.off && player.ground === c) player.ground = null;
    }
  }

  function updateLasers() {
    for (let i = 0; i < W.lasers.length; i++) {
      const l = W.lasers[i];
      const cycle = l.on + l.off;
      const tt = U.clamp(((W.time + l.phase) % cycle + cycle) % cycle, 0, cycle);
      const was = l.isOn;
      l.isOn = tt < l.on;
      l.warn = !l.isOn && tt > cycle - 0.45;
      if (l.isOn && !was && !W.titleMode && Math.abs(player.cx - l.x) < 700) A.play('laser');
    }
  }

  function updateMites(dt) {
    for (let i = 0; i < W.mites.length; i++) {
      const m = W.mites[i];
      if (!m.alive) { m.deadT += dt; continue; }
      m.x += m.dir * 70 * dt;
      if (m.x > m.x2) { m.x = m.x2; m.dir = -1; }
      if (m.x < m.x1) { m.x = m.x1; m.dir = 1; }
    }
  }

  // ---------------- interações ----------------
  function hurtBox() { return { x: player.x + 5, y: player.y + 8, w: player.w - 10, h: player.h - 10 }; }

  function kill() {
    if (player.dead || player.invuln > 0) return;
    player.die();
    W.stats.falls++;
    W.respawnT = 0;
    W.shake = 0.35;
    A.play('hurt');
    P.fx.debris(player.cx, player.y + 20, ['#ffffff', '#ff8a3d', '#cdd4ea', '#7ff6ff'], 14);
    P.fx.burst(player.cx, player.y + 25, '#ff4d8d', 18, 320);
  }

  function checkHazards(inp) {
    const hb = hurtBox();
    for (let i = 0; i < W.spikes.length; i++) {
      const s = W.spikes[i];
      if (U.overlap(hb, { x: s.x + 4, y: s.y + 10, w: s.w - 8, h: s.h - 10 })) { kill(); return; }
    }
    for (let i = 0; i < W.lasers.length; i++) {
      const l = W.lasers[i];
      if (l.isOn && U.overlap(hb, { x: l.x - 5, y: l.top, w: 10, h: l.bottom - l.top })) { kill(); return; }
    }
    for (let i = 0; i < W.mites.length; i++) {
      const m = W.mites[i];
      if (!m.alive) continue;
      const box = { x: m.x - 18, y: m.y - 26, w: 36, h: 26 };
      if (!U.overlap(player, box)) continue;
      const prevBottom = player.prevY + player.h;
      if (player.vy > 0 && prevBottom <= box.y + 14) {
        m.alive = false; m.deadT = 0;
        player.vy = -(inp.jumpHeld ? C.player.stompVelHeld : C.player.stompVel);
        player.jumping = false; player.ground = null;
        player.sx = 0.8; player.sy = 1.2;
        A.play('stomp');
        P.fx.burst(m.x, m.y - 12, '#ff4d8d', 12, 240);
        P.fx.ring(m.x, m.y - 10, '#ff8ab4', 8, 0.35);
        W.shake = 0.12;
      } else if (U.overlap(hb, box)) {
        kill(); return;
      }
    }
    if (player.y > C.killY) kill();
  }

  function collect() {
    const cx = player.cx, cy = player.y + player.h / 2;
    for (let i = 0; i < W.crystals.length; i++) {
      const c = W.crystals[i];
      if (c.taken) continue;
      if (Math.abs(c.x - cx) < 15 + player.w / 2 && Math.abs(c.y - cy) < 15 + player.h / 2) {
        c.taken = true;
        W.stats.crystals++;
        W.bump.crystal = 1;
        A.play('crystal');
        P.fx.sparkle(c.x, c.y, '#9ff3ff', 6);
        P.fx.ring(c.x, c.y, '#7fe3ff', 6, 0.3);
      }
    }
    for (let i = 0; i < W.cores.length; i++) {
      const c = W.cores[i];
      if (c.taken) continue;
      if (Math.abs(c.x - cx) < 22 + player.w / 2 && Math.abs(c.y - cy) < 22 + player.h / 2) {
        c.taken = true;
        W.stats.cores++;
        W.bump.core = 1;
        A.play('core');
        P.fx.sparkle(c.x, c.y, '#ffd27a', 14);
        P.fx.ring(c.x, c.y, '#ffe1a0', 10, 0.6);
        P.fx.burst(c.x, c.y, '#ffd27a', 16, 300);
      }
    }
  }

  function checkpoints() {
    for (let i = 0; i < W.checkpoints.length; i++) {
      const cp = W.checkpoints[i];
      if (cp.active) continue;
      if (player.cx >= cp.x - 10 && Math.abs(player.bottom - cp.y) < 160) {
        cp.active = true;
        if (cp.x > W.respawn.x) W.respawn = { x: cp.x, y: cp.y };
        A.play('checkpoint');
        P.fx.sparkle(cp.x, cp.y - 90, '#9ff3ff', 12);
        P.fx.ring(cp.x, cp.y - 89, '#7ff6ff', 8, 0.5);
      }
    }
  }

  function checkGoal() {
    const g = W.goal;
    if (!g || W.complete) return;
    if (player.cx >= g.x - 40 && player.bottom <= g.y + 4 && player.bottom > g.y - 220) {
      W.complete = true; W.completeT = 0;
      player.auto = g.x;
      A.play('win');
      A.setMusicLevel(0.35);
      P.fx.sparkle(g.x, g.y - 60, '#ffe1a0', 20);
      P.fx.ring(g.x, g.y - 40, '#bff8ff', 14, 0.7);
    }
  }

  function respawnPlayer() {
    player.reset(W.respawn.x, W.respawn.y);
    player.invuln = 0.8;
    for (let i = 0; i < W.crumbles.length; i++) {
      const c = W.crumbles[i];
      c.state = 'idle'; c.x = c.x0; c.y = c.y0; c.alpha = 1; c.t = 0; c.off = false;
    }
    W.flash = 1;
    snapCamera();
  }

  // Altura do chão logo abaixo de um ponto (para a sombra)
  W.groundBelow = function (x, y) {
    let best = null;
    const test = function (o) {
      if (o.off) return;
      if (x < o.x || x > o.x + o.w) return;
      if (o.y < y - 2) return;
      if (best === null || o.y < best) best = o.y;
    };
    for (let i = 0; i < W.solids.length; i++) test(W.solids[i]);
    for (let i = 0; i < W.platforms.length; i++) test(W.platforms[i]);
    return best;
  };

  W.progress = function () {
    const a = L.spawn.x, b = W.goal.x;
    return U.clamp((player.cx - a) / (b - a), 0, 1);
  };

  // ---------------- passo de simulação ----------------
  W.update = function (dt, inp) {
    W.time += dt;
    if (!W.complete && !W.titleMode) W.stats.time += dt;
    W.bump.crystal = Math.max(0, W.bump.crystal - dt * 3);
    W.bump.core = Math.max(0, W.bump.core - dt * 2);
    W.flash = Math.max(0, W.flash - dt * 2.5);
    W.shake = Math.max(0, W.shake - dt);

    updateMovers();
    updateCrumbles(dt);
    updateLasers();
    updateMites(dt);
    for (let i = 0; i < W.pads.length; i++) W.pads[i].fx = Math.max(0, W.pads[i].fx - dt * 2.2);

    player.update(dt, W, inp);

    if (!player.dead && !W.complete && !W.titleMode) {
      checkHazards(inp);
      if (!player.dead) { collect(); checkpoints(); checkGoal(); }
    }
    if (player.dead) {
      W.respawnT += dt;
      if (W.respawnT >= C.respawnDelay) respawnPlayer();
    }
    if (W.complete) W.completeT += dt;

    updateCamera(dt);
    P.update(dt);
  };

  // ---------------- desenho ----------------
  W.render = function (ctx) {
    const t = W.time;
    let camX = W.cam.x, camY = W.cam.y;
    if (W.shake > 0) {
      const k = W.shake * 14;
      camX += (Math.random() - 0.5) * k; camY += (Math.random() - 0.5) * k;
    }
    const cam = { x: camX, y: camY };
    SE.BG.drawBack(ctx, cam, t);

    const left = camX - 260, right = camX + VW + 260, bottom = camY + VH;
    const vis = function (x, w) { return x + w > left && x < right; };

    ctx.save();
    ctx.translate(-camX, -camY);

    for (let i = 0; i < W.decor.length; i++) { const d = W.decor[i]; if (vis(d.x - 80, 160)) Art.drawDecor(ctx, d, t); }
    if (W.goal && vis(W.goal.x - 240, 480)) Art.drawStation(ctx, W.goal, t, W.complete);
    for (let i = 0; i < W.signs.length; i++) { const s = W.signs[i]; if (vis(s.x - 150, 300)) Art.drawSign(ctx, s, t); }
    for (let i = 0; i < W.checkpoints.length; i++) { const c = W.checkpoints[i]; if (vis(c.x - 170, 340)) Art.drawCheckpoint(ctx, c, t); }

    for (let i = 0; i < W.solids.length; i++) {
      const s = W.solids[i];
      if (!vis(s.x, s.w)) continue;
      if (s.kind === 'metal') Art.drawMetal(ctx, s, t); else Art.drawRock(ctx, s, bottom);
    }
    for (let i = 0; i < W.ledges.length; i++) { const s = W.ledges[i]; if (vis(s.x, s.w)) Art.drawLedge(ctx, s); }
    for (let i = 0; i < W.crumbles.length; i++) { const c = W.crumbles[i]; if (vis(c.x, c.w)) Art.drawCrumble(ctx, c, t); }
    for (let i = 0; i < W.movers.length; i++) { const m = W.movers[i]; if (vis(m.x, m.w)) Art.drawMover(ctx, m, t); }
    for (let i = 0; i < W.pads.length; i++) { const p = W.pads[i]; if (vis(p.x - 40, p.w + 80)) Art.drawPad(ctx, p, t); }
    for (let i = 0; i < W.spikes.length; i++) { const s = W.spikes[i]; if (vis(s.x, s.w)) Art.drawSpikes(ctx, s); }
    for (let i = 0; i < W.lasers.length; i++) { const l = W.lasers[i]; if (vis(l.x - 30, 60)) Art.drawLaserBase(ctx, { x: l.x, top: l.top, bottom: l.bottom, on: l.isOn, warn: l.warn }); }

    for (let i = 0; i < W.crystals.length; i++) { const c = W.crystals[i]; if (!c.taken && vis(c.x - 20, 40)) Art.drawCrystal(ctx, c.x, c.y, t); }
    for (let i = 0; i < W.cores.length; i++) { const c = W.cores[i]; if (!c.taken && vis(c.x - 40, 80)) Art.drawCore(ctx, c.x, c.y + Math.sin(t * 2 + i) * 5, t, 1.1); }
    for (let i = 0; i < W.mites.length; i++) { const m = W.mites[i]; if (vis(m.x - 30, 60)) Art.drawMite(ctx, m, t); }

    if (!player.dead && player.alpha > 0) {
      const gy = W.groundBelow(player.cx, player.bottom);
      if (gy !== null) Art.drawShadow(ctx, player.cx, gy, gy - player.bottom);
    }
    player.draw(ctx, t);

    for (let i = 0; i < W.lasers.length; i++) { const l = W.lasers[i]; if (vis(l.x - 30, 60)) Art.drawLaserBeam(ctx, { x: l.x, top: l.top, bottom: l.bottom, on: l.isOn, warn: l.warn }, t); }
    P.draw(ctx);
    ctx.restore();

    SE.BG.drawFront(ctx, cam, t);

    // escurece antes do respawn e clareia depois
    let dark = W.flash;
    if (player.dead) dark = Math.max(dark, U.clamp((W.respawnT - (C.respawnDelay - 0.35)) / 0.35, 0, 1));
    if (dark > 0) { ctx.fillStyle = 'rgba(7,5,26,' + dark.toFixed(3) + ')'; ctx.fillRect(0, 0, VW, VH); }
  };

  return W;
};
