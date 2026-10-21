# Jovone Games

A página inicial (`index.html`) é o launcher: lista os jogos em cartões.

## Estrutura

```
index.html          ← launcher
turbo-br316/        ← cada jogo em sua pasta, com index.html próprio
  index.html          corrida 3D pelas estradas brasileiras
pane-seca/
  index.html          sobrevivência 3D no sertão (feito a partir do motor do Turbo BR-316)
pong/
  index.html          Pong clássico em canvas 2D (contra a CPU ou dois jogadores)
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

Pong em canvas 2D, arquivo único, sem bibliotecas. Contra a CPU (fácil, médio ou difícil) ou dois jogadores no mesmo teclado (W/S e ↑/↓; no celular, arrastando o dedo). Partidas até 11 ou 21 pontos, visual retrô preto e branco ou neon. O ângulo da bola depende de onde ela bate na raquete e a velocidade sobe 5% a cada rebatida. Salva as opções e o placar contra a CPU no `localStorage` com o prefixo `pong`.

## Como adicionar um jogo

1. Crie uma pasta (ex.: `meu-fps/`) com um `index.html` — o jogo, de preferência em arquivo único.
2. No `index.html` da raiz, adicione um item ao array `GAMES`:

```js
{ id:'meu-fps', title:'Meu FPS', tag:'FPS', desc:'Descrição curta.', cover:'<svg>…</svg>' /* ou URL de imagem */ }
```

3. No jogo, coloque um link de volta: `<a href="../">‹ Jogos</a>`.

Observação: o `localStorage` é compartilhado por todos os jogos do mesmo site; use um prefixo próprio nas chaves (o Turbo BR-316 usa `br316`).
