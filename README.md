# Jovone Games

A página inicial (`index.html`) é o launcher, no estilo da tela inicial de console: uma fileira de capas, o fundo muda para a capa do jogo em foco e o botão Jogar abre o jogo. Navega por toque, mouse, teclado (← → e Enter) ou controle (direcional/analógico e A). Lembra o último jogo aberto (`launcherUltimo` no `localStorage`).

## Estrutura

```
index.html          ← launcher
turbo-br316/        ← cada jogo em sua pasta, com index.html próprio
  index.html          corrida 3D pelas estradas brasileiras
pane-seca/
  index.html          sobrevivência 3D no sertão (feito a partir do motor do Turbo BR-316)
pong/
  index.html          Pong clássico em canvas 2D (contra a CPU ou dois jogadores)
zona-quente/
  index.html          tiro tático em equipe (estilo CS / Critical Ops) contra bots
```

## Pane Seca

O carro do Turbo BR-316 ficou sem gasolina no meio da BR-316. A pé, em terceira pessoa (ou primeira, tecla `V`), o jogador:

- controla vida, fome, sede e fôlego; o sol do meio-dia seca mais rápido e a chuva alivia;
- corta carnaúbas e árvores, quebra pedras, colhe umbu e fruta de mandacaru, revira ferros-velhos, vasculha casas abandonadas, bebe no açude e caça bodes;
- fabrica fogueira, lança, facão, ataduras e abrigo de palha, e assa carne no fogo;
- enfrenta matilhas de cães do mato à noite (maiores a cada noite), que não entram no círculo da fogueira, e dorme no carro, numa casa ou no abrigo para pular até o amanhecer;
- vence ao instalar 3 peças de motor e 4 galões (20 L) no carro e dar a partida.

Reaproveita do Turbo BR-316: renderizador e iluminação, ciclo de horário (agora contínuo), chuva, cenário do sertão (carnaúba, mandacaru, moitas, casinhas, bodes, urubus), pedestre como personagem, áudio sintetizado e trilha, toque, gamepad e o visual da interface. Salva sozinho no `localStorage` com o prefixo `pseca`.

## Pong

Pong em canvas 2D, arquivo único, sem bibliotecas. Contra a CPU (fácil, médio ou difícil) ou dois jogadores locais. Controles: teclado (W/S e ↑/↓, P pausa, Esc menu), controle/joypad pela Gamepad API (analógico ou direcional, Start pausa, Select menu, A confirma, navega no menu e vibra nas rebatidas; o 1º controle é a raquete esquerda e o 2º a direita) e celular (arrastar o dedo em qualquer parte da tela, cada jogador na sua metade; botões na tela para pausar, tela cheia e menu). Partidas até 11 ou 21 pontos, visual retrô preto e branco ou neon. O ângulo da bola depende de onde ela bate na raquete e a velocidade sobe 5% a cada rebatida. Salva as opções e o placar contra a CPU no `localStorage` com o prefixo `pong`.

## Zona Quente

Tiro tático em primeira pessoa, Força Tática contra Insurgentes, no mapa original **Mercado** (dois pontos de bomba, meio, passarela, corredor longo e túneis cobertos).

- **Desarme:** os Insurgentes plantam a bomba no ponto A ou B (3,2 s), a Força Tática desarma (10 s, ou 5 s com kit); quem vencer 7 rodadas leva, com troca de lado depois da 6ª.
- **Economia como no CS:** dinheiro por vitória, derrota (bônus crescente), abates por tipo de arma e plantio; loja na base nos primeiros 20 s; sobreviventes mantêm as armas; armas caídas podem ser pegas.
- **Arsenal:** pistolas Falcão e Tupã .50, submetralhadora Vespa, escopeta Trovão, fuzis Carcará e Jaguar, fuzil de precisão Gavião (luneta em 2 níveis), faca (golpe pelas costas), granada, atordoante e fumaça, colete, capacete e kit.
- **Tiro:** cabeça ×4, tronco, barriga ×1,25 e pernas ×0,75; colete e capacete absorvem conforme a penetração da arma; dispersão por movimento, pulo e agachamento; recuo com padrão; queda de dano com a distância.
- **Bots** em 4 níveis: visão com campo e linha de visada, tempo de reação, erro de mira que diminui, rajadas controladas, contra-strafe, audição de tiros e passos, rotas por A* no grid, execução por corredores, lurker, rotação e retomada em grupo da defesa, compra por equipe (pistola, economia, forçar, completa), uso de granadas.
- **Mata-mata em equipe:** renascimento, compras grátis na base, 50 abates.
- Radar, placar, feed de abates, indicador de dano, espectador em terceira pessoa ao morrer.
- **Movimentação como no CS:GO:** 6,3 m/s com a faca e cada arma com seu peso (pistola 96%, fuzis 86–90%, Gavião 80% e 62% com luneta); arranca em 0,2 s, para em 0,1 s e o contra-strafe devolve a precisão total na hora; embalo conservado no ar e pulo que alcança as caixas.
- **Controles:** PC (WASD, mouse com captura do ponteiro), celular na horizontal (joystick, arrastar para mirar, dois botões de fogo que também giram a câmera, mira, pulo, agachar, recarga, troca de arma, granada, usar/plantar/desarmar, loja) e controle Xbox/PlayStation.

Salva opções e estatísticas no `localStorage` com o prefixo `zq`.

## Como adicionar um jogo

1. Crie uma pasta (ex.: `meu-fps/`) com um `index.html` — o jogo, de preferência em arquivo único.
2. No `index.html` da raiz, adicione um item ao array `GAMES`:

```js
{ id:'meu-fps', title:'Meu FPS', tag:'FPS', desc:'Descrição curta.', cover:'<svg>…</svg>' /* ou URL de imagem */ }
```

3. No jogo, coloque um link de volta: `<a href="../">‹ Jogos</a>`.

Observação: o `localStorage` é compartilhado por todos os jogos do mesmo site; use um prefixo próprio nas chaves (o Turbo BR-316 usa `br316`).
