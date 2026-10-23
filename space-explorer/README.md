# Space Explorer — Fase 1: Saturno

Jogo de plataforma 2D no navegador. Um robô explorador atravessa o "Anel de Gelo" de Saturno, coleta cristais e os 3 núcleos e chega à Estação Anel-9.
Feito com HTML5 Canvas e JavaScript puro, sem dependências nem arquivos de imagem ou som: tudo é desenhado e sintetizado no código.

## Como jogar

**Opção 1:** abra o `index.html` com dois cliques.

**Opção 2 (recomendada):** rode um servidor local nesta pasta e abra http://localhost:8000

```bash
python -m http.server 8000
```

## Controles

| Ação | Teclado | Toque |
|---|---|---|
| Mover | ← → ou A D | botões ◀ ▶ |
| Pular (segure para ir mais alto) | Espaço, ↑, W, Z ou K | botão ▲ |
| Descer de uma borda de gelo | ↓ + pular | — |
| Pausar | Esc ou P | botão II |
| Reiniciar a fase | R | menu de pausa |
| Som liga/desliga | M | — |

Nos menus: ↑ ↓ e Enter, ou clique/toque no botão.

## Regras

- Não há vidas. Ao cair ou encostar em um perigo, o robô volta ao último farol (checkpoint) e mantém os itens coletados.
- Perigos: espinhos de cristal magenta, lasers (espere desligar) e ácaros (pise em cima para derrotá-los).
- Gêiseres lançam o robô para cima. Placas de gelo rachadas desabam pouco depois de você pisar nelas.
- Estrelas na tela final: 1 por terminar, 1 por coletar 80% dos cristais, 1 por pegar os 3 núcleos.
- O melhor tempo fica salvo no navegador.

## Estrutura

| Arquivo | Conteúdo |
|---|---|
| `js/config.js` | Física e câmera (ajuste a sensação do pulo aqui) |
| `js/util.js` | Funções auxiliares |
| `js/input.js` | Teclado, mouse e toque |
| `js/audio.js` | Efeitos e música sintetizados (Web Audio) |
| `js/particles.js` | Partículas |
| `js/level.js` | Mapa da fase (edite `build()` para mudar o percurso) |
| `js/art.js` | Desenho do robô, terreno, perigos, itens e cenário |
| `js/background.js` | Fundo com parallax (Saturno, luas, mesas, estrelas) |
| `js/player.js` | Física e animação do robô |
| `js/world.js` | Estado da fase, colisões com perigos, coleta, checkpoints, câmera |
| `js/ui.js` | HUD, tela inicial, pausa, tela de conclusão |
| `js/game.js` | Loop principal e estados do jogo |

Para depurar, o console do navegador tem `SE.debug.world` (estado da fase) e `SE.debug.state` (tela atual).
