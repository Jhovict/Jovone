# Space Explorer — progresso (fase 1 concluída em 23/10/2026)

Jogo de plataforma 2D no navegador (fase 1: Saturno). HTML5 Canvas + JavaScript puro, sem dependências.
Usa scripts clássicos (sem módulos ES) para abrir com duplo clique no `index.html`; para testar, também dá para rodar `python -m http.server` nesta pasta.
O documento de requisitos completo foi colado na conversa original. Os pontos principais estão abaixo.

## Já escrito
- `index.html`: canvas, botões touch e ordem dos scripts.
- `css/style.css`: tela com letterbox e botões touch (só aparecem em telas de toque, com a classe `.on`).
- `js/config.js`: parâmetros de física e câmera (`SE.CONFIG`).
- `js/util.js`: clamp/lerp/damp, RNG determinístico, `overlap`, `roundRect`, `fmtTime`, `FONT` (`SE.U`).
- `js/input.js`: teclado, touch e clique (`SE.Input`: isDown, wasHit, endFrame, bindTouch, bindCanvas, pointer, onGesture).
- `js/audio.js`: efeitos sonoros e música ambiente sintetizados com Web Audio (`SE.Audio`: init, play(nome), startMusic, setMusicLevel, toggleMute).
  Sons disponíveis: jump, land, step, crystal, core, stomp, pad, hurt, checkpoint, crumble, laser, win, ui, uiMove, start.
- `js/particles.js`: partículas (`SE.Particles`: spawn, update, draw, clear; fx.dust/burst/sparkle/ring/debris/thrust).
- `js/level.js`: fase completa em dados (`SE.LEVELS.saturn.build()`): solids (rock/boulder/pillar/metal/ledge one-way, mesa), movers, crumbles, pads (gêiser), spikes, lasers, mites (ácaros), crystals, cores (3 núcleos), checkpoints, signs, decor (pod/antenna/cluster/rocks/pipes/lamp) e goal (x 8420, y 300).

## Concluído em 23/10/2026
- `js/art.js`, `js/background.js`, `js/player.js`, `js/world.js`, `js/ui.js` e `js/game.js` escritos.
- Testado no navegador: sem erros no console; pulo (~162 px, menor ao soltar cedo), colisão com paredes, gêiser, espinhos e respawn no checkpoint, pisar em ácaros, plataformas móveis carregando o robô, placas de gelo que desabam, lasers, coleta, pausa, menu e tela de conclusão.
- Todos os vãos da fase foram conferidos (alcance máximo do pulo ~230 px; maior vão é de 170 px).
- `README.md` com instruções de execução e controles.

## Ideias para depois
- Testar os controles de toque em um celular de verdade.
- Próximas fases (outros planetas) usando o mesmo formato de `SE.LEVELS`.

## Paleta e decisões
Céu índigo e roxo, Saturno em tons bege e dourado (#e8c98a, #d4a764), terreno lilás (#5a4d92 → #1a1336) com gelo ciano (#d6f4ff → #8fd3f0).
Robô branco com detalhes laranja (#ff8a3d) e visor ciano. Perigos em magenta (#ff4d8d). Cristais em ciano. Núcleos dourados.
Sem vidas: o jogador volta no último checkpoint e mantém os itens coletados. Ácaros derrotados continuam derrotados.
