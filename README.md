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
pulse-kart/
  index.html          corrida de kart 3D no circuito Apex Loop
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

## Pulse Kart

Corrida de kart 125cc em terceira pessoa (ou do capacete, tecla `V`) em três circuitos originais: **Apex Loop** (1,3 km, reta dos boxes, esses, grampo e curvão), **Orla** (à beira-mar, com areia, coqueiros e mar) e **Centro** (de rua, entre prédios e muros de concreto). A pista é escolhida no menu (a página recarrega para montá-la).

- **Modo com itens** (opcional): caixas na pista dão turbo, óleo, míssil teleguiado ou escudo, com sorteio que favorece quem está atrás; os bots também usam.

- **Kart Pulse:** chassi tubular cromado, para-choque e carenagem frontal com placa de número, sideboxes, banco envolvente, tanque, volante que gira, motor dois tempos com aletas, vela, carburador e caixa de ar, escapamento com câmara de expansão, corrente e coroa, eixo traseiro com freio a disco e pneus traseiros largos. Oito pinturas.
- **Piloto:** macacão preto com faixas na cor do kart, luvas, botas e capacete com faixas e viseira escura. Ele se inclina e olha para dentro das curvas.
- **Circuito:** asfalto, faixas brancas, zebras vermelhas e brancas nas curvas, caixas de brita e barreiras de pneus por fora das curvas fortes, alambrado com postes, placas de patrocínio, três pórticos (o da largada com as cinco luzes), muro dos boxes, prédio do paddock com boxes numerados, arquibancadas com torcida, postos de fiscais com bandeira, árvores e morros.
- **Corrida:** 3, 5 ou 8 voltas contra 7 pilotos em três níveis (Amador, Piloto, Profissional), largada com as cinco luzes vermelhas, posição ao vivo, torre de tempos, minimapa e resultado com pódio. Os bots seguem o traçado ideal, freiam antes das curvas, desviam e disputam posição.
- **Contra o relógio:** voltas livres sozinho; o kart fantasma repete a melhor volta (salva no navegador).
- **Pilotagem:** aderência limitada pela velocidade, drift (segure na curva e solte: turbo azul ou laranja conforme o tempo), vácuo atrás de outro kart, grama e brita freiam, batidas no alambrado e entre karts.
- **Controles:** teclado (setas/WASD, Espaço drift, V câmera, P pausa, M som), controle (RT/A acelera, LT/B freia, analógico, RB/X drift, Y câmera, Start pausa) e celular na horizontal (botões de direção, acelerador, freio e drift).

Salva opções, melhor volta e fantasma (por pista) e estatísticas no `localStorage` com o prefixo `pkart`.

## Como adicionar um jogo

1. Crie uma pasta (ex.: `meu-fps/`) com um `index.html` — o jogo, de preferência em arquivo único.
2. No `index.html` da raiz, adicione um item ao array `GAMES`:

```js
{ id:'meu-fps', title:'Meu FPS', tag:'FPS', desc:'Descrição curta.', cover:'<svg>…</svg>' /* ou URL de imagem */ }
```

3. No jogo, coloque um link de volta: `<a href="../">‹ Jogos</a>`.

Observação: o `localStorage` é compartilhado por todos os jogos do mesmo site; use um prefixo próprio nas chaves (o Turbo BR-316 usa `br316`).
