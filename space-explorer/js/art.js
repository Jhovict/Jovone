// Desenho procedural (estilo cartoon) do robô, do terreno e dos objetos da fase.
SE.Art = (function () {
  const U = SE.U;
  const TAU = Math.PI * 2;
  const OUT = '#1b1440'; // cor do contorno

  function mk(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }

  function circle(ctx, x, y, r) { ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, TAU); }

  function limb(ctx, x1, y1, x2, y2, w, color) {
    ctx.lineCap = 'round';
    ctx.strokeStyle = OUT; ctx.lineWidth = w + 4;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    ctx.strokeStyle = color; ctx.lineWidth = w;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  }

  // ======================= ROBÔ =======================
  // (x, y) = ponto entre os pés. o: facing, sx, sy, run, moving, air, vy, blink, antenna, thrust, alpha, t
  function drawRobot(ctx, x, y, o) {
    const f = o.facing || 1;
    const t = o.t || 0;
    ctx.save();
    ctx.translate(x, y);
    if (o.alpha !== undefined) ctx.globalAlpha = o.alpha;
    ctx.scale(o.sx || 1, o.sy || 1);
    ctx.scale(f, 1);
    ctx.lineJoin = 'round';

    const run = o.run || 0;
    const walking = o.moving && !o.air;
    const sw = walking ? Math.sin(run) : 0;
    const bob = walking ? -Math.abs(Math.cos(run)) * 2.5 : Math.sin(t * 2.2) * 0.6;

    // posição dos pés
    let bx, by, fx, fy;
    if (o.air) {
      const up = o.vy < 0;
      bx = -8; by = up ? -4 : -1;
      fx = 8; fy = up ? -7 : -2;
    } else if (walking) {
      bx = -4 - sw * 7; by = -Math.max(0, Math.cos(run)) * 4;
      fx = 4 + sw * 7; fy = -Math.max(0, -Math.cos(run)) * 4;
    } else {
      bx = -6; by = 0; fx = 6; fy = 0;
    }

    // pernas
    limb(ctx, -5, -15 + bob, bx, by - 3, 6, '#aeb5d2');
    foot(ctx, bx, by, '#2f2a55');
    limb(ctx, 5, -15 + bob, fx, fy - 3, 6, '#dde2f2');
    foot(ctx, fx, fy, '#3d3766');

    ctx.translate(0, bob);

    // braço de trás
    let hbx, hby, hfx, hfy;
    if (o.air) { hbx = -11; hby = -42; hfx = 14; hfy = -42; }
    else if (walking) { hbx = -6 - sw * 6; hby = -20; hfx = 6 + sw * 6; hfy = -20; }
    else { hbx = -8; hby = -20 + Math.sin(t * 2.2) * 0.5; hfx = 8; hfy = -20 + Math.sin(t * 2.2) * 0.5; }
    limb(ctx, -6, -31, hbx, hby, 5, '#c3c9e0');
    circle(ctx, hbx, hby, 3.6); ctx.fillStyle = '#8e88b8'; ctx.fill(); ctx.lineWidth = 1.5; ctx.strokeStyle = OUT; ctx.stroke();

    // jetpack
    if (o.thrust) {
      const L = 10 + Math.random() * 10;
      const gfl = ctx.createLinearGradient(0, -12, 0, -12 + L);
      gfl.addColorStop(0, '#fff6c2'); gfl.addColorStop(0.5, '#ffb347'); gfl.addColorStop(1, 'rgba(255,90,40,0)');
      ctx.fillStyle = gfl;
      ctx.beginPath(); ctx.moveTo(-20, -12); ctx.lineTo(-11, -12); ctx.lineTo(-15.5, -12 + L); ctx.closePath(); ctx.fill();
    }
    U.roundRect(ctx, -22, -38, 12, 22, 4);
    const gj = ctx.createLinearGradient(-22, 0, -10, 0);
    gj.addColorStop(0, '#d9622a'); gj.addColorStop(1, '#ff9a52');
    ctx.fillStyle = gj; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.fillRect(-19, -34, 2, 9);
    U.roundRect(ctx, -20, -17, 8, 5, 1.5); ctx.fillStyle = '#5b5680'; ctx.fill(); ctx.lineWidth = 1.5; ctx.stroke();

    // corpo
    U.roundRect(ctx, -12, -39, 24, 25, 8);
    const gb = ctx.createLinearGradient(-12, -39, 12, -14);
    gb.addColorStop(0, '#ffffff'); gb.addColorStop(1, '#cdd4ea');
    ctx.fillStyle = gb; ctx.fill();
    ctx.save(); ctx.clip();
    ctx.fillStyle = '#ff8a3d'; ctx.fillRect(-13, -24, 26, 5);
    ctx.fillStyle = '#c9551f'; ctx.fillRect(-13, -19, 26, 1.5);
    ctx.restore();
    U.roundRect(ctx, -12, -39, 24, 25, 8); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    circle(ctx, 5, -31, 5); ctx.fillStyle = 'rgba(95,240,255,0.25)'; ctx.fill();
    circle(ctx, 5, -31, 2.6); ctx.fillStyle = '#5ff0ff'; ctx.fill();

    // cabeça (cúpula)
    circle(ctx, 1, -50, 13);
    const gh = ctx.createRadialGradient(-4, -57, 2, 1, -50, 14);
    gh.addColorStop(0, '#ffffff'); gh.addColorStop(1, '#cbd2ea');
    ctx.fillStyle = gh; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    // parafuso lateral
    circle(ctx, -10, -50, 3.2); ctx.fillStyle = '#ff8a3d'; ctx.fill(); ctx.lineWidth = 1.5; ctx.stroke();
    // visor
    U.roundRect(ctx, -3, -57, 16, 13, 5.5); ctx.fillStyle = '#121a3d'; ctx.fill(); ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.28)';
    ctx.beginPath(); ctx.ellipse(1, -54.5, 3.5, 1.4, -0.3, 0, TAU); ctx.fill();
    // olhos
    const eh = o.blink ? 1.2 : 6;
    for (let i = 0; i < 2; i++) {
      const ex = 3.5 + i * 6;
      ctx.fillStyle = 'rgba(110,240,255,0.25)';
      U.roundRect(ctx, ex - 3, -50.5 - eh / 2 - 1.5, 6, eh + 3, 3); ctx.fill();
      ctx.fillStyle = '#7ff6ff';
      U.roundRect(ctx, ex - 1.8, -50.5 - eh / 2, 3.6, eh, 1.8); ctx.fill();
    }

    // antena com mola
    ctx.save();
    ctx.translate(-1, -62);
    ctx.rotate((o.antenna || 0) * f);
    ctx.beginPath(); ctx.moveTo(0, 1);
    for (let i = 1; i <= 5; i++) ctx.lineTo(i % 2 ? 2.6 : -2.6, -i * 2.1);
    ctx.lineTo(0, -12);
    ctx.lineCap = 'round';
    ctx.strokeStyle = OUT; ctx.lineWidth = 3.4; ctx.stroke();
    ctx.strokeStyle = '#c3c9e0'; ctx.lineWidth = 1.6; ctx.stroke();
    circle(ctx, 0, -14, 7.5); ctx.fillStyle = 'rgba(255,160,80,' + (0.22 + 0.12 * Math.sin(t * 5)) + ')'; ctx.fill();
    circle(ctx, 0, -14, 3.8); ctx.fillStyle = '#ff8a3d'; ctx.fill(); ctx.lineWidth = 1.5; ctx.strokeStyle = OUT; ctx.stroke();
    circle(ctx, -1, -15, 1.2); ctx.fillStyle = '#ffe0c2'; ctx.fill();
    ctx.restore();

    // braço da frente
    limb(ctx, 6, -31, hfx, hfy, 5, '#f2f4fb');
    circle(ctx, hfx, hfy, 3.6); ctx.fillStyle = '#a49ecb'; ctx.fill(); ctx.lineWidth = 1.5; ctx.strokeStyle = OUT; ctx.stroke();

    ctx.restore();
  }

  function foot(ctx, x, y, color) {
    U.roundRect(ctx, x - 5, y - 6, 13, 6, 3);
    ctx.fillStyle = color; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.stroke();
  }

  function drawShadow(ctx, x, gy, dist) {
    const k = U.clamp(1 - dist / 280, 0, 1);
    if (k <= 0) return;
    ctx.fillStyle = 'rgba(8,4,25,' + (0.38 * k).toFixed(3) + ')';
    ctx.beginPath(); ctx.ellipse(x, gy, 18 * (0.45 + 0.55 * k), 4.5 * (0.45 + 0.55 * k), 0, 0, TAU); ctx.fill();
  }

  // ======================= TERRENO =======================
  function prep(s) {
    if (s._p) return s._p;
    const r = U.rng(((s.x * 73856093) ^ (s.y * 19349663) ^ (s.w * 83492791)) >>> 0);
    const p = { spots: [], bumps: [], crust: [], drips: [], strata: [] };
    const visH = Math.min(s.h, 760);
    const n = Math.max(2, Math.floor(s.w * visH / 6500));
    for (let i = 0; i < n; i++) p.spots.push({ x: r.range(10, s.w - 10), y: r.range(36, visH), rx: r.range(4, 15) });
    for (let x = 0; x <= s.w + 16; x += 16) p.crust.push(r.range(9, 17));
    for (let x = r.range(12, 30); x < s.w - 12; x += r.range(26, 64)) p.drips.push({ x: x, len: r.range(5, 13), w: r.range(4, 7) });
    const rad = s.kind === 'boulder' ? 18 : 10;
    for (let x = rad + r.range(4, 30); x < s.w - rad - 10; x += r.range(45, 120)) p.bumps.push({ x: x, r: r.range(4, 8) });
    for (let y = r.range(60, 110); y < visH; y += r.range(45, 100)) p.strata.push({ y: y, a: r.range(0.05, 0.13), h: r.range(2, 5) });
    s._p = p;
    return p;
  }

  function rockPath(ctx, x, y, w, bot, rad) {
    ctx.beginPath();
    ctx.moveTo(x, bot); ctx.lineTo(x, y + rad); ctx.quadraticCurveTo(x, y, x + rad, y);
    ctx.lineTo(x + w - rad, y); ctx.quadraticCurveTo(x + w, y, x + w, y + rad); ctx.lineTo(x + w, bot);
    ctx.closePath();
  }

  function drawRock(ctx, s, viewBottom) {
    const p = prep(s);
    const x = s.x, y = s.y, w = s.w;
    const bot = Math.min(s.y + s.h, viewBottom + 30);
    if (bot <= y) return;
    const rad = s.kind === 'boulder' ? 18 : 10;
    if (!s._g) {
      s._g = ctx.createLinearGradient(0, y, 0, y + 460);
      if (s.mesa) {
        s._g.addColorStop(0, '#62539c'); s._g.addColorStop(0.3, '#43367c'); s._g.addColorStop(1, '#1a1336');
      } else {
        s._g.addColorStop(0, '#5a4d92'); s._g.addColorStop(0.35, '#3d3173'); s._g.addColorStop(1, '#1a1336');
      }
      s._ig = ctx.createLinearGradient(0, y - 4, 0, y + 18);
      s._ig.addColorStop(0, '#f2fdff'); s._ig.addColorStop(0.45, '#c4efff'); s._ig.addColorStop(1, '#8fd3f0');
    }
    rockPath(ctx, x, y, w, bot, rad);
    ctx.fillStyle = s._g; ctx.fill();
    ctx.save(); ctx.clip();

    // estratos
    for (let i = 0; i < p.strata.length; i++) {
      const st = p.strata[i];
      if (y + st.y > bot) break;
      ctx.fillStyle = 'rgba(10,5,35,' + st.a + ')';
      ctx.fillRect(x, y + st.y, w, st.h);
    }
    // crateras
    for (let i = 0; i < p.spots.length; i++) {
      const sp = p.spots[i];
      if (y + sp.y > bot + 20) continue;
      ctx.fillStyle = 'rgba(170,150,240,0.16)';
      ctx.beginPath(); ctx.ellipse(x + sp.x, y + sp.y + 1.5, sp.rx, sp.rx * 0.62, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = 'rgba(18,10,50,0.5)';
      ctx.beginPath(); ctx.ellipse(x + sp.x, y + sp.y, sp.rx * 0.9, sp.rx * 0.5, 0, 0, TAU); ctx.fill();
    }
    // luz e sombra laterais
    ctx.fillStyle = 'rgba(8,4,30,0.3)'; ctx.fillRect(x + w - 9, y, 9, bot - y);
    ctx.fillStyle = 'rgba(190,170,255,0.12)'; ctx.fillRect(x, y, 5, bot - y);

    // crosta de gelo
    ctx.beginPath();
    ctx.moveTo(x - 2, y - 4); ctx.lineTo(x + w + 2, y - 4);
    for (let i = p.crust.length - 1; i >= 0; i--) ctx.lineTo(Math.min(x + i * 16, x + w + 2), y + p.crust[i]);
    ctx.closePath();
    ctx.fillStyle = s._ig; ctx.fill();
    ctx.fillStyle = '#a7e0f6';
    for (let i = 0; i < p.drips.length; i++) {
      const d = p.drips[i];
      const cy = y + p.crust[Math.min(p.crust.length - 1, Math.round(d.x / 16))] - 1;
      ctx.beginPath(); ctx.moveTo(x + d.x - d.w / 2, cy); ctx.lineTo(x + d.x + d.w / 2, cy); ctx.lineTo(x + d.x, cy + d.len); ctx.closePath(); ctx.fill();
    }
    ctx.restore();

    rockPath(ctx, x, y, w, bot, rad);
    ctx.lineWidth = 3; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(x + rad, y + 2.5); ctx.lineTo(x + w - rad, y + 2.5); ctx.stroke();

    // montinhos de neve
    for (let i = 0; i < p.bumps.length; i++) {
      const b = p.bumps[i];
      ctx.beginPath(); ctx.arc(x + b.x, y + 2, b.r, Math.PI, 0); ctx.closePath();
      ctx.fillStyle = '#ecfbff'; ctx.fill();
      ctx.beginPath(); ctx.arc(x + b.x, y + 2, b.r, Math.PI, 0);
      ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.stroke();
    }
  }

  function drawMetal(ctx, s, t) {
    const x = s.x, y = s.y, w = s.w, h = s.h;
    // luz por baixo
    const gl = ctx.createRadialGradient(x + w / 2, y + h + 4, 2, x + w / 2, y + h + 4, w * 0.5);
    gl.addColorStop(0, 'rgba(120,230,255,0.28)'); gl.addColorStop(1, 'rgba(120,230,255,0)');
    ctx.fillStyle = gl; ctx.fillRect(x - 10, y + h - 6, w + 20, 40);

    U.roundRect(ctx, x, y, w, h, 6);
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, '#b4bcdf'); g.addColorStop(1, '#585e8c');
    ctx.fillStyle = g; ctx.fill();
    ctx.save(); ctx.clip();
    ctx.fillStyle = '#e8edff'; ctx.fillRect(x, y, w, 5);
    // listras de aviso
    ctx.beginPath(); ctx.rect(x + 12, y + h - 10, w - 24, 5); ctx.clip();
    ctx.fillStyle = '#2b2550'; ctx.fillRect(x, y + h - 10, w, 5);
    ctx.fillStyle = '#ff8a3d';
    for (let sx = x + 4; sx < x + w; sx += 12) {
      ctx.beginPath(); ctx.moveTo(sx, y + h - 5); ctx.lineTo(sx + 6, y + h - 10); ctx.lineTo(sx + 11, y + h - 10); ctx.lineTo(sx + 5, y + h - 5); ctx.closePath(); ctx.fill();
    }
    ctx.restore();
    U.roundRect(ctx, x, y, w, h, 6); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.fillStyle = '#3c3868';
    circle(ctx, x + 7, y + 12, 2); ctx.fill();
    circle(ctx, x + w - 7, y + 12, 2); ctx.fill();
    // luzinha
    circle(ctx, x + w / 2, y + 12, 2.5);
    ctx.fillStyle = Math.sin(t * 3 + x) > 0 ? '#7ff6ff' : '#3d7c9a'; ctx.fill();
  }

  function drawLedge(ctx, s) {
    const x = s.x, y = s.y, w = s.w, h = s.h;
    // pingentes
    ctx.fillStyle = 'rgba(170,230,255,0.75)';
    for (let i = 8, k = 0; i < w - 6; i += 17, k++) {
      const len = 6 + ((k * 7) % 5) * 2;
      ctx.beginPath(); ctx.moveTo(x + i - 3, y + h - 1); ctx.lineTo(x + i + 3, y + h - 1); ctx.lineTo(x + i, y + h + len); ctx.closePath(); ctx.fill();
    }
    U.roundRect(ctx, x, y, w, h, 5);
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, 'rgba(220,248,255,0.9)'); g.addColorStop(1, 'rgba(110,190,240,0.6)');
    ctx.fillStyle = g; ctx.fill();
    ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(30,60,130,0.95)'; ctx.stroke();
    ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(x + 5, y + 3); ctx.lineTo(x + w - 5, y + 3); ctx.stroke();
    // tracejado indica que dá para atravessar por baixo
    ctx.strokeStyle = 'rgba(40,90,160,0.5)'; ctx.setLineDash([5, 6]); ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x + 6, y + h - 4); ctx.lineTo(x + w - 6, y + h - 4); ctx.stroke();
    ctx.setLineDash([]);
  }

  function drawMover(ctx, m, t) {
    const x = m.x, y = m.y, w = m.w, h = m.h;
    // propulsores
    for (let i = 0; i < 2; i++) {
      const nx = x + w * (i ? 0.75 : 0.25);
      const L = 12 + Math.sin(t * 40 + i * 2) * 4 + Math.random() * 3;
      const gf = ctx.createLinearGradient(0, y + h + 6, 0, y + h + 6 + L);
      gf.addColorStop(0, '#fff3b0'); gf.addColorStop(0.5, '#ff9a47'); gf.addColorStop(1, 'rgba(255,80,40,0)');
      ctx.fillStyle = gf;
      ctx.beginPath(); ctx.moveTo(nx - 6, y + h + 6); ctx.lineTo(nx + 6, y + h + 6); ctx.lineTo(nx, y + h + 6 + L); ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.moveTo(nx - 9, y + h - 2); ctx.lineTo(nx + 9, y + h - 2); ctx.lineTo(nx + 6, y + h + 7); ctx.lineTo(nx - 6, y + h + 7); ctx.closePath();
      ctx.fillStyle = '#4d4878'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.stroke();
    }
    U.roundRect(ctx, x, y, w, h, 7);
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, '#9aa2cc'); g.addColorStop(1, '#4a4f7c');
    ctx.fillStyle = g; ctx.fill();
    ctx.save(); ctx.clip();
    ctx.fillStyle = '#e2e8ff'; ctx.fillRect(x, y, w, 5);
    ctx.fillStyle = '#ff8a3d'; ctx.fillRect(x, y + h - 7, w, 3);
    ctx.restore();
    U.roundRect(ctx, x, y, w, h, 7); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    const on = Math.sin(t * 6) > 0;
    ctx.fillStyle = on ? '#ffd27a' : '#8a5a3a';
    circle(ctx, x + 9, y + 12, 3); ctx.fill();
    ctx.fillStyle = on ? '#8a5a3a' : '#ffd27a';
    circle(ctx, x + w - 9, y + 12, 3); ctx.fill();
  }

  function drawCrumble(ctx, c, t) {
    if (c.alpha <= 0.01) return;
    let ox = 0, oy = 0;
    if (c.state === 'shake') { ox = (Math.random() - 0.5) * 4; oy = (Math.random() - 0.5) * 2; }
    const x = c.x + ox, y = c.y + oy, w = c.w, h = c.h;
    ctx.save();
    ctx.globalAlpha = c.alpha;
    U.roundRect(ctx, x, y, w, h, 8);
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, '#effcff'); g.addColorStop(0.5, '#9fdcf5'); g.addColorStop(1, '#5aa6d6');
    ctx.fillStyle = g; ctx.fill();
    ctx.lineWidth = 2.5; ctx.strokeStyle = '#26407e'; ctx.stroke();
    // rachaduras (mais visíveis quando prestes a cair)
    const crack = c.state === 'idle' ? 0.35 : 1;
    ctx.strokeStyle = 'rgba(30,70,140,' + (0.35 + 0.5 * crack) + ')'; ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(x + w * 0.3, y + 2); ctx.lineTo(x + w * 0.36, y + h * 0.45); ctx.lineTo(x + w * 0.28, y + h - 3);
    ctx.moveTo(x + w * 0.36, y + h * 0.45); ctx.lineTo(x + w * 0.5, y + h * 0.6);
    ctx.moveTo(x + w * 0.7, y + 3); ctx.lineTo(x + w * 0.64, y + h * 0.5); ctx.lineTo(x + w * 0.74, y + h - 4);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(x + 7, y + 4); ctx.lineTo(x + w - 7, y + 4); ctx.stroke();
    ctx.restore();
  }

  function drawPad(ctx, p, t) {
    const x = p.x, y = p.y, w = p.w, h = p.h, cx = x + w / 2;
    // coluna de vapor quando ativado
    if (p.fx > 0) {
      const a = p.fx;
      const gc = ctx.createLinearGradient(0, y - 260, 0, y);
      gc.addColorStop(0, 'rgba(200,245,255,0)'); gc.addColorStop(1, 'rgba(220,250,255,' + (0.6 * a) + ')');
      ctx.fillStyle = gc;
      const cw = 18 + 26 * a;
      ctx.beginPath(); ctx.moveTo(cx - cw / 2, y); ctx.lineTo(cx - cw, y - 260); ctx.lineTo(cx + cw, y - 260); ctx.lineTo(cx + cw / 2, y); ctx.closePath(); ctx.fill();
    }
    // vapor ocioso
    for (let i = 0; i < 4; i++) {
      const ph = (t * 0.7 + i / 4) % 1;
      ctx.fillStyle = 'rgba(225,248,255,' + ((1 - ph) * 0.32).toFixed(3) + ')';
      circle(ctx, cx + Math.sin(ph * 6 + i * 1.7) * 7, y - ph * 60, 5 + ph * 11); ctx.fill();
    }
    // base
    ctx.beginPath(); ctx.moveTo(x - 4, y + h); ctx.lineTo(x + 10, y + 1); ctx.lineTo(x + w - 10, y + 1); ctx.lineTo(x + w + 4, y + h); ctx.closePath();
    const g = ctx.createLinearGradient(0, y, 0, y + h);
    g.addColorStop(0, '#6a5bb0'); g.addColorStop(1, '#3a2f6e');
    ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.beginPath(); ctx.ellipse(cx, y + 3, 19, 5, 0, 0, TAU);
    ctx.fillStyle = '#120c2a'; ctx.fill();
    ctx.lineWidth = 2.5; ctx.strokeStyle = 'rgba(255,170,90,' + (0.6 + 0.4 * Math.sin(t * 4)) + ')'; ctx.stroke();
    ctx.fillStyle = '#ff8a3d';
    ctx.fillRect(x + 12, y + h - 6, 6, 3); ctx.fillRect(x + w - 18, y + h - 6, 6, 3);
  }

  function drawSpikes(ctx, s) {
    const n = Math.max(1, Math.round(s.w / 22));
    const sw = s.w / n;
    const base = s.y + s.h;
    if (!s._g) {
      s._g = ctx.createLinearGradient(0, s.y, 0, base);
      s._g.addColorStop(0, '#ffc2dc'); s._g.addColorStop(0.35, '#ff4d8d'); s._g.addColorStop(1, '#8e1550');
    }
    for (let i = 0; i < n; i++) {
      const x0 = s.x + i * sw, tip = s.y + 2 + (i % 2) * 7;
      ctx.beginPath(); ctx.moveTo(x0 + 1, base); ctx.lineTo(x0 + sw / 2, tip); ctx.lineTo(x0 + sw - 1, base); ctx.closePath();
      ctx.fillStyle = s._g; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#3d0a26'; ctx.stroke();
      ctx.strokeStyle = 'rgba(255,230,240,0.85)'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(x0 + sw / 2 - 1, tip + 4); ctx.lineTo(x0 + sw * 0.28, base - 4); ctx.stroke();
    }
    ctx.fillStyle = 'rgba(255,77,141,0.12)';
    ctx.fillRect(s.x, base - 4, s.w, 4);
  }

  function drawLaserBase(ctx, l) {
    const x = l.x, top = l.top, bot = l.bottom;
    const g = ctx.createLinearGradient(x + 14, 0, x + 24, 0);
    g.addColorStop(0, '#9aa2cc'); g.addColorStop(1, '#4a4f7c');
    ctx.fillStyle = g; ctx.fillRect(x + 15, top - 14, 9, bot - top + 14);
    ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.strokeRect(x + 15, top - 14, 9, bot - top + 14);
    for (let yy = top + 20; yy < bot - 10; yy += 34) { ctx.fillStyle = '#3a3668'; ctx.fillRect(x + 17, yy, 5, 3); }
    // emissor de cima
    U.roundRect(ctx, x - 15, top - 24, 42, 20, 6);
    ctx.fillStyle = '#5d6390'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    U.roundRect(ctx, x - 7, top - 6, 14, 8, 2); ctx.fillStyle = '#2b2550'; ctx.fill(); ctx.stroke();
    ctx.fillStyle = l.on ? '#ff4d8d' : (l.warn ? '#ffb0cc' : '#6b3a5a');
    circle(ctx, x + 18, top - 14, 3); ctx.fill();
    // receptor de baixo
    U.roundRect(ctx, x - 13, bot - 12, 30, 12, 4);
    ctx.fillStyle = '#5d6390'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
  }

  function drawLaserBeam(ctx, l, t) {
    const x = l.x, top = l.top, bot = l.bottom;
    if (l.on) {
      const wob = 1 + Math.sin(t * 55) * 0.15;
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = 'rgba(255,77,141,0.22)'; ctx.fillRect(x - 10 * wob, top, 20 * wob, bot - top - 10);
      ctx.fillStyle = 'rgba(255,77,141,0.75)'; ctx.fillRect(x - 4 * wob, top, 8 * wob, bot - top - 10);
      ctx.fillStyle = '#fff0f6'; ctx.fillRect(x - 1.5, top, 3, bot - top - 10);
      const gg = ctx.createRadialGradient(x, top, 0, x, top, 26);
      gg.addColorStop(0, 'rgba(255,140,190,0.8)'); gg.addColorStop(1, 'rgba(255,77,141,0)');
      ctx.fillStyle = gg; ctx.fillRect(x - 26, top - 26, 52, 52);
      ctx.globalCompositeOperation = 'source-over';
    } else if (l.warn) {
      ctx.fillStyle = 'rgba(255,140,190,' + (Math.sin(t * 60) > 0 ? 0.7 : 0.2) + ')';
      ctx.fillRect(x - 1, top, 2, bot - top - 10);
    } else {
      ctx.strokeStyle = 'rgba(255,120,180,0.18)'; ctx.lineWidth = 1.5; ctx.setLineDash([4, 8]);
      ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, bot - 10); ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  // ======================= INIMIGOS E ITENS =======================
  function drawMite(ctx, m, t) {
    const x = m.x, y = m.y, d = m.dir;
    if (!m.alive) {
      if (m.deadT > 0.8) return;
      ctx.save(); ctx.globalAlpha = 1 - m.deadT / 0.8;
      ctx.beginPath(); ctx.ellipse(x, y - 4, 22, 5, 0, 0, TAU);
      ctx.fillStyle = '#4b3888'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
      ctx.fillStyle = '#ffffff'; ctx.font = 'bold 10px ' + U.FONT; ctx.textAlign = 'center'; ctx.fillText('x x', x, y - 1);
      ctx.restore();
      return;
    }
    // pernas
    ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const lx = x + (i - 1) * 10;
      const ph = t * 16 + i * 2.1;
      ctx.strokeStyle = OUT; ctx.lineWidth = 3.5;
      ctx.beginPath(); ctx.moveTo(lx, y - 10); ctx.lineTo(lx + Math.sin(ph) * 5 - 2, y - 4 - Math.max(0, Math.cos(ph)) * 3); ctx.lineTo(lx + Math.sin(ph) * 6, y); ctx.stroke();
    }
    const by = y - 15 + Math.abs(Math.sin(t * 16)) * 1.5;
    ctx.beginPath(); ctx.ellipse(x, by, 20, 13, 0, 0, TAU);
    const g = ctx.createLinearGradient(0, by - 13, 0, by + 13);
    g.addColorStop(0, '#7d62c8'); g.addColorStop(1, '#3b2a6b');
    ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.fillStyle = '#ff4d8d';
    circle(ctx, x - d * 9, by - 6, 3); ctx.fill();
    circle(ctx, x - d * 2, by - 9, 2.2); ctx.fill();
    circle(ctx, x - d * 13, by + 1, 2); ctx.fill();
    // antenas
    ctx.strokeStyle = OUT; ctx.lineWidth = 2;
    for (let i = 0; i < 2; i++) {
      const ax = x + d * (4 + i * 6), sway = Math.sin(t * 8 + i) * 3;
      ctx.beginPath(); ctx.moveTo(ax, by - 11); ctx.quadraticCurveTo(ax + d * 3, by - 20, ax + d * 6 + sway, by - 24); ctx.stroke();
      circle(ctx, ax + d * 6 + sway, by - 24, 2.6); ctx.fillStyle = '#ff4d8d'; ctx.fill();
    }
    // olho
    circle(ctx, x + d * 8, by - 2, 6.5); ctx.fillStyle = '#ffffff'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.stroke();
    circle(ctx, x + d * 10, by - 2, 3); ctx.fillStyle = '#c21d63'; ctx.fill();
  }

  let crystalSprite = null;
  function getCrystalSprite() {
    if (crystalSprite) return crystalSprite;
    const c = mk(64, 64), g = c.getContext('2d');
    const glow = g.createRadialGradient(32, 32, 2, 32, 32, 30);
    glow.addColorStop(0, 'rgba(150,240,255,0.6)'); glow.addColorStop(0.5, 'rgba(90,200,255,0.16)'); glow.addColorStop(1, 'rgba(90,200,255,0)');
    g.fillStyle = glow; g.fillRect(0, 0, 64, 64);
    g.translate(32, 32);
    g.beginPath(); g.moveTo(0, -15); g.lineTo(10, -4); g.lineTo(0, 15); g.lineTo(-10, -4); g.closePath();
    const fill = g.createLinearGradient(-10, -15, 10, 15);
    fill.addColorStop(0, '#f2feff'); fill.addColorStop(0.45, '#7fe3ff'); fill.addColorStop(1, '#2a8fd6');
    g.fillStyle = fill; g.fill(); g.lineJoin = 'round'; g.lineWidth = 2; g.strokeStyle = '#1d3f8a'; g.stroke();
    g.beginPath(); g.moveTo(-10, -4); g.lineTo(10, -4); g.moveTo(0, -15); g.lineTo(-4, -4); g.lineTo(0, 15); g.lineTo(4, -4); g.closePath();
    g.strokeStyle = 'rgba(255,255,255,0.5)'; g.lineWidth = 1; g.stroke();
    g.fillStyle = 'rgba(255,255,255,0.9)';
    g.beginPath(); g.moveTo(-6, -5); g.lineTo(-1, -12); g.lineTo(-2, -5); g.closePath(); g.fill();
    crystalSprite = c;
    return c;
  }

  function drawCrystal(ctx, x, y, t, scale) {
    const spr = getCrystalSprite();
    const s = scale || 1;
    const bob = Math.sin(t * 3 + x * 0.013) * 4;
    const sx = (0.72 + 0.28 * Math.abs(Math.cos(t * 2.2 + x * 0.01))) * s;
    ctx.save();
    ctx.translate(x, y + bob);
    ctx.scale(sx, s);
    ctx.drawImage(spr, -32, -32);
    ctx.restore();
  }

  // Núcleo: mini-Saturno dourado
  function drawCore(ctx, x, y, t, scale, alpha) {
    const s = scale || 1;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    if (alpha !== undefined) ctx.globalAlpha = alpha;
    const glow = ctx.createRadialGradient(0, 0, 4, 0, 0, 40);
    glow.addColorStop(0, 'rgba(255,215,120,0.55)'); glow.addColorStop(1, 'rgba(255,190,90,0)');
    ctx.fillStyle = glow; ctx.fillRect(-40, -40, 80, 80);
    const rot = -0.35 + Math.sin(t * 1.5) * 0.08;
    // anel de trás
    ctx.lineWidth = 4; ctx.strokeStyle = '#d4a764';
    ctx.beginPath(); ctx.ellipse(0, 0, 25, 7.5, rot, Math.PI, TAU); ctx.stroke();
    // planeta
    circle(ctx, 0, 0, 12);
    const g = ctx.createRadialGradient(-4, -5, 1, 0, 0, 13);
    g.addColorStop(0, '#fff3c9'); g.addColorStop(0.5, '#f2c25a'); g.addColorStop(1, '#b97a24');
    ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#5a3510'; ctx.stroke();
    ctx.save(); circle(ctx, 0, 0, 12); ctx.clip();
    ctx.rotate(rot); ctx.fillStyle = 'rgba(160,100,30,0.35)'; ctx.fillRect(-14, -3, 28, 3); ctx.fillRect(-14, 4, 28, 2);
    ctx.restore();
    // anel da frente
    ctx.lineWidth = 4; ctx.strokeStyle = '#ffe1a0';
    ctx.beginPath(); ctx.ellipse(0, 0, 25, 7.5, rot, 0, Math.PI); ctx.stroke();
    ctx.lineWidth = 1.2; ctx.strokeStyle = '#7a4f18';
    ctx.beginPath(); ctx.ellipse(0, 0, 27, 9, rot, 0, Math.PI); ctx.stroke();
    // brilho
    const sp = (t * 1.3) % 2;
    if (sp < 1) {
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = 'rgba(255,255,230,' + (0.8 * Math.sin(sp * Math.PI)) + ')';
      ctx.beginPath(); ctx.moveTo(-6, -15); ctx.lineTo(-4.5, -10); ctx.lineTo(0, -8.5); ctx.lineTo(-4.5, -7); ctx.lineTo(-6, -2); ctx.lineTo(-7.5, -7); ctx.lineTo(-12, -8.5); ctx.lineTo(-7.5, -10); ctx.closePath(); ctx.fill();
    }
    ctx.restore();
  }

  function drawCoreSlot(ctx, x, y, s) {
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    ctx.setLineDash([3, 3]); ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(232,201,138,0.45)';
    circle(ctx, 0, 0, 11); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(0, 0, 23, 7, -0.35, 0, TAU); ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }

  // ======================= CENÁRIO DA FASE =======================
  function drawCheckpoint(ctx, cp, t) {
    const x = cp.x, y = cp.y, on = cp.active;
    if (on) {
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const a = t * 2.2;
      for (let k = 0; k < 2; k++) {
        const ang = a + k * Math.PI;
        const dx = Math.cos(ang);
        ctx.fillStyle = 'rgba(120,235,255,' + (0.12 * Math.abs(dx) + 0.03) + ')';
        ctx.beginPath(); ctx.moveTo(x, y - 88); ctx.lineTo(x + dx * 160, y - 110); ctx.lineTo(x + dx * 160, y - 66); ctx.closePath(); ctx.fill();
      }
      ctx.restore();
    }
    U.roundRect(ctx, x - 15, y - 10, 30, 10, 3);
    ctx.fillStyle = '#5d6390'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    ctx.fillStyle = '#8e96c2'; ctx.fillRect(x - 3, y - 78, 6, 68);
    ctx.lineWidth = 2; ctx.strokeRect(x - 3, y - 78, 6, 68);
    // bandeira
    ctx.beginPath(); ctx.moveTo(x + 3, y - 74);
    for (let i = 0; i <= 6; i++) ctx.lineTo(x + 3 + i * 4, y - 74 + Math.sin(t * 6 - i * 0.8) * (on ? 2.5 : 0.8) + i * (on ? 0 : 1.5));
    for (let i = 6; i >= 0; i--) ctx.lineTo(x + 3 + i * 4, y - 60 + Math.sin(t * 6 - i * 0.8) * (on ? 2.5 : 0.8) + i * (on ? 0 : 1.5));
    ctx.closePath();
    ctx.fillStyle = on ? '#5ff0ff' : '#6b5c8f'; ctx.fill(); ctx.lineWidth = 2; ctx.stroke();
    // lâmpada
    U.roundRect(ctx, x - 11, y - 100, 22, 22, 7);
    ctx.fillStyle = '#3a3668'; ctx.fill(); ctx.lineWidth = 2.5; ctx.stroke();
    if (on) {
      const gl = ctx.createRadialGradient(x, y - 89, 1, x, y - 89, 30);
      gl.addColorStop(0, 'rgba(160,245,255,0.9)'); gl.addColorStop(1, 'rgba(120,235,255,0)');
      ctx.fillStyle = gl; ctx.fillRect(x - 30, y - 119, 60, 60);
      circle(ctx, x, y - 89, 6); ctx.fillStyle = '#e8feff'; ctx.fill();
    } else {
      circle(ctx, x, y - 89, 6);
      ctx.fillStyle = Math.sin(t * 3) > 0.6 ? '#ff6b8f' : '#6b5c8f'; ctx.fill();
    }
  }

  function drawSign(ctx, sg, t) {
    const x = sg.x, y = sg.y;
    const flick = 0.82 + 0.12 * Math.sin(t * 7 + x) + (Math.random() < 0.02 ? -0.3 : 0);
    ctx.font = 'bold 17px ' + U.FONT;
    const tw = ctx.measureText(sg.title).width;
    ctx.font = 'bold 14px ' + U.FONT;
    const keys = sg.keys.map(function (k) { return { k: k, w: k === '/' ? 12 : Math.max(26, ctx.measureText(k).width + 14) }; });
    let kw = 0; keys.forEach(function (k) { kw += k.w + 6; }); kw = Math.max(0, kw - 6);
    const pw = Math.max(tw, kw) + 36;
    const ph = keys.length ? 74 : 42;
    const py = y - 46 - ph;

    // base projetora
    U.roundRect(ctx, x - 16, y - 8, 32, 8, 3);
    ctx.fillStyle = '#5d6390'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.stroke();
    circle(ctx, x, y - 8, 3); ctx.fillStyle = '#7ff6ff'; ctx.fill();

    ctx.save();
    ctx.globalAlpha = flick;
    const gb = ctx.createLinearGradient(0, y - 8, 0, py + ph);
    gb.addColorStop(0, 'rgba(120,235,255,0.25)'); gb.addColorStop(1, 'rgba(120,235,255,0.04)');
    ctx.fillStyle = gb;
    ctx.beginPath(); ctx.moveTo(x - 4, y - 8); ctx.lineTo(x + 4, y - 8); ctx.lineTo(x + pw / 2 - 10, py + ph); ctx.lineTo(x - pw / 2 + 10, py + ph); ctx.closePath(); ctx.fill();

    U.roundRect(ctx, x - pw / 2, py, pw, ph, 10);
    ctx.fillStyle = 'rgba(50,170,240,0.2)'; ctx.fill();
    ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(150,240,255,0.85)'; ctx.stroke();
    ctx.save(); U.roundRect(ctx, x - pw / 2, py, pw, ph, 10); ctx.clip();
    ctx.fillStyle = 'rgba(180,245,255,0.07)';
    const off = (t * 20) % 4;
    for (let yy = py + off; yy < py + ph; yy += 4) ctx.fillRect(x - pw / 2, yy, pw, 1.5);
    ctx.restore();

    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = 'bold 17px ' + U.FONT;
    ctx.fillStyle = '#e4fbff';
    ctx.fillText(sg.title, x, py + 21);
    if (keys.length) {
      let kx = x - kw / 2;
      ctx.font = 'bold 14px ' + U.FONT;
      keys.forEach(function (k) {
        if (k.k === '/') {
          ctx.fillStyle = 'rgba(200,240,255,0.7)'; ctx.fillText('/', kx + k.w / 2, py + 51);
        } else {
          U.roundRect(ctx, kx, py + 38, k.w, 26, 6);
          ctx.fillStyle = 'rgba(220,245,255,0.18)'; ctx.fill();
          ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(200,245,255,0.9)'; ctx.stroke();
          ctx.fillStyle = '#ffffff'; ctx.fillText(k.k, kx + k.w / 2, py + 51.5);
        }
        kx += k.w + 6;
      });
    }
    ctx.restore();
  }

  // Estação final "Anel-9"
  function drawStation(ctx, g, t, open) {
    const x = g.x, y = g.y;
    const ringY = y - 118;
    function ring(a0, a1) {
      ctx.lineWidth = 9; ctx.strokeStyle = '#d4a764';
      ctx.beginPath(); ctx.ellipse(x, ringY, 196, 30, -0.07, a0, a1); ctx.stroke();
      ctx.lineWidth = 5; ctx.strokeStyle = '#f0d9a6';
      ctx.beginPath(); ctx.ellipse(x, ringY, 178, 26, -0.07, a0, a1); ctx.stroke();
      ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(90,60,20,0.6)';
      ctx.beginPath(); ctx.ellipse(x, ringY, 188, 28, -0.07, a0, a1); ctx.stroke();
    }
    // antena
    ctx.strokeStyle = '#8e96c2'; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(x + 112, y - 70); ctx.lineTo(x + 112, y - 210); ctx.stroke();
    ctx.lineWidth = 2; ctx.strokeStyle = OUT;
    ctx.strokeRect(x + 109.5, y - 210, 5, 140);
    ctx.beginPath(); ctx.ellipse(x + 112, y - 196, 20, 8, -0.5, 0, Math.PI); ctx.fillStyle = '#c3c9e0'; ctx.fill(); ctx.stroke();
    circle(ctx, x + 112, y - 214, 5); ctx.fillStyle = Math.sin(t * 4) > 0 ? '#ff4d6b' : '#6b2a3a'; ctx.fill(); ctx.stroke();

    ring(Math.PI, TAU);

    // cúpula
    ctx.beginPath(); ctx.arc(x, y - 76, 94, Math.PI, 0); ctx.closePath();
    const gd = ctx.createLinearGradient(0, y - 170, 0, y - 76);
    gd.addColorStop(0, 'rgba(170,240,255,0.55)'); gd.addColorStop(1, 'rgba(90,170,230,0.3)');
    ctx.fillStyle = gd; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = OUT; ctx.stroke();
    // interior iluminado
    const gi = ctx.createRadialGradient(x, y - 90, 5, x, y - 90, 80);
    gi.addColorStop(0, 'rgba(255,230,170,0.5)'); gi.addColorStop(1, 'rgba(255,230,170,0)');
    ctx.fillStyle = gi; ctx.beginPath(); ctx.arc(x, y - 76, 90, Math.PI, 0); ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.65)'; ctx.lineWidth = 4;
    ctx.beginPath(); ctx.arc(x, y - 76, 80, Math.PI * 1.15, Math.PI * 1.4); ctx.stroke();
    ctx.strokeStyle = 'rgba(40,60,120,0.5)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x, y - 170); ctx.lineTo(x, y - 76); ctx.moveTo(x - 66, y - 143); ctx.lineTo(x - 30, y - 76); ctx.moveTo(x + 66, y - 143); ctx.lineTo(x + 30, y - 76); ctx.stroke();

    // casco
    U.roundRect(ctx, x - 132, y - 80, 264, 66, 18);
    const gh = ctx.createLinearGradient(0, y - 80, 0, y - 14);
    gh.addColorStop(0, '#f5f7fd'); gh.addColorStop(1, '#aeb5d2');
    ctx.fillStyle = gh; ctx.fill();
    ctx.save(); ctx.clip();
    ctx.fillStyle = '#ff8a3d'; ctx.fillRect(x - 140, y - 38, 280, 7);
    ctx.restore();
    U.roundRect(ctx, x - 132, y - 80, 264, 66, 18); ctx.lineWidth = 3; ctx.strokeStyle = OUT; ctx.stroke();
    [-100, -68, 68, 100].forEach(function (dx) {
      circle(ctx, x + dx, y - 58, 8); ctx.fillStyle = '#1f2a5c'; ctx.fill(); ctx.lineWidth = 2; ctx.stroke();
      circle(ctx, x + dx - 2, y - 60, 3); ctx.fillStyle = 'rgba(160,240,255,0.8)'; ctx.fill();
    });
    // porta
    U.roundRect(ctx, x - 25, y - 72, 50, 58, 12);
    if (open) {
      const gp = ctx.createLinearGradient(0, y - 72, 0, y - 14);
      gp.addColorStop(0, '#ffffff'); gp.addColorStop(1, '#8ff0ff');
      ctx.fillStyle = gp;
    } else {
      ctx.fillStyle = '#2a3466';
    }
    ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = OUT; ctx.stroke();
    if (!open) {
      ctx.strokeStyle = 'rgba(120,235,255,' + (0.5 + 0.5 * Math.sin(t * 4)) + ')'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(x, y - 66); ctx.lineTo(x, y - 20); ctx.stroke();
    }
    // base
    U.roundRect(ctx, x - 160, y - 16, 320, 16, 5);
    ctx.fillStyle = '#7d84ad'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
    for (let i = 0; i < 8; i++) {
      const on = Math.floor(t * 6 - i) % 8 === 0;
      circle(ctx, x - 140 + i * 40, y - 8, 3); ctx.fillStyle = on ? '#7ff6ff' : '#3a4a7a'; ctx.fill();
    }

    ring(0, Math.PI);

    // holograma com o nome
    const hy = y - 236 + Math.sin(t * 2) * 4;
    ctx.save();
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = 'bold 30px ' + U.FONT;
    ctx.globalAlpha = 0.9;
    ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(20,60,120,0.6)'; ctx.strokeText('ANEL-9', x - 20, hy);
    ctx.fillStyle = '#bff8ff'; ctx.fillText('ANEL-9', x - 20, hy);
    ctx.font = 'bold 13px ' + U.FONT; ctx.fillStyle = 'rgba(200,245,255,0.85)';
    ctx.fillText('ESTAÇÃO DE PESQUISA', x - 20, hy + 24);
    ctx.restore();
  }

  function drawDecor(ctx, d, t) {
    const x = d.x, y = d.y, s = d.s;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    ctx.lineJoin = 'round';
    switch (d.type) {
      case 'pod': {
        ctx.fillStyle = 'rgba(10,5,30,0.35)'; ctx.beginPath(); ctx.ellipse(0, 0, 50, 6, 0, 0, TAU); ctx.fill();
        // fumaça
        for (let i = 0; i < 3; i++) {
          const ph = (t * 0.35 + i / 3) % 1;
          ctx.fillStyle = 'rgba(200,200,230,' + ((1 - ph) * 0.18).toFixed(3) + ')';
          circle(ctx, 20 + ph * 25, -40 - ph * 70, 6 + ph * 14); ctx.fill();
        }
        limb(ctx, -20, -20, -34, -1, 4, '#8e96c2');
        limb(ctx, 20, -20, 34, -1, 4, '#8e96c2');
        ctx.beginPath(); ctx.moveTo(-30, -16); ctx.lineTo(-17, -76); ctx.arc(0, -76, 17, Math.PI, 0); ctx.lineTo(30, -16); ctx.closePath();
        const g = ctx.createLinearGradient(-30, 0, 30, 0);
        g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#b8bfdb');
        ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = OUT; ctx.stroke();
        ctx.fillStyle = '#ff8a3d'; ctx.fillRect(-27, -30, 54, 7); ctx.lineWidth = 2; ctx.strokeRect(-27, -30, 54, 7);
        circle(ctx, 0, -56, 10); ctx.fillStyle = '#1f2a5c'; ctx.fill(); ctx.lineWidth = 3; ctx.stroke();
        circle(ctx, -3, -59, 3.5); ctx.fillStyle = 'rgba(160,240,255,0.8)'; ctx.fill();
        U.roundRect(ctx, -36, -18, 72, 10, 4); ctx.fillStyle = '#5d6390'; ctx.fill(); ctx.lineWidth = 2.5; ctx.stroke();
        circle(ctx, 0, -95, 3.5); ctx.fillStyle = Math.sin(t * 5) > 0 ? '#ff4d6b' : '#5a2a3a'; ctx.fill();
        break;
      }
      case 'antenna': {
        ctx.strokeStyle = '#6a6f9e'; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(-14, 0); ctx.lineTo(-3, -120); ctx.moveTo(14, 0); ctx.lineTo(3, -120); ctx.stroke();
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < 6; i++) {
          const y0 = -i * 20, y1 = -(i + 1) * 20;
          const w0 = 14 - i * 1.8, w1 = 14 - (i + 1) * 1.8;
          ctx.moveTo(-w0, y0); ctx.lineTo(w1, y1); ctx.moveTo(w0, y0); ctx.lineTo(-w1, y1);
        }
        ctx.stroke();
        ctx.save(); ctx.translate(0, -118); ctx.rotate(-0.6 + Math.sin(t * 0.4) * 0.15);
        ctx.beginPath(); ctx.ellipse(0, 0, 22, 9, 0, 0, Math.PI); ctx.closePath();
        ctx.fillStyle = '#d3d8ee'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, 2); ctx.lineTo(0, 14); ctx.stroke();
        ctx.restore();
        circle(ctx, 0, -126, 4); ctx.fillStyle = Math.sin(t * 3 + x) > 0.3 ? '#ff4d6b' : '#5a2a3a'; ctx.fill();
        break;
      }
      case 'cluster': {
        const shards = [[-26, 34, -0.35, 12], [-10, 56, -0.12, 16], [8, 44, 0.15, 14], [24, 28, 0.42, 10], [-2, 24, 0, 9]];
        shards.forEach(function (sh, i) {
          ctx.save(); ctx.translate(sh[0], 0); ctx.rotate(sh[2]);
          ctx.beginPath(); ctx.moveTo(-sh[3] / 2, 0); ctx.lineTo(-sh[3] / 2, -sh[1] * 0.75); ctx.lineTo(0, -sh[1]); ctx.lineTo(sh[3] / 2, -sh[1] * 0.75); ctx.lineTo(sh[3] / 2, 0); ctx.closePath();
          const g = ctx.createLinearGradient(-sh[3] / 2, 0, sh[3] / 2, 0);
          g.addColorStop(0, 'rgba(230,252,255,0.9)'); g.addColorStop(1, 'rgba(90,170,230,0.75)');
          ctx.fillStyle = g; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#26407e'; ctx.stroke();
          ctx.strokeStyle = 'rgba(255,255,255,0.8)'; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(-sh[3] / 4, -3); ctx.lineTo(-sh[3] / 4, -sh[1] * 0.7); ctx.stroke();
          ctx.restore();
          if (i === 1) {
            const tw = Math.max(0, Math.sin(t * 2 + x));
            ctx.fillStyle = 'rgba(255,255,255,' + tw + ')';
            ctx.beginPath(); ctx.moveTo(-10, -60); ctx.lineTo(-8, -55); ctx.lineTo(-3, -53); ctx.lineTo(-8, -51); ctx.lineTo(-10, -46); ctx.lineTo(-12, -51); ctx.lineTo(-17, -53); ctx.lineTo(-12, -55); ctx.closePath(); ctx.fill();
          }
        });
        break;
      }
      case 'rocks': {
        [[-20, 18, 14], [6, 24, 20], [32, 14, 10]].forEach(function (r) {
          ctx.beginPath(); ctx.ellipse(r[0], 0, r[1], r[2], 0, Math.PI, 0); ctx.closePath();
          ctx.fillStyle = '#4a3e85'; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = OUT; ctx.stroke();
          ctx.beginPath(); ctx.ellipse(r[0], -r[2] + 3, r[1] * 0.6, 4, 0, Math.PI, 0); ctx.fillStyle = '#dff7ff'; ctx.fill();
        });
        break;
      }
      case 'pipes': {
        ctx.lineCap = 'butt';
        limb(ctx, -60, -14, 40, -14, 14, '#8e96c2');
        limb(ctx, 40, -14, 40, -70, 14, '#8e96c2');
        limb(ctx, -40, -34, 10, -34, 10, '#6a6f9e');
        [-20, 20].forEach(function (px) { ctx.fillStyle = '#ff8a3d'; ctx.fillRect(px - 4, -24, 8, 20); ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.strokeRect(px - 4, -24, 8, 20); });
        circle(ctx, 40, -78, 10); ctx.fillStyle = '#ff8a3d'; ctx.fill(); ctx.lineWidth = 2.5; ctx.stroke();
        ctx.beginPath(); ctx.moveTo(30, -78); ctx.lineTo(50, -78); ctx.moveTo(40, -88); ctx.lineTo(40, -68); ctx.stroke();
        for (let i = 0; i < 3; i++) {
          const ph = (t * 0.6 + i / 3) % 1;
          ctx.fillStyle = 'rgba(225,248,255,' + ((1 - ph) * 0.3).toFixed(3) + ')';
          circle(ctx, -62 - ph * 20, -18 - ph * 40, 4 + ph * 10); ctx.fill();
        }
        break;
      }
      case 'lamp': {
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        const gl = ctx.createLinearGradient(0, -80, 0, 0);
        gl.addColorStop(0, 'rgba(255,230,170,0.22)'); gl.addColorStop(1, 'rgba(255,230,170,0)');
        ctx.fillStyle = gl;
        ctx.beginPath(); ctx.moveTo(14, -84); ctx.lineTo(28, -84); ctx.lineTo(70, 0); ctx.lineTo(-28, 0); ctx.closePath(); ctx.fill();
        ctx.restore();
        ctx.fillStyle = '#6a6f9e'; ctx.fillRect(-3, -96, 6, 96);
        ctx.lineWidth = 2; ctx.strokeStyle = OUT; ctx.strokeRect(-3, -96, 6, 96);
        ctx.beginPath(); ctx.moveTo(0, -94); ctx.lineTo(22, -94); ctx.stroke();
        U.roundRect(ctx, 10, -94, 24, 11, 4); ctx.fillStyle = '#4d4878'; ctx.fill(); ctx.stroke();
        circle(ctx, 22, -82, 4); ctx.fillStyle = '#fff1c8'; ctx.fill();
        break;
      }
    }
    ctx.restore();
  }

  return {
    OUT: OUT,
    drawRobot: drawRobot, drawShadow: drawShadow,
    drawRock: drawRock, drawMetal: drawMetal, drawLedge: drawLedge, drawMover: drawMover, drawCrumble: drawCrumble,
    drawPad: drawPad, drawSpikes: drawSpikes, drawLaserBase: drawLaserBase, drawLaserBeam: drawLaserBeam,
    drawMite: drawMite, drawCrystal: drawCrystal, getCrystalSprite: getCrystalSprite, drawCore: drawCore, drawCoreSlot: drawCoreSlot,
    drawCheckpoint: drawCheckpoint, drawSign: drawSign, drawStation: drawStation, drawDecor: drawDecor,
  };
})();
