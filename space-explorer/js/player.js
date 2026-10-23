// Robô do jogador: física com passo fixo, colisão e animação.
// x, y = canto superior esquerdo da caixa de colisão.
SE.createPlayer = function () {
  const C = SE.CONFIG.player;
  const U = SE.U, P = SE.Particles, A = SE.Audio;

  const p = {
    w: C.w, h: C.h,
    x: 0, y: 0, vx: 0, vy: 0, prevY: 0,
    facing: 1,
    ground: null,          // objeto em que está apoiado
    coyoteT: 0, bufferT: 0, dropT: 0,
    jumping: false,
    dead: false, invuln: 0,
    auto: null, entering: 0, alpha: 1,
    // animação
    sx: 1, sy: 1, run: 0, antenna: 0, antV: 0,
    blinkT: 2, blink: 0, thrustT: 0, stepT: 0,
  };

  Object.defineProperty(p, 'cx', { get: function () { return this.x + this.w / 2; } });
  Object.defineProperty(p, 'bottom', { get: function () { return this.y + this.h; } });

  p.reset = function (feetX, feetY) {
    this.x = feetX - this.w / 2; this.y = feetY - this.h; this.prevY = this.y;
    this.vx = 0; this.vy = 0; this.ground = null;
    this.coyoteT = 0; this.bufferT = 0; this.dropT = 0; this.jumping = false;
    this.dead = false; this.auto = null; this.entering = 0; this.alpha = 1;
    this.sx = 1.25; this.sy = 0.8; this.antenna = 0; this.antV = 4; this.thrustT = 0;
  };

  p.die = function () {
    this.dead = true; this.vx = 0; this.vy = 0; this.ground = null;
  };

  const NEUTRAL = { move: 0, jumpHeld: false, jumpPressed: false, down: false };

  p.update = function (dt, W, inp) {
    // animações que rodam sempre
    this.blinkT -= dt;
    if (this.blinkT <= 0) { this.blink = 0.13; this.blinkT = 2 + Math.random() * 3.5; }
    if (this.blink > 0) this.blink -= dt;
    this.sx = U.damp(this.sx, 1, 14, dt);
    this.sy = U.damp(this.sy, 1, 14, dt);
    if (this.dead) return;
    if (this.invuln > 0) this.invuln -= dt;

    // caminhada automática até a porta da estação
    let move = inp.move;
    if (this.auto !== null) {
      inp = NEUTRAL;
      const d = this.auto - this.cx;
      move = Math.abs(d) < 3 ? 0 : Math.sign(d);
      if (move === 0) { this.entering += dt; this.alpha = Math.max(0, 1 - this.entering / 0.6); this.vx = 0; }
    }

    // ser carregado por plataformas móveis
    let carryX = 0;
    if (this.ground && this.ground.kind === 'mover') { carryX = this.ground.mdx; this.y += this.ground.mdy; }

    // movimento horizontal
    const target = move * (this.auto !== null ? C.runSpeed * 0.45 : C.runSpeed);
    let accel;
    if (this.ground) {
      if (move === 0) accel = C.decelGround;
      else if (this.vx !== 0 && Math.sign(this.vx) !== move) accel = C.accelGround + C.decelGround;
      else accel = C.accelGround;
    } else {
      accel = move === 0 ? C.decelAir : C.accelAir;
    }
    const prevVx = this.vx;
    this.vx = U.approach(this.vx, target, accel * dt);
    if (move !== 0) this.facing = move;

    // pulo (com buffer e coyote time)
    if (inp.jumpPressed) this.bufferT = C.jumpBuffer; else this.bufferT -= dt;
    if (this.ground) this.coyoteT = C.coyote; else this.coyoteT -= dt;
    if (this.dropT > 0) this.dropT -= dt;

    if (this.bufferT > 0 && this.coyoteT > 0) {
      if (inp.down && this.ground && this.ground.kind === 'ledge') {
        // baixo + pulo: desce da borda atravessável
        this.dropT = 0.25; this.y += 2;
      } else {
        this.vy = -C.jumpVel;
        this.jumping = true;
        this.thrustT = 0.22;
        this.sx = 0.74; this.sy = 1.28;
        this.antV += (Math.random() - 0.5) * 6;
        A.play('jump');
        P.fx.dust(this.cx, this.bottom, 6, 0);
      }
      this.bufferT = 0; this.coyoteT = 0; this.ground = null;
    }
    // pulo variável: soltar cedo corta a subida
    if (this.jumping && !inp.jumpHeld && this.vy < 0) { this.vy *= C.jumpCut; this.jumping = false; }
    if (this.vy >= 0) this.jumping = false;

    // gravidade (mais forte na queda; leve flutuação no ápice)
    let g = this.vy < 0 ? C.gravity : C.fallGravity;
    if (inp.jumpHeld && !this.ground && Math.abs(this.vy) < 90) g *= 0.65;
    this.vy = Math.min(this.vy + g * dt, C.maxFall);

    // colisão: primeiro X, depois Y
    this.moveX(this.vx * dt + carryX, W);
    const wasGround = !!this.ground;
    const vyBefore = this.vy;
    this.prevY = this.y;
    this.moveY(this.vy * dt, W);

    // pouso
    if (this.ground && !wasGround) {
      const impact = U.clamp(vyBefore / C.maxFall, 0, 1);
      if (impact > 0.12) {
        this.sx = 1 + 0.35 * impact; this.sy = 1 - 0.3 * impact;
        this.antV += this.facing * 6 * impact;
        A.play('land', impact);
        P.fx.dust(this.cx, this.bottom, 3 + Math.round(impact * 8), 0);
      }
      if (this.ground.kind === 'crumble') W.touchCrumble(this.ground);
    }

    // gêiser
    for (let i = 0; i < W.pads.length; i++) {
      const pad = W.pads[i];
      if (this.vy >= 0 && U.overlap(this, pad)) {
        this.vy = -C.padVel;
        this.ground = null; this.jumping = false; this.coyoteT = 0;
        this.sx = 0.7; this.sy = 1.35; this.thrustT = 0.45;
        this.antV -= 5;
        pad.fx = 1;
        A.play('pad');
        P.fx.burst(pad.x + pad.w / 2, pad.y, 'rgba(220,250,255,0.9)', 16, 320);
        P.fx.ring(pad.x + pad.w / 2, pad.y, '#bff8ff', 10, 0.4);
      }
    }

    // passos e partículas
    if (this.ground && Math.abs(this.vx) > 40) {
      this.run += Math.abs(this.vx) * dt * 0.052;
      this.stepT -= dt;
      if (this.stepT <= 0) {
        this.stepT = 0.27;
        A.play('step');
        if (Math.random() < 0.5) P.fx.dust(this.cx - this.facing * 8, this.bottom, 1, -this.facing);
      }
    } else {
      this.stepT = 0.05;
    }
    if (this.thrustT > 0) {
      this.thrustT -= dt;
      if (Math.random() < 0.55) P.fx.thrust(this.cx - this.facing * 15, this.bottom - 14, -this.facing * 0.5);
    }

    // antena com mola
    const lean = -this.vx / C.runSpeed * 0.3 - (this.vx - prevVx) * 0.004;
    this.antV += ((lean - this.antenna) * 180 - this.antV * 9) * dt;
    this.antenna += this.antV * dt;
  };

  p.moveX = function (dx, W) {
    if (dx === 0) return;
    this.x += dx;
    const S = W.solids;
    for (let i = 0; i < S.length; i++) {
      const s = S[i];
      if (U.overlap(this, s)) {
        if (dx > 0) this.x = s.x - this.w; else this.x = s.x + s.w;
        this.vx = 0;
      }
    }
    const L = W.L;
    if (this.x < L.left) { this.x = L.left; this.vx = 0; }
    if (this.x + this.w > L.right) { this.x = L.right - this.w; this.vx = 0; }
  };

  p.moveY = function (dy, W) {
    const prevBottom = this.y + this.h;
    this.y += dy;
    this.ground = null;
    const S = W.solids;
    for (let i = 0; i < S.length; i++) {
      const s = S[i];
      if (U.overlap(this, s)) {
        if (dy > 0) { this.y = s.y - this.h; this.vy = 0; this.ground = s; }
        else if (dy < 0) { this.y = s.y + s.h; this.vy = 0; this.jumping = false; }
      }
    }
    if (dy >= 0) {
      const Pl = W.platforms;
      for (let i = 0; i < Pl.length; i++) {
        const pl = Pl[i];
        if (pl.off) continue;
        if (this.dropT > 0 && pl.kind === 'ledge') continue;
        if (this.x + this.w > pl.x && this.x < pl.x + pl.w && prevBottom <= pl.y + 2 && this.y + this.h >= pl.y) {
          this.y = pl.y - this.h; this.vy = 0; this.ground = pl;
        }
      }
    }
  };

  p.draw = function (ctx, t) {
    if (this.dead || this.alpha <= 0) return;
    let alpha = this.alpha;
    if (this.invuln > 0 && Math.floor(this.invuln * 16) % 2 === 0) alpha *= 0.45;
    SE.Art.drawRobot(ctx, this.cx, this.bottom, {
      facing: this.facing, sx: this.sx, sy: this.sy,
      run: this.run, moving: Math.abs(this.vx) > 30, air: !this.ground, vy: this.vy,
      blink: this.blink > 0, antenna: this.antenna, thrust: this.thrustT > 0,
      alpha: alpha, t: t,
    });
  };

  return p;
};
