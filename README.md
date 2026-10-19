# Jovone Games

A página inicial (`index.html`) é o launcher: lista os jogos em cartões.

## Estrutura

```
index.html          ← launcher
turbo-br316/        ← cada jogo em sua pasta, com index.html próprio
  index.html
```

## Como adicionar um jogo

1. Crie uma pasta (ex.: `meu-fps/`) com um `index.html` — o jogo, de preferência em arquivo único.
2. No `index.html` da raiz, adicione um item ao array `GAMES`:

```js
{ id:'meu-fps', title:'Meu FPS', tag:'FPS', desc:'Descrição curta.', cover:'<svg>…</svg>' /* ou URL de imagem */ }
```

3. No jogo, coloque um link de volta: `<a href="../">‹ Jogos</a>`.

Observação: o `localStorage` é compartilhado por todos os jogos do mesmo site; use um prefixo próprio nas chaves (o Turbo BR-316 usa `br316`).
