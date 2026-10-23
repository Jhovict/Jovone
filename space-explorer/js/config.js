// Parâmetros ajustáveis do jogo. Unidades: pixels e segundos.
window.SE = window.SE || {};

SE.CONFIG = {
  VIEW_W: 1280,
  VIEW_H: 720,
  STEP: 1 / 120,          // passo fixo da física
  MAX_FRAME: 0.1,         // limita o salto de tempo após troca de aba

  player: {
    w: 30, h: 50,          // caixa de colisão
    gravity: 2500,         // gravidade subindo
    fallGravity: 3300,     // gravidade caindo (queda mais firme, menos "flutuante")
    maxFall: 1150,
    runSpeed: 340,
    accelGround: 3000,
    decelGround: 3800,
    accelAir: 2100,
    decelAir: 1300,
    jumpVel: 910,          // ~165px de altura máxima
    jumpCut: 0.42,         // soltar o pulo cedo corta a subida
    coyote: 0.10,          // tolerância após sair da borda
    jumpBuffer: 0.13,      // tolerância para apertar pulo antes de tocar o chão
    padVel: 1480,          // impulso do gêiser
    stompVel: 720,
    stompVelHeld: 980,
  },

  camera: {
    anchorX: 0.40,         // posição horizontal do robô na tela
    lookAhead: 110,
    smoothX: 5.5,
    smoothY: 3.5,
    minY: -340,
    maxY: 0,
  },

  killY: 980,
  respawnDelay: 1.0,
};
