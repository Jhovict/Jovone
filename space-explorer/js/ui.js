// Interface: HUD, tela inicial, pausa, tela de conclusão e transições com fade.
SE.UI = (function () {
  const U = SE.U, F = U.FONT, I = SE.Input, A = SE.Audio, Art = SE.Art;
  const VW = SE.CONFIG.VIEW_W, VH = SE.CONFIG.VIEW_H;
  const TAU = Math.PI * 2;

  let fade = 0, fadeDir = 0, fadeCb = null;
  let sel = 0, openT = 0;

  function fadeTo(cb) {
    if (fadeDir !== 0) return;
    fadeDir = 1; fadeCb = cb;
  }

  function update(dt) {
    openT += dt;
    if (fadeDir === 1) {
      fade += dt / 0.35;
      if (fade >= 1) { fade = 1; fadeDir = -1; const cb = fadeCb; fadeCb = null; if (cb) cb(); }
    } else if (fadeDir === -1) {
      fade -= dt / 0.4;
      if (fade <= 0) { fade = 0; fadeDir = 0; }
    }
  }

  function resetMenu() { sel = 0; openT = 0; }

  function text(ctx, s, x, y, size, color, align, weight) {
    ctx.font = (weight || 'bold') + ' ' + size + 'px ' + F;
    ctx.textAlign = align || 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = color;
    ctx.fillText(s, x, y);
  }

  function panel(ctx, x, y, w, h, r) {
    U.roundRect(ctx, x, y, w, h, r || 18);
    ctx.fillStyle = 'rgba(16,10,44,0.86)'; ctx.fill();
    ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(150,225,255,0.45)'; ctx.stroke();
  }

  // ---------------- menus ----------------
  function layout(items, cx, y0) {
    return items.map(function (label, i) { return { x: cx - 160, y: y0 + i * 64, w: 320, h: 50, label: label }; });
  }

  // Retorna o índice escolhido ou -1
  function menuInput(rects) {
    if (fadeDir !== 0 || openT < 0.15) return -1;
    if (I.wasHit('down')) { sel = (sel + 1) % rects.length; A.play('uiMove'); }
    if (I.wasHit('up')) { sel = (sel + rects.length - 1) % rects.length; A.play('uiMove'); }
    const p = I.pointer;
    if (p) {
      for (let i = 0; i < rects.length; i++) {
        const r = rects[i];
        if (p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) { sel = i; A.play('ui'); return i; }
      }
    }
    if (I.wasHit('confirm')) { A.play('ui'); return sel; }
    return -1;
  }

  function drawMenu(ctx, rects, t) {
    rects.forEach(function (r, i) {
      const on = i === sel;
      U.roundRect(ctx, r.x, r.y, r.w, r.h, 14);
      ctx.fillStyle = on ? 'rgba(120,220,255,0.26)' : 'rgba(255,255,255,0.05)'; ctx.fill();
      ctx.lineWidth = on ? 3 : 1.5; ctx.strokeStyle = on ? '#9feaff' : 'rgba(160,220,255,0.3)'; ctx.stroke();
      text(ctx, r.label, r.x + r.w / 2, r.y + r.h / 2 + 1, 22, on ? '#ffffff' : '#bcd6f2');
      if (on) text(ctx, '▶', r.x + 26 + Math.sin(t * 6) * 3, r.y + r.h / 2 + 1, 16, '#9feaff');
    });
  }

  const PAUSE_ITEMS = ['Continuar', 'Reiniciar fase', 'Menu inicial', 'Voltar aos jogos'];
  const DONE_ITEMS = ['Jogar de novo', 'Menu inicial'];

  function pauseRects() { return layout(PAUSE_ITEMS, VW / 2, 270); }
  function doneRects() { return layout(DONE_ITEMS, VW / 2, 528); }

  function pauseMenu() { return menuInput(pauseRects()); }
  function completeMenu() { return menuInput(doneRects()); }

  // ---------------- HUD ----------------
  function drawHUD(ctx, W, touchOn) {
    const t = W.time;
    // cristais
    panel(ctx, 20, 18, 176, 54, 18);
    const bc = 1 + W.bump.crystal * 0.35;
    ctx.save(); ctx.translate(50, 45); ctx.scale(0.85 * bc, 0.85 * bc); ctx.drawImage(Art.getCrystalSprite(), -32, -32); ctx.restore();
    text(ctx, W.stats.crystals + ' / ' + W.totalCrystals, 76, 46, 24, '#e8fbff', 'left');

    // núcleos
    panel(ctx, 206, 18, 160, 54, 18);
    for (let i = 0; i < W.totalCores; i++) {
      const x = 240 + i * 46;
      if (i < W.stats.cores) {
        const b = (i === W.stats.cores - 1) ? W.bump.core * 0.4 : 0;
        Art.drawCore(ctx, x, 45, t, 0.62 * (1 + b));
      } else {
        Art.drawCoreSlot(ctx, x, 45, 0.62);
      }
    }

    // progresso até a estação
    const bx = 470, bw = 340, by = 40;
    U.roundRect(ctx, bx - 14, by - 22, bw + 60, 44, 16);
    ctx.fillStyle = 'rgba(16,10,44,0.6)'; ctx.fill();
    U.roundRect(ctx, bx, by - 4, bw, 8, 4); ctx.fillStyle = 'rgba(255,255,255,0.12)'; ctx.fill();
    const pr = W.progress();
    if (pr > 0) {
      U.roundRect(ctx, bx, by - 4, Math.max(8, bw * pr), 8, 4);
      const g = ctx.createLinearGradient(bx, 0, bx + bw, 0);
      g.addColorStop(0, '#5ff0ff'); g.addColorStop(1, '#ffd27a');
      ctx.fillStyle = g; ctx.fill();
    }
    const a = W.L.spawn.x, b = W.goal.x;
    W.checkpoints.forEach(function (cp) {
      const x = bx + bw * (cp.x - a) / (b - a);
      ctx.fillStyle = cp.active ? '#7ff6ff' : 'rgba(200,200,255,0.45)';
      ctx.fillRect(x - 1.5, by - 9, 3, 18);
    });
    // estação no fim
    ctx.save(); ctx.translate(bx + bw + 22, by + 2);
    ctx.beginPath(); ctx.arc(0, 0, 9, Math.PI, 0); ctx.closePath(); ctx.fillStyle = 'rgba(170,240,255,0.7)'; ctx.fill();
    ctx.lineWidth = 2.5; ctx.strokeStyle = '#d4a764'; ctx.beginPath(); ctx.ellipse(0, -3, 16, 4, -0.1, 0, TAU); ctx.stroke();
    ctx.restore();
    // cabeça do robô como marcador
    const mx = bx + bw * pr;
    ctx.beginPath(); ctx.arc(mx, by, 9, 0, TAU); ctx.fillStyle = '#ffffff'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = Art.OUT; ctx.stroke();
    U.roundRect(ctx, mx - 3, by - 5, 9, 8, 3); ctx.fillStyle = '#121a3d'; ctx.fill();
    ctx.fillStyle = '#7ff6ff'; ctx.fillRect(mx - 1, by - 3, 1.6, 4); ctx.fillRect(mx + 2.5, by - 3, 1.6, 4);

    // tempo e som
    const rx = VW - 24 - (touchOn ? 72 : 0);
    text(ctx, U.fmtTime(W.stats.time), rx, 46, 24, '#e8fbff', 'right');
    if (A.muted) text(ctx, 'SOM DESLIGADO (M)', rx, 76, 13, 'rgba(255,180,200,0.85)', 'right');
  }

  // ---------------- telas ----------------
  function drawTitle(ctx, t, best, touch) {
    const g = ctx.createLinearGradient(0, 0, 0, VH);
    g.addColorStop(0, 'rgba(7,5,26,0.7)'); g.addColorStop(0.55, 'rgba(7,5,26,0.25)'); g.addColorStop(1, 'rgba(7,5,26,0.65)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, VW, VH);

    text(ctx, 'FASE 1', VW / 2, 118, 20, 'rgba(200,235,255,0.8)');
    ctx.save();
    ctx.translate(VW / 2, 200 + Math.sin(t * 1.6) * 4);
    ctx.font = 'bold 96px ' + F; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.lineJoin = 'round';
    ctx.lineWidth = 14; ctx.strokeStyle = '#1b1440'; ctx.strokeText('SPACE EXPLORER', 0, 0);
    const tg = ctx.createLinearGradient(0, -45, 0, 45);
    tg.addColorStop(0, '#ffffff'); tg.addColorStop(0.55, '#bff3ff'); tg.addColorStop(1, '#5fc8ff');
    ctx.fillStyle = tg; ctx.fillText('SPACE EXPLORER', 0, 0);
    ctx.restore();

    ctx.save();
    ctx.font = 'bold 26px ' + F; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    if ('letterSpacing' in ctx) ctx.letterSpacing = '6px';
    ctx.fillStyle = '#e8c98a'; ctx.fillText('SATURNO · ANEL DE GELO', VW / 2, 276);
    ctx.restore();

    // robô de vitrine
    Art.drawRobot(ctx, VW / 2, 440, { facing: 1, sx: 1.6, sy: 1.6 + Math.sin(t * 2.2) * 0.02, t: t, antenna: Math.sin(t * 1.7) * 0.25, blink: (t % 3.2) < 0.12 });

    const pulse = 0.55 + 0.45 * Math.sin(t * 3.2);
    text(ctx, touch ? 'Toque para começar' : 'Pressione ENTER ou toque para começar', VW / 2, 510, 26, 'rgba(255,255,255,' + pulse.toFixed(3) + ')');

    if (!touch) text(ctx, '← → / A D  mover    ·    ESPAÇO / ↑  pular    ·    P  pausar    ·    R  reiniciar    ·    M  som', VW / 2, 585, 17, 'rgba(200,225,255,0.75)', 'center', 'normal');
    text(ctx, 'Colete cristais e os 3 núcleos e chegue à Estação Anel-9', VW / 2, 616, 17, 'rgba(200,225,255,0.75)', 'center', 'normal');
    if (best) text(ctx, 'Melhor tempo: ' + U.fmtTime(best), VW / 2, 664, 18, '#ffd27a');
  }

  function drawPause(ctx, t) {
    ctx.fillStyle = 'rgba(8,5,25,0.62)'; ctx.fillRect(0, 0, VW, VH);
    panel(ctx, VW / 2 - 220, 140, 440, 460, 24);
    text(ctx, 'PAUSADO', VW / 2, 200, 40, '#e8fbff');
    drawMenu(ctx, pauseRects(), t);
    text(ctx, 'M: ' + (A.muted ? 'ligar' : 'desligar') + ' o som', VW / 2, 565, 15, 'rgba(200,225,255,0.65)', 'center', 'normal');
  }

  function star(ctx, x, y, r, on) {
    ctx.beginPath();
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * 0.45 : r;
      ctx.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr);
    }
    ctx.closePath();
    ctx.fillStyle = on ? '#ffd27a' : 'rgba(255,255,255,0.1)'; ctx.fill();
    ctx.lineWidth = 3; ctx.strokeStyle = on ? '#8a5a1a' : 'rgba(255,255,255,0.3)'; ctx.stroke();
  }

  function drawComplete(ctx, W, t, record) {
    const k = U.clamp(openT / 0.4, 0, 1);
    ctx.fillStyle = 'rgba(8,5,25,' + (0.6 * k).toFixed(3) + ')'; ctx.fillRect(0, 0, VW, VH);
    ctx.save();
    const s = U.easeOutBack(k);
    ctx.translate(VW / 2, VH / 2); ctx.scale(s, s); ctx.translate(-VW / 2, -VH / 2);
    panel(ctx, VW / 2 - 300, 70, 600, 600, 26);
    text(ctx, 'MISSÃO CONCLUÍDA!', VW / 2, 126, 42, '#ffd27a');
    text(ctx, 'Você chegou à Estação Anel-9', VW / 2, 168, 19, 'rgba(220,240,255,0.85)', 'center', 'normal');

    const st = W.stats;
    const stars = [true, st.crystals >= Math.ceil(W.totalCrystals * 0.8), st.cores >= W.totalCores];
    stars.forEach(function (on, i) {
      const show = openT > 0.5 + i * 0.25;
      if (show) star(ctx, VW / 2 - 70 + i * 70, 222 - (i === 1 ? 8 : 0), 24, on);
    });

    const c = U.clamp((openT - 0.4) / 1.2, 0, 1);
    const rows = [
      ['Cristais', Math.round(st.crystals * c) + ' / ' + W.totalCrystals],
      ['Núcleos', Math.round(st.cores * c) + ' / ' + W.totalCores],
      ['Tempo', U.fmtTime(st.time * c)],
      ['Quedas', String(Math.round(st.falls * c))],
    ];
    rows.forEach(function (r, i) {
      const y = 290 + i * 46;
      U.roundRect(ctx, VW / 2 - 220, y - 19, 440, 38, 10);
      ctx.fillStyle = 'rgba(255,255,255,0.05)'; ctx.fill();
      text(ctx, r[0], VW / 2 - 200, y, 21, '#bcd6f2', 'left', 'normal');
      text(ctx, r[1], VW / 2 + 200, y, 22, '#ffffff', 'right');
    });
    if (record && c >= 1) text(ctx, 'NOVO RECORDE!', VW / 2, 488, 20, '#7ff6ff');
    drawMenu(ctx, doneRects(), t);
    ctx.restore();
  }

  function drawFade(ctx) {
    if (fade <= 0) return;
    ctx.fillStyle = 'rgba(7,5,26,' + fade.toFixed(3) + ')';
    ctx.fillRect(0, 0, VW, VH);
  }

  return {
    update: update, fadeTo: fadeTo, resetMenu: resetMenu,
    pauseMenu: pauseMenu, completeMenu: completeMenu,
    drawHUD: drawHUD, drawTitle: drawTitle, drawPause: drawPause, drawComplete: drawComplete, drawFade: drawFade,
    get busy() { return fadeDir !== 0; },
  };
})();
