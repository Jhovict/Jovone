// Fundo com parallax: céu e nebulosa, estrelas, Saturno, luas, meteoros,
// mesas distantes com torres, partículas de gelo e silhuetas em primeiro plano.
SE.BG = (function () {
  const U = SE.U;
  const W = SE.CONFIG.VIEW_W, H = SE.CONFIG.VIEW_H;
  const TAU = Math.PI * 2;

  let ready = false;
  let sky, nebula, saturn, farStrip, nearStrip, fgStrip, vignette;
  const stars = [], flakes = [], towers = [], meteors = [];
  let meteorT = 2.5, lastT = 0;

  function mk(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  function mod(a, n) { return ((a % n) + n) % n; }

  function buildSky() {
    sky = mk(W, H);
    const g = sky.getContext('2d');
    const gr = g.createLinearGradient(0, 0, 0, H);
    gr.addColorStop(0, '#090522'); gr.addColorStop(0.45, '#160c42'); gr.addColorStop(0.8, '#2d1764'); gr.addColorStop(1, '#46217c');
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
  }

  function buildNebula() {
    nebula = mk(1600, 900);
    const g = nebula.getContext('2d');
    const r = U.rng(7);
    const cols = ['120,60,210', '60,110,220', '210,80,170', '90,60,200', '70,170,230'];
    g.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 16; i++) {
      const x = r.range(0, 1600), y = r.range(0, 620), rad = r.range(140, 380);
      const c = cols[i % cols.length];
      const gr = g.createRadialGradient(x, y, 0, x, y, rad);
      gr.addColorStop(0, 'rgba(' + c + ',' + r.range(0.07, 0.16).toFixed(3) + ')');
      gr.addColorStop(1, 'rgba(' + c + ',0)');
      g.fillStyle = gr; g.fillRect(x - rad, y - rad, rad * 2, rad * 2);
    }
    // poeira fina
    for (let i = 0; i < 900; i++) {
      g.fillStyle = 'rgba(200,190,255,' + r.range(0.03, 0.12).toFixed(3) + ')';
      g.fillRect(r.range(0, 1600), r.range(0, 700), 1, 1);
    }
  }

  function buildStars() {
    const r = U.rng(11);
    for (let i = 0; i < 240; i++) {
      const big = r() < 0.08;
      stars.push({
        x: r() * W, y: r() * H * 0.9,
        s: big ? r.range(1.6, 2.4) : r.range(0.6, 1.4),
        big: big,
        ph: r() * TAU, sp: r.range(0.7, 3),
        f: r() < 0.5 ? 0.012 : 0.025,
        c: r() < 0.15 ? '#ffe9b0' : (r() < 0.25 ? '#b9e6ff' : '#ffffff'),
      });
    }
    const r2 = U.rng(13);
    for (let i = 0; i < 70; i++) {
      flakes.push({ x: r2() * W, y: r2() * H, s: r2.range(1, 2.6), vx: r2.range(-18, -6), vy: r2.range(8, 26), f: r2.range(0.5, 0.8), ph: r2() * TAU });
    }
  }

  function buildSaturn() {
    const R = 150, CW = 1000, CH = 640, cx = CW / 2, cy = CH / 2, tilt = -0.36, flat = 0.27;
    saturn = mk(CW, CH);
    const g = saturn.getContext('2d');

    // halo
    const halo = g.createRadialGradient(cx, cy, R * 0.9, cx, cy, R * 1.6);
    halo.addColorStop(0, 'rgba(232,201,138,0.18)'); halo.addColorStop(1, 'rgba(232,201,138,0)');
    g.fillStyle = halo; g.fillRect(0, 0, CW, CH);

    const bands = [
      [1.24, 1.50, 'rgba(190,160,120,0.25)'],
      [1.52, 1.72, 'rgba(226,196,135,0.82)'],
      [1.72, 1.95, 'rgba(242,218,165,0.94)'],   // anel B
      [2.03, 2.24, 'rgba(212,167,100,0.80)'],   // anel A (depois da divisão de Cassini)
      [2.26, 2.30, 'rgba(212,167,100,0.42)'],
      [2.38, 2.40, 'rgba(230,210,170,0.45)'],   // anel F
    ];
    function rings(a0, a1) {
      g.save();
      g.translate(cx, cy); g.rotate(tilt); g.scale(1, flat);
      bands.forEach(function (b) {
        g.beginPath(); g.arc(0, 0, b[1] * R, a0, a1); g.arc(0, 0, b[0] * R, a1, a0, true); g.closePath();
        g.fillStyle = b[2]; g.fill();
      });
      const r = U.rng(5);
      for (let rr = 1.26 * R; rr < 2.3 * R; rr += 2.2) {
        const a = r.range(0.03, 0.13).toFixed(3), light = r() < 0.5;
        if (rr > 1.95 * R && rr < 2.03 * R) continue;
        g.beginPath(); g.arc(0, 0, rr, a0, a1);
        g.strokeStyle = light ? 'rgba(255,240,210,' + a + ')' : 'rgba(80,50,30,' + a + ')';
        g.lineWidth = 1.2; g.stroke();
      }
      g.restore();
    }

    rings(Math.PI, TAU);

    // planeta com faixas
    g.save();
    g.beginPath(); g.arc(cx, cy, R, 0, TAU); g.clip();
    g.save();
    g.translate(cx, cy); g.rotate(tilt);
    const cols = ['#f3dfb0', '#e8c98a', '#dcb57a', '#efd6a0', '#c99a5e', '#e3c088', '#d4a764', '#f0d8a8', '#c48f55', '#e8c98a'];
    const r2 = U.rng(9);
    let yy = -R - 10, i = 0;
    while (yy < R + 10) {
      const hh = r2.range(10, 32);
      g.fillStyle = cols[i++ % cols.length];
      g.fillRect(-R - 20, yy, 2 * R + 40, hh + 1);
      yy += hh;
    }
    g.globalAlpha = 0.22;
    for (let k = 0; k < 30; k++) {
      g.fillStyle = r2() < 0.5 ? '#fff1d0' : '#a8743c';
      g.fillRect(-R - 20, r2.range(-R, R), 2 * R + 40, r2.range(1, 3));
    }
    g.globalAlpha = 1;
    g.restore();
    // sombra do anel sobre o planeta
    g.save();
    g.translate(cx, cy + R * 0.12); g.rotate(tilt); g.scale(1, flat);
    g.beginPath(); g.arc(0, 0, 1.68 * R, 0, Math.PI);
    g.lineWidth = 0.32 * R; g.strokeStyle = 'rgba(40,20,40,0.3)'; g.stroke();
    g.restore();
    // iluminação (sol no canto superior esquerdo)
    const sh = g.createRadialGradient(cx - R * 0.45, cy - R * 0.5, R * 0.1, cx - R * 0.15, cy - R * 0.15, R * 1.3);
    sh.addColorStop(0, 'rgba(255,250,235,0.3)');
    sh.addColorStop(0.45, 'rgba(255,240,210,0)');
    sh.addColorStop(0.8, 'rgba(40,20,60,0.4)');
    sh.addColorStop(1, 'rgba(15,5,35,0.88)');
    g.fillStyle = sh; g.fillRect(cx - R, cy - R, 2 * R, 2 * R);
    g.restore();
    g.beginPath(); g.arc(cx, cy, R + 1, 0, TAU);
    g.strokeStyle = 'rgba(255,230,180,0.3)'; g.lineWidth = 2; g.stroke();

    rings(0, Math.PI);
  }

  // Altura periódica (com frequências inteiras, para emendar sem costura)
  function wave(r, width, base, amps) {
    const terms = amps.map(function (a) { return { k: a[0], a: a[1], p: r() * TAU }; });
    return function (x) {
      let v = base;
      for (let i = 0; i < terms.length; i++) v += terms[i].a * Math.sin(terms[i].k * TAU * x / width + terms[i].p);
      return v;
    };
  }

  function buildFar() {
    const FW = 2560, FH = 380;
    farStrip = mk(FW, FH);
    const g = farStrip.getContext('2d');
    const r = U.rng(21);
    const raw = wave(r, FW, 170, [[3, 40], [7, 24], [13, 10], [29, 5]]);
    const h = function (x) { const v = raw(x); return Math.floor(v / 26) * 26 + (v % 26) * 0.3; };
    g.beginPath(); g.moveTo(0, FH);
    for (let x = 0; x <= FW; x += 6) g.lineTo(x, h(x));
    g.lineTo(FW, FH); g.closePath();
    const gr = g.createLinearGradient(0, 80, 0, FH);
    gr.addColorStop(0, '#3e3084'); gr.addColorStop(1, '#1c1546');
    g.fillStyle = gr; g.fill();
    g.beginPath();
    for (let x = 0; x <= FW; x += 6) { const y = h(x); if (x === 0) g.moveTo(x, y); else g.lineTo(x, y); }
    g.strokeStyle = 'rgba(170,220,255,0.35)'; g.lineWidth = 2; g.stroke();
    // torres
    for (let i = 0; i < 7; i++) {
      const tx = 120 + i * (FW / 7) + r.range(-60, 60);
      const base = h(tx) + 2, th = r.range(40, 85);
      g.strokeStyle = '#2a2160'; g.lineWidth = 3;
      g.beginPath(); g.moveTo(tx - 7, base); g.lineTo(tx, base - th); g.lineTo(tx + 7, base); g.stroke();
      g.lineWidth = 1.2;
      g.beginPath();
      for (let k = 1; k < 4; k++) { const yy = base - th * k / 4, ww = 7 * (1 - k / 4); g.moveTo(tx - ww, yy); g.lineTo(tx + ww, yy); }
      g.stroke();
      towers.push({ x: tx, y: base - th - 2, ph: r() * TAU });
    }
  }

  function buildNear() {
    const FW = 2048, FH = 320;
    nearStrip = mk(FW, FH);
    const g = nearStrip.getContext('2d');
    const r = U.rng(31);
    const raw = wave(r, FW, 150, [[2, 50], [5, 30], [11, 14], [23, 6]]);
    const h = function (x) { const v = raw(x); return Math.floor(v / 34) * 34 + (v % 34) * 0.25; };
    g.beginPath(); g.moveTo(0, FH);
    for (let x = 0; x <= FW; x += 6) g.lineTo(x, h(x));
    g.lineTo(FW, FH); g.closePath();
    const gr = g.createLinearGradient(0, 60, 0, FH);
    gr.addColorStop(0, '#2c2168'); gr.addColorStop(1, '#120d30');
    g.fillStyle = gr; g.fill();
    // capas de gelo
    g.save(); g.clip();
    g.beginPath();
    for (let x = 0; x <= FW; x += 6) { const y = h(x); if (x === 0) g.moveTo(x, y); else g.lineTo(x, y); }
    for (let x = FW; x >= 0; x -= 6) g.lineTo(x, h(x) + 6 + 3 * Math.sin(x * 0.07));
    g.closePath();
    g.fillStyle = 'rgba(190,235,255,0.35)'; g.fill();
    g.restore();
    g.beginPath();
    for (let x = 0; x <= FW; x += 6) { const y = h(x); if (x === 0) g.moveTo(x, y); else g.lineTo(x, y); }
    g.strokeStyle = 'rgba(210,245,255,0.55)'; g.lineWidth = 2.5; g.stroke();
  }

  function buildFG() {
    const FW = 3000, FH = 200;
    fgStrip = mk(FW, FH);
    const g = fgStrip.getContext('2d');
    const r = U.rng(41);
    g.fillStyle = '#0a0620';
    g.strokeStyle = 'rgba(130,100,230,0.35)'; g.lineWidth = 2;
    for (let x = r.range(50, 200); x < FW - 100; x += r.range(260, 620)) {
      // monte baixo
      const mw = r.range(120, 260), mh = r.range(30, 60);
      g.beginPath(); g.moveTo(x - mw / 2, FH); g.quadraticCurveTo(x, FH - mh * 2, x + mw / 2, FH); g.closePath(); g.fill();
      // agulhas de gelo
      const n = r.int(1, 3);
      for (let k = 0; k < n; k++) {
        const sx = x + r.range(-mw / 3, mw / 3), sh = r.range(70, 170), sw = r.range(18, 40), lean = r.range(-14, 14);
        g.beginPath(); g.moveTo(sx - sw / 2, FH); g.lineTo(sx + lean, FH - sh); g.lineTo(sx + sw / 2, FH); g.closePath();
        g.fill();
        g.beginPath(); g.moveTo(sx - sw / 2, FH); g.lineTo(sx + lean, FH - sh); g.stroke();
      }
    }
  }

  function buildVignette() {
    vignette = mk(W, H);
    const g = vignette.getContext('2d');
    const gr = g.createRadialGradient(W / 2, H / 2, H * 0.45, W / 2, H / 2, H * 0.95);
    gr.addColorStop(0, 'rgba(5,3,20,0)'); gr.addColorStop(1, 'rgba(5,3,20,0.5)');
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
  }

  function init() {
    if (ready) return;
    buildSky(); buildNebula(); buildStars(); buildSaturn(); buildFar(); buildNear(); buildFG(); buildVignette();
    ready = true;
  }

  function strip(ctx, img, offX, y, fillBelow) {
    let x = -mod(offX, img.width);
    for (; x < W; x += img.width) ctx.drawImage(img, x, y);
    if (fillBelow && y + img.height < H) { ctx.fillStyle = fillBelow; ctx.fillRect(0, y + img.height - 1, W, H - y - img.height + 1); }
  }

  function moon(ctx, x, y, r, c0, c1, haze, crater) {
    if (haze) {
      const gh = ctx.createRadialGradient(x, y, r * 0.8, x, y, r * 1.8);
      gh.addColorStop(0, haze); gh.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = gh; ctx.fillRect(x - r * 2, y - r * 2, r * 4, r * 4);
    }
    const g = ctx.createRadialGradient(x - r * 0.4, y - r * 0.4, r * 0.1, x, y, r);
    g.addColorStop(0, c0); g.addColorStop(1, c1);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
    if (crater) {
      ctx.fillStyle = 'rgba(40,30,60,0.35)';
      ctx.beginPath(); ctx.arc(x + r * 0.3, y - r * 0.1, r * 0.38, 0, TAU); ctx.fill();
      ctx.fillStyle = 'rgba(40,30,60,0.25)';
      ctx.beginPath(); ctx.arc(x - r * 0.35, y + r * 0.4, r * 0.15, 0, TAU); ctx.fill();
    }
  }

  function drawBack(ctx, cam, t) {
    init();
    const dt = Math.min(0.1, Math.max(0, t - lastT)); lastT = t;

    ctx.drawImage(sky, 0, 0);
    ctx.drawImage(nebula, -120 - cam.x * 0.008, -80 - cam.y * 0.01);

    // estrelas piscando
    for (let i = 0; i < stars.length; i++) {
      const s = stars[i];
      const sx = mod(s.x - cam.x * s.f, W), sy = s.y - cam.y * s.f;
      const a = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * s.sp + s.ph));
      ctx.globalAlpha = a;
      ctx.fillStyle = s.c;
      if (s.big) {
        ctx.fillRect(sx - s.s * 2, sy - 0.5, s.s * 4, 1);
        ctx.fillRect(sx - 0.5, sy - s.s * 2, 1, s.s * 4);
        ctx.beginPath(); ctx.arc(sx, sy, s.s * 0.7, 0, TAU); ctx.fill();
      } else {
        ctx.fillRect(sx, sy, s.s, s.s);
      }
    }
    ctx.globalAlpha = 1;

    // meteoros
    meteorT -= dt;
    if (meteorT <= 0) {
      meteorT = 3 + Math.random() * 5;
      meteors.push({ x: 200 + Math.random() * (W - 100), y: -20 + Math.random() * 120, vx: -(420 + Math.random() * 300), vy: 160 + Math.random() * 140, life: 1.1 });
    }
    for (let i = meteors.length - 1; i >= 0; i--) {
      const m = meteors[i];
      m.life -= dt; m.x += m.vx * dt; m.y += m.vy * dt;
      if (m.life <= 0) { meteors.splice(i, 1); continue; }
      const a = Math.min(1, m.life * 2);
      const gr = ctx.createLinearGradient(m.x, m.y, m.x - m.vx * 0.18, m.y - m.vy * 0.18);
      gr.addColorStop(0, 'rgba(255,255,255,' + a + ')'); gr.addColorStop(1, 'rgba(160,220,255,0)');
      ctx.strokeStyle = gr; ctx.lineWidth = 2; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(m.x, m.y); ctx.lineTo(m.x - m.vx * 0.18, m.y - m.vy * 0.18); ctx.stroke();
    }

    // luas e Saturno
    const wrap = W + 240;
    moon(ctx, mod(1210 - cam.x * 0.04 + 120, wrap) - 120, 96 - cam.y * 0.04, 11, '#e8e6f0', '#6c6884', null, true);
    const ss = 0.8;
    ctx.globalAlpha = 0.92;
    ctx.drawImage(saturn, 900 - saturn.width * ss / 2 - cam.x * 0.025, 165 - saturn.height * ss / 2 - cam.y * 0.04, saturn.width * ss, saturn.height * ss);
    ctx.globalAlpha = 1;
    moon(ctx, mod(230 - cam.x * 0.05 + 120, wrap) - 120, 130 - cam.y * 0.05, 23, '#f6c57a', '#8f5326', 'rgba(255,190,110,0.28)', false);
    moon(ctx, mod(560 - cam.x * 0.045 + 120, wrap) - 120, 70 - cam.y * 0.045, 8, '#ffffff', '#9fc4e6', 'rgba(220,245,255,0.3)', false);

    // mesas distantes
    const farY = 330 - cam.y * 0.12;
    strip(ctx, farStrip, cam.x * 0.12, farY, '#1c1546');
    for (let i = 0; i < towers.length; i++) {
      const tw = towers[i];
      const sx = tw.x - mod(cam.x * 0.12, farStrip.width);
      for (let k = -1; k <= 1; k++) {
        const xx = sx + k * farStrip.width;
        if (xx < -10 || xx > W + 10) continue;
        const on = Math.sin(t * 2.5 + tw.ph) > 0.2;
        ctx.fillStyle = on ? 'rgba(255,90,120,0.95)' : 'rgba(120,40,70,0.6)';
        ctx.beginPath(); ctx.arc(xx, farY + tw.y, on ? 2.5 : 1.8, 0, TAU); ctx.fill();
      }
    }
    strip(ctx, nearStrip, cam.x * 0.28, 420 - cam.y * 0.28, '#120d30');

    // partículas de gelo
    ctx.fillStyle = 'rgba(220,245,255,0.55)';
    for (let i = 0; i < flakes.length; i++) {
      const f = flakes[i];
      const sx = mod(f.x + t * f.vx - cam.x * f.f + Math.sin(t + f.ph) * 8, W);
      const sy = mod(f.y + t * f.vy - cam.y * f.f, H);
      ctx.fillRect(sx, sy, f.s, f.s);
    }
  }

  function drawFront(ctx, cam) {
    init();
    strip(ctx, fgStrip, cam.x * 1.3, H - 140 - cam.y * 1.0, null);
    ctx.drawImage(vignette, 0, 0);
  }

  return { init: init, drawBack: drawBack, drawFront: drawFront };
})();
