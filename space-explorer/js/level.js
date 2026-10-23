// Definição da fase 1: Saturno — "Anel de Gelo".
// Coordenadas do mundo: y cresce para baixo; o chão principal fica em y = 560.
// Para alterar o percurso, edite apenas a função build() abaixo.
SE.LEVELS = SE.LEVELS || {};

SE.LEVELS.saturn = (function () {
  const BOTTOM = 1300; // os blocos de terreno descem até aqui (fora da tela)

  function build() {
    const L = {
      name: 'Saturno',
      subtitle: 'Anel de Gelo',
      left: 0, right: 8760,
      spawn: { x: 230, y: 560 },
      solids: [], movers: [], crumbles: [], pads: [], spikes: [], lasers: [],
      mites: [], crystals: [], cores: [], checkpoints: [], signs: [], decor: [], goal: null,
    };

    // ---- construtores ----
    const ground = function (x, w, top, opts) { L.solids.push(Object.assign({ x: x, y: top, w: w, h: BOTTOM - top, kind: 'rock' }, opts || {})); };
    const boulder = function (x, w, top, base) { L.solids.push({ x: x, y: top, w: w, h: base - top, kind: 'boulder' }); };
    const pillar = function (x, w, top) { L.solids.push({ x: x, y: top, w: w, h: BOTTOM - top, kind: 'pillar' }); };
    const plat = function (x, y, w) { L.solids.push({ x: x, y: y, w: w, h: 26, kind: 'metal' }); };
    const ledge = function (x, y, w) { L.solids.push({ x: x, y: y, w: w, h: 14, kind: 'ledge', oneWay: true }); };
    const mover = function (x, y, w, dx, dy, period, phase) { L.movers.push({ x0: x, y0: y, w: w, h: 22, dx: dx, dy: dy, period: period, phase: phase || 0 }); };
    const crumble = function (x, y, w) { L.crumbles.push({ x0: x, y0: y, w: w, h: 30 }); };
    const pad = function (x, groundY) { L.pads.push({ x: x, y: groundY - 18, w: 64, h: 18 }); };
    const spikes = function (x, groundY, w) { L.spikes.push({ x: x, y: groundY - 30, w: w, h: 30 }); };
    const laser = function (x, top, bottom, on, off, phase) { L.lasers.push({ x: x, top: top, bottom: bottom, on: on, off: off, phase: phase || 0 }); };
    const mite = function (x1, x2, groundY) { L.mites.push({ x1: x1, x2: x2, y: groundY }); };
    const crystal = function (x, y) { L.crystals.push({ x: x, y: y }); };
    const row = function (x, y, n, gap) { for (let i = 0; i < n; i++) crystal(x + i * gap, y); };
    const arc = function (x, y, n, gap, h) {
      for (let i = 0; i < n; i++) { const t = n === 1 ? 0.5 : i / (n - 1); crystal(x + i * gap, y - Math.sin(t * Math.PI) * h); }
    };
    const core = function (x, y) { L.cores.push({ x: x, y: y }); };
    const checkpoint = function (x, groundY) { L.checkpoints.push({ x: x, y: groundY }); };
    const sign = function (x, groundY, title, keys) { L.signs.push({ x: x, y: groundY, title: title, keys: keys || [] }); };
    const deco = function (type, x, y, s) { L.decor.push({ type: type, x: x, y: y, s: s || 1 }); };

    // ================= SEÇÃO 1 — Pouso e tutorial =================
    ground(-400, 1500, 560);
    deco('pod', 120, 560);
    deco('cluster', 520, 560, 0.8);
    deco('antenna', 900, 560, 1);
    sign(330, 560, 'MOVER', ['←', '→', '/', 'A', 'D']);
    row(430, 520, 4, 50);
    boulder(760, 130, 494, 560);
    sign(620, 560, 'PULAR', ['ESPAÇO', '/', '↑']);
    row(790, 440, 3, 35);
    sign(985, 560, 'SEGURE PARA IR MAIS ALTO', []);
    arc(1130, 470, 4, 40, 40);

    // ================= SEÇÃO 2 — Plataformas e primeiro perigo =================
    ground(1260, 690, 560);
    plat(1420, 445, 150);
    row(1460, 405, 2, 60);
    plat(1630, 335, 140);
    row(1655, 295, 3, 40);
    ledge(1830, 235, 120);              // caminho alternativo
    core(1900, 192);                    // Núcleo 1
    spikes(1790, 560, 90);
    deco('cluster', 1300, 560, 1.1);
    deco('lamp', 1590, 560);

    // ================= SEÇÃO 3 — Ácaros =================
    ground(2110, 910, 520);
    sign(2200, 520, 'PISE NOS ÁCAROS', []);
    mite(2360, 2660, 520);
    row(2400, 430, 4, 70);
    spikes(2720, 520, 110);
    arc(2725, 440, 3, 50, 30);
    checkpoint(2900, 520);
    deco('rocks', 2320, 520);
    deco('antenna', 2980, 520, 0.8);

    // ================= SEÇÃO 4 — Abismo com plataformas móveis =================
    mover(3090, 500, 130, 220, 0, 4.0, 0);
    row(3160, 440, 3, 100);
    pillar(3500, 100, 470);
    crystal(3550, 420);
    mover(3660, 470, 120, 0, -150, 3.6, 0);
    crystal(3720, 300);
    crystal(3720, 250);

    // ================= SEÇÃO 5 — Gêiseres e rota alta =================
    ground(3950, 1000, 560);
    sign(4030, 560, 'GÊISER: PISE PARA SUBIR', []);
    pad(4130, 560);
    ledge(4190, 210, 280);
    row(4235, 168, 5, 50);
    ledge(4560, 170, 140);
    core(4640, 122);                    // Núcleo 2
    mite(4290, 4480, 560);
    mite(4620, 4860, 560);
    row(4560, 515, 3, 60);
    deco('cluster', 4000, 560, 0.9);
    deco('pipes', 4890, 560);

    // Placas de gelo que desabam
    crumble(5030, 530, 110);
    crumble(5220, 490, 110);
    crystal(5085, 470);
    crystal(5275, 430);

    // ================= SEÇÃO 6 — Lasers e combinação =================
    ground(5410, 1290, 560);
    checkpoint(5520, 560);
    sign(5650, 560, 'ESPERE O LASER DESLIGAR', []);
    laser(5800, 300, 560, 1.3, 1.3, 0);
    mite(5880, 6070, 560);
    row(5900, 510, 3, 60);
    laser(6150, 300, 560, 1.3, 1.3, 1.3);
    spikes(6300, 560, 260);
    plat(6320, 455, 80);
    plat(6470, 405, 80);
    crystal(6360, 410);
    crystal(6510, 360);
    deco('lamp', 6250, 560);

    // Segundo abismo
    mover(6760, 500, 130, 220, 0, 3.6, 0.5);
    crystal(6830, 450);
    crystal(6930, 450);
    core(6905, 330);                    // Núcleo 3 (arriscado)

    // ================= SEÇÃO 7 — Escalada final =================
    ground(7150, 700, 560);
    spikes(7380, 560, 260);
    plat(7330, 470, 90);
    plat(7500, 390, 90);
    ledge(7680, 310, 110);
    crystal(7375, 430);
    crystal(7545, 350);
    crystal(7735, 270);
    ground(7850, 920, 300, { mesa: true });
    row(7960, 260, 4, 50);
    mite(8020, 8220, 300);
    L.goal = { x: 8420, y: 300 };
    deco('antenna', 8650, 300, 1.2);
    deco('cluster', 7920, 300, 0.7);

    return L;
  }

  return { build: build };
})();
