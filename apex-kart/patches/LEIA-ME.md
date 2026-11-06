# Patch: rolar menus arrastando o dedo

Antes, as listas grandes (garagem, capacetes, troféus e outras) só rolavam pela
barrinha fina do canto. Com este patch tu bota o dedo em qualquer opção,
arrasta pra cima ou pra baixo e a lista acompanha. Se soltar rápido, ela
continua deslizando, igual a lista de apps do celular.

- Toque rápido sem arrastar continua clicando no botão normalmente.
- Arrastar **não** clica no botão onde o dedo começou.
- Tocar numa lista que ainda está deslizando só faz ela parar.
- Vale para **todos** os `ScrollContainer` do jogo, inclusive os que forem criados depois.

## Como aplicar (no PC, no projeto Godot)

1. Copia `touch_scroll.gd` pra pasta `scripts/` do projeto.
2. Abre **Projeto → Configurações do Projeto → Globais (Autoload)**.
3. Em *Caminho*, escolhe `res://scripts/touch_scroll.gd`. Em *Nome*, põe `TouchScroll`. Clica em **Adicionar**.
4. Confere se **Input Devices → Pointing → Emulate Mouse From Touch** está ligado (vem ligado por padrão).
5. Exporta o APK e o build web de novo.

Pra testar no PC com o mouse: clica e arrasta numa lista. Funciona do mesmo jeito.

## Ajustes (no topo do script)

| Constante | O que faz |
|---|---|
| `DRAG_THRESHOLD` | Quanto o dedo anda antes de virar arrasto (padrão 14 px). Aumenta se estiver clicando sem querer, diminui se estiver demorando pra rolar. |
| `FRICTION` | Quanto maior, mais rápido a inércia para. |
| `MAX_FLING_SPEED` | Velocidade máxima do "peteleco". |

Opcional: se quiser esconder a barrinha, põe `vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER`
nos ScrollContainer. A rolagem por arrasto continua funcionando.
