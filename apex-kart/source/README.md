# Apex Kart GP

Jogo original de corrida de kart de câmbio (classe KZ) em Godot 4.7: visão do piloto, kartódromos 3D,
física veicular, 16 karts com IA, cronometragem e carreira. Equipes, pilotos e kartódromos são fictícios.
Cada equipe tem a sua pintura de kart, piloto e capacete (8 pinturas originais, com patrocinadores fictícios).

Abra a pasta no Godot (Importar → `project.godot`) e pressione F5.

## Controles padrão (remapeáveis em Opções → Controles do teclado)

| Ação | Teclado | Controle |
|---|---|---|
| Acelerar | W / ↑ | Gatilho direito |
| Frear (segure parado para empurrar o kart para trás) | S / ↓ | Gatilho esquerdo |
| Esterçar | A, D / ←, → | Analógico esquerdo |
| Subir / reduzir marcha | E / Q | RB / LB |
| Trocar câmera (piloto, perseguição, traseira baixa, TV) | C | Y |
| Olhar para trás | B | X |
| Reposicionar kart | R | Back |
| Chamar o box | F | D-pad ↑ |
| Pausar | Esc / P | Start |

Controle (joypad) funciona em todas as telas: D-pad/analógico navegam, A confirma, B volta, Start abre
o menu e pausa; os botões do controle também podem ser trocados em Opções → Controles.

Em Opções → "Controle usado" escolha Automático, Teclado, Controle (joypad) ou Toque na tela; no
Automático os botões na tela só aparecem em celular/tablet. Os botões aceitam vários dedos ao mesmo tempo. Em Opções → "Posição dos botões de toque" dá para arrastar cada botão
e mudar o tamanho. O botão Voltar do Android pausa a corrida ou volta uma tela.

## Som

Gravações reais do Freesound (CC0 e CC-BY 4.0, créditos em `sounds/CREDITOS.txt`). O motor do jogador é
granular: ciclos de explosão recortados das gravações de kart e 2 tempos (marcha lenta, médio, giro alto,
`tools/make_grains.py`) são disparados um a cada explosão do motor do jogo, então o ronco acompanha o RPM e o
acelerador na hora; sem acelerador em giro alto o motor falha e estala, e um filtro abafa ao tirar o pé; motores dos adversários em 3D com efeito Doppler e acelerando no grid; partida real de kart
ao montar o grid; bipe gravado nas luzes; pneu cantando conforme o escorregamento; batida; ambiente de
kartódromo ao fundo. Vento e zebra são sintetizados. Um limitador no volume geral evita saturação.

## Menus

Moldura própria (`scripts/menu_frame.gd`): faixas de fibra de carbono azul com friso cromado, painel claro
com setas grandes atrás do menu, item em foco marcado com »», valor dos seletores entre « », faixa
quadriculada com a dica do item em foco e os comandos no rodapé. Imagens de destaque renderizadas do
próprio kart (`ui/`), kart girando com o capacete escolhido na criação do piloto e tela de carregamento
com dicas. Fonte Chakra Petch (licença OFL, `fonts/OFL.txt`).

## Modelos 3D

- `models/kart.glb`: o kart texturizado enviado (malha, UVs e texturas PBR originais, 1,9 milhão de
  triângulos). Os vértices não foram alterados: as 4 rodas foram apenas separadas em nós próprios
  (com o pivô no centro de cada roda) para girarem e as dianteiras esterçarem. Escala uniforme 1,95
  (kart de ~1,9 m), sem compressão de malha e com texturas sem perda.
- `models/fan.glb`: o piloto simplificado que formava a torcida; hoje não é usado nem exportado.
- `models/driver.glb`: o piloto (pernas, tronco, capacete e luvas) retirado do modelo segmentado enviado,
  que não tem textura; o macacão usa a cor da equipe e o capacete a cor do piloto.
- `tools/`: scripts Node (glTF-Transform) usados para descomprimir o meshopt dos arquivos originais
  e separar rodas/piloto. O Godot não lê `EXT_meshopt_compression` diretamente.

## O que existe

- Física de kart: 175 kg com piloto, entre-eixos de 1,02 m, sem downforce, pneus com círculo de
  atrito, transferência de carga, motor 125 cc 2 tempos (curva de torque, limite 14.800 rpm),
  câmbio de 6 marchas, eixo traseiro rígido, patinagem e travamento, zebra, grama e barreira de pneus.
- Modo de pilotagem (Opções e menu de pausa): **Assistido** é o máximo de ajuda do jogo e também o
  padrão: controle de tração, ABS, estabilidade, frenagem leve (só freia quando o kart chega rápido
  demais na curva), câmbio automático e linha ideal. **Simulação** desliga tudo; mexer numa
  assistência isolada vira **Personalizado**.
- Assistências com efeito real: controle de tração, ABS, controle de estabilidade, assistência de
  frenagem, linha ideal (verde/amarelo/vermelho), câmbio manual/automático, sensibilidade, danos.
- 16 pistas geradas a partir das imagens de traçado da pasta (1,3 km a 2,5 km):
  relevo com subidas e descidas, ponte onde o traçado cruza a si mesmo, zebras modulares, brita nas
  saídas de curvas fechadas, barreira de pneus nas retas e Tecpro vermelha/branca nas curvas.
  As barreiras e os taludes são calculados ponto a ponto para nunca invadir outro trecho da pista.
  Nenhuma curva fica com raio muito abaixo de 9 m (grampos apertados foram abertos em U por tools/reshape.py).
- Cenário (sem arquibancadas, mais leve no celular): pórtico treliçado com
  luzes e painel de LED, placas de 150/100/50 m, prédio dos boxes, cinco espécies de árvore
  (pinheiro, folhosa, cipreste, palmeira, arbusto) conforme o tema, prédios na pista urbana.
- Clima (corrida rápida, fim de semana e contrarrelógio, com recordes separados): **Seco**; **Chuva**
  (aderência ~70 %); **Tempestade** (chuva forte inclinada pelo vento, céu escuro, neblina, raios com
  clarão e trovão que chega depois, aderência ~60 %); **Neve** (flocos caindo, grama, morros e copas
  brancos, aderência ~50 %). Fora do seco todos usam pneu de chuva e a IA anda mais devagar. Som de chuva
  e trovões gravados (Freesound, CC0).
- Corrida com largada de 5 luzes, voltas e setores, limites de pista com avisos e penalidade,
  colisões entre karts, danos e pontuação 10-8-6-5-4-3-2-1.
- Box, combustível e pneus (no estilo das corridas com reabastecimento): todas as pistas têm pit lane
  com rampa de entrada e de saída, muro divisório com amortecedor, limite de 50 km/h, vagas pintadas e
  um box por equipe com sigla e quatro mecânicos que vão até as rodas na parada. Em "Paradas no box"
  (corrida rápida, fim de semana e Opções) a regra **1 parada** ou **2 paradas** mede o tanque e a
  vida dos pneus pelo tamanho da corrida, então é preciso parar; **Sem estratégia** deixa como antes.
  - Combustível em voltas: pesa no kart (acelera e freia pior cheio) e, se acabar, o kart para e abandona.
  - Pneus: cada um gasta pela carga que leva (lado de fora da curva, dianteiros na freada, traseiros na
    tração, muito mais derrapando ou travando) e a aderência despenca depois de 70 %; pneus novos saem
    frios. Compostos Macio (mais aderência, gasta 50 % mais), Duro e Chuva (só rende no molhado).
  - Chame o box (F, D-pad ↑, botão BOX ou "Estratégia de box" na pausa) e entre no pit lane: o kart
    anda sozinho até o box, a parada leva o tempo de troca de pneus, reabastecimento e reparo
    (escolhidos na pausa ou automáticos) e o kart volta sozinho até a saída.
  - A IA calcula quando parar (combustível que não chega à próxima volta ou pneus que não chegam ao
    fim), cada piloto com a sua antecipação; cada box tem uma vaga por piloto (com 4 mecânicos cada), então o grid cheio de 16 karts nunca forma fila.
  - HUD: os quatro pneus vistos de cima (verde → amarelo → vermelho, azul enquanto frios), composto,
    combustível em voltas, avisos do box e "BOX" na torre de posições.
- Modos: Carreira, Corrida rápida, Fim de semana de GP, Contrarrelógio (recordes salvos), Opções.
- Carreira: criação de piloto → escolha entre 3 equipes iniciantes → teste de recrutamento →
  piloto de testes → segundo piloto → primeiro piloto, com e-mails, notícias, tabelas, calendário,
  evolução do kart, propostas de transferência e até 5 temporadas. Salvamento explícito.

## Aproximações deste jogo

- O volante foi separado do kart (mesmos vértices) e gira até 80° para cada lado; as luvas vão junto e
  os braços do piloto seguem com ombro e cotovelo (cinemática inversa). O tronco do piloto é a única
  malha deformada, e só nos braços.
- A textura original dos pneus tinha luz e sombra pintadas, que giravam com a roda; essa variação em
  volta do eixo foi removida (o desenho e as letras do pneu ficaram).
- Karts reais não têm ré: aqui, segurar o freio parado empurra o kart para trás (assistência).
- Metas de tempo e tempos de classificação da IA vêm do perfil de velocidade calculado da pista.
- Classificação é uma sessão única de 3 voltas e só o jogador vai à pista.
- Sem área de boxes funcional, sem combustível e sem troca de pneus. Temporada de 4 etapas.

## Testes automáticos (linha de comando)

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest=0 --speed=4 --laps=3
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --flowtest
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest=6 --laps=5 --pit=2 --pitlog
```
`--pit=0|1|2` escolhe a regra de paradas e `--pitlog` mostra entrada, parada e saída do box do kart
testado; `--pitshot=arquivo.png` (com janela) fotografa a parada.

## Celular e navegador

O APK (Android, arm64) e a versão web usam o renderizador de compatibilidade e uma versão reduzida
dos modelos (`models/lite/`: kart com ~100 mil triângulos, texturas de 2048/1024 px). No PC, em Opções →
"Qualidade dos modelos", dá para usar a versão leve também.
