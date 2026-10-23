// Sistema simples de partículas com reaproveitamento de objetos.
SE.Particles = (function () {
  const MAX = 500;
  const pool = [];
  const live = [];

  function spawn(o) {
    if (live.length >= MAX) return null;
    const p = pool.pop() || {};
    p.x = o.x; p.y = o.y;
    p.vx = o.vx || 0; p.vy = o.vy || 0;
    p.life = p.max = o.life || 0.6;
    p.size = o.size || 4;
    p.grow = o.grow || 0;
    p.color = o.color || '#fff';
    p.type = o.type || 'dot';
    p.grav = o.grav || 0;
    p.drag = o.drag || 0;
    p.rot = o.rot || 0;
    p.vr = o.vr || 0;
    p.glow = !!o.glow;
    live.push(p);
    return p;
  }

  function update(dt) {
    for (let i = live.length - 1; i >= 0; i--) {
      const p = live[i];
      p.life -= dt;
      if (p.life <= 0) { live[i] = live[live.length - 1]; live.pop(); pool.push(p); continue; }
      p.vy += p.grav * dt;
      if (p.drag) { const k = Math.exp(-p.drag * dt); p.vx *= k; p.vy *= k; }
      p.x += p.vx * dt; p.y += p.vy * dt;
      p.rot += p.vr * dt;
      p.size = Math.max(0, p.size + p.grow * dt);
    }
  }

  function draw(ctx) {
    for (let i = 0; i < live.length; i++) {
      const p = live[i];
      const t = p.life / p.max;
      ctx.globalAlpha = Math.min(1, t * 1.6);
      if (p.glow) ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = p.color;
      ctx.strokeStyle = p.color;
      switch (p.type) {
        case 'dot':
          ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.fill();
          break;
        case 'spark': {
          const len = Math.hypot(p.vx, p.vy) * 0.03 + 2;
          const a = Math.atan2(p.vy, p.vx);
          ctx.lineWidth = p.size; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - Math.cos(a) * len, p.y - Math.sin(a) * len); ctx.stroke();
          break;
        }
        case 'star': {
          const s = p.size * (0.6 + 0.4 * t);
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.beginPath();
          for (let k = 0; k < 4; k++) {
            const ang = k * Math.PI / 2;
            ctx.lineTo(Math.cos(ang) * s, Math.sin(ang) * s);
            ctx.lineTo(Math.cos(ang + Math.PI / 4) * s * 0.3, Math.sin(ang + Math.PI / 4) * s * 0.3);
          }
          ctx.closePath(); ctx.fill(); ctx.restore();
          break;
        }
        case 'ring':
          ctx.lineWidth = 3 * t;
          ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.stroke();
          break;
        case 'debris':
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.7);
          ctx.restore();
          break;
      }
      ctx.globalCompositeOperation = 'source-over';
    }
    ctx.globalAlpha = 1;
  }

  // Efeitos prontos
  const fx = {
    dust: function (x, y, n, dir) {
      for (let i = 0; i < n; i++) {
        spawn({ x: x + (Math.random() - 0.5) * 18, y: y - 2, vx: (Math.random() - 0.5) * 120 + (dir || 0) * 60, vy: -Math.random() * 70 - 10,
          life: 0.35 + Math.random() * 0.3, size: 3 + Math.random() * 4, grow: 8, color: 'rgba(200,225,255,0.75)', drag: 4 });
      }
    },
    burst: function (x, y, color, n, speed) {
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2, s = (0.4 + Math.random() * 0.6) * (speed || 260);
        spawn({ x: x, y: y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.4 + Math.random() * 0.35, size: 2.2, type: 'spark', color: color, drag: 3, glow: true });
      }
    },
    sparkle: function (x, y, color, n) {
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2, s = 40 + Math.random() * 120;
        spawn({ x: x, y: y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 40, life: 0.5 + Math.random() * 0.4, size: 5 + Math.random() * 4, type: 'star', color: color, drag: 2.5, rot: Math.random() * 3, vr: 4, glow: true });
      }
    },
    ring: function (x, y, color, size, life) {
      spawn({ x: x, y: y, life: life || 0.45, size: size || 6, grow: 120, type: 'ring', color: color, glow: true });
    },
    debris: function (x, y, colors, n) {
      for (let i = 0; i < n; i++) {
        const a = -Math.PI / 2 + (Math.random() - 0.5) * 2.6, s = 150 + Math.random() * 350;
        spawn({ x: x, y: y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.8 + Math.random() * 0.6, size: 4 + Math.random() * 6, type: 'debris',
          color: colors[i % colors.length], grav: 1400, rot: Math.random() * 6, vr: (Math.random() - 0.5) * 20 });
      }
    },
    thrust: function (x, y, dir) {
      spawn({ x: x, y: y, vx: (Math.random() - 0.5) * 40 + dir * 40, vy: 120 + Math.random() * 80, life: 0.25, size: 3 + Math.random() * 2, grow: -8, color: Math.random() < 0.5 ? '#ffb347' : '#ffe08a', glow: true });
    },
  };

  function clear() { while (live.length) pool.push(live.pop()); }

  return { spawn, update, draw, fx, clear, get count() { return live.length; } };
})();
