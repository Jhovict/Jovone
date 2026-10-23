// Funções utilitárias compartilhadas.
SE.U = (function () {
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function damp(a, b, k, dt) { return a + (b - a) * (1 - Math.exp(-k * dt)); }
  function approach(v, target, delta) {
    return v < target ? Math.min(v + delta, target) : Math.max(v - delta, target);
  }

  // Gerador pseudoaleatório determinístico (mesmo cenário a cada execução)
  function rng(seed) {
    let a = seed >>> 0;
    const f = function () {
      a = (a + 0x6D2B79F5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    f.range = function (lo, hi) { return lo + f() * (hi - lo); };
    f.int = function (lo, hi) { return Math.floor(lo + f() * (hi - lo + 1)); };
    return f;
  }

  function overlap(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
  }

  function roundRect(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  const easeOutBack = function (t) { const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };
  const easeInOut = function (t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };

  function fmtTime(s) {
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    const cs = Math.floor((s * 100) % 100);
    return m + ':' + String(sec).padStart(2, '0') + '.' + String(cs).padStart(2, '0');
  }

  const FONT = "'Trebuchet MS', 'Segoe UI', 'Helvetica Neue', Arial, sans-serif";

  return { clamp, lerp, damp, approach, rng, overlap, roundRect, easeOutBack, easeInOut, fmtTime, FONT };
})();
