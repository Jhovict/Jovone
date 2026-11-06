# Apex Kart GP — atualização de modelos e animações

Projeto Godot 4.7.2 atualizado a partir de `Downloads/Pistas/apex_gp` em 04/11/2026.

## Alterações

- Piloto com sete ossos e braços animados por cinemática inversa. As duas luvas seguem a posição e a rotação do volante; o tronco permanece conectado aos ombros.
- Inclinação discreta do tronco e capacete nas curvas, reação à aceleração/frenagem e respiração sutil no grid.
- Esterço visual suavizado e geometria de direção Ackermann: a roda interna vira mais que a externa.
- Pneus com perfil arredondado, aros com seis raios e marcação de composto que muda entre macio, duro e chuva.
- Casco do capacete reconstruído com superfície suave. A escolha de cor da carreira preserva a viseira escura.
- Oito pinturas mantidas, com filtragem anisotrópica e verniz nas carenagens. Patrocínio do macacão legível também de costas.
- Qualidade Automático usa malhas leves nos adversários e mantém o modelo detalhado do jogador. Alta e Leve continuam disponíveis.
- Suavização exponencial e vibração determinística nas câmeras.
- Motor granular e vento/zebra configurados como streams de áudio, eliminando o aviso de amostra incompatível na web.
- Imagens dos menus renderizadas novamente com os modelos atualizados.

## Abrir

Importe `project.godot` no Godot 4.7.2 e pressione F5. W/S aceleram/freiam, A/D esterçam, C troca a câmera e Esc pausa.
As pinturas são compartilhadas por uma única geometria em `models/kart2`; os scripts constroem os detalhes e o rig no carregamento.
O importador recria `.godot` automaticamente. Essa pasta de cache não acompanha o projeto.

## Testes

- `Godot --headless --path . -s tools/visual_test.gd`: 288 verificações nas oito pinturas e nas duas qualidades; UVs, pesos, alcance dos braços, esterço e personalização do capacete.
- `Godot --headless --path . -- --flowtest`: navegação e progressão de carreira.
- `Godot --headless --path . -- --autotest=0 --speed=6 --laps=1 --pit=0`: corrida concluída com 16 karts.
- Renderização nativa das posições de volante e da câmera do piloto; carregamento da corrida exportada em WebGL 2 pelo Microsoft Edge.
- Prévia animada: `Godot --path . --rendering-method gl_compatibility -s tools/visual_preview.gd -- <pasta>`.

Os pesos recuperados da ArrayMesh usam quantização UNORM16; o teste aceita erro de soma até 0,0001 (medido ~0,000031).
As validações cobrem desktop e carregamento web; não houve teste em aparelho Android nem geração de APK nesta atualização.
As superfícies de carenagem, motor e roupa ainda derivam da malha recebida: não houve retopologia manual completa.

## Exportação web

O pacote web usa o motor 4.7.2 já presente no repositório e um novo `index.pck`, gerado com `--export-pack Web`.
Os tamanhos no `index.html` foram atualizados. Sirva a pasta por HTTP; abrir `index.html` por file:// não executa WebAssembly corretamente.
Os templates de exportação e o SDK Android não estão incluídos.

## Referências técnicas

Rig baseado em Skeleton3D/Skin da Godot: https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html
Áudio procedural como stream: https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html
Fontes e sons mantêm seus créditos em `fonts/OFL.txt` e `sounds/CREDITOS.txt`.


## Revisão do volante

Aro reconstruído com textura procedural de borracha perfurada, faixa amarela, três raios em carbono e seis parafusos metálicos. Pivô e eixo preservados para o rig das mãos. Verificado em Vulkan e OpenGL; 288 verificações do rig passaram novamente.


## Troféus por pista — carreira

16 esculturas 3D, cada uma com o traçado real do circuito e placa com nome. Ouro para P1, prata para P2 e bronze para P3; 48 variantes. Conquistas repetidas aumentam o contador da respectiva medalha. DNF e posições fora do pódio não recebem troféus. Uma mesma etapa não é premiada duas vezes.

A entrega aparece antes dos resultados. A coleção está em Escritório → Sala de troféus, com navegação entre as 16 pistas, seleção de medalha e visual bloqueado para as ainda não conquistadas. A carreira concluída também dá acesso à coleção.

As conquistas acompanham o salvamento manual da carreira e sobrevivem às mudanças de temporada/equipe. Saves antigos abrem normalmente com coleção vazia; não são inventados troféus retroativos. O save real do usuário não foi alterado pela instalação.

O calendário agora distribui 16 pistas pelas quatro primeiras temporadas, com retorno às primeiras pistas na quinta. Etapas já registradas em saves antigos mantêm seu circuito original.

Validação: 110 verificações de premiação, duplicatas, contadores, calendário, persistência e migração; fluxo da carreira incluindo pódio e coleção validado em desktop e WebGL sem erros de script. Prévia renderizada das 16 esculturas incluída no pacote.


## Capacetes de corrida
Casco remodelado com queixeira, abertura real, viseira independente, borrachas, entradas de ar e fixações laterais. 18 pinturas (seis clássicas, Brasil, Argentina, Itália, França, Alemanha, Japão, Reino Unido, dois tribais, Aurora, Apex Neon e Heritage), quatro viseiras e três acabamentos. Equipes usam oito pinturas coordenadas.
Personalização: Carreira → Escritório → Personalizar capacete. Aplicar confirma as opções; Cancelar descarta. Salve a carreira para manter a escolha ao fechar o jogo. Saves antigos recebem valores padrão para viseira/acabamento sem perder o progresso.
Validação: 288 verificações de rig/animação, 18 texturas e geometria full/lite, persistência/migração e aplicar/cancelar, fluxo desktop e web. APK e publicação GitHub não atualizados.


## Atualização: som, disputas, pódio, garagem e circuitos

Motor: transições de volume suavizadas, corpo grave, corte e ataque de troca de marcha, estalos moderados ao aliviar e variação individual/suavização dos motores 3D dos adversários. A câmera não foi modificada.
IA: compromisso com o lado da ultrapassagem, busca de espaço livre, distância de segurança, espaço lado a lado, defesa antecipada com intervalo entre movimentos e erros pequenos e recuperáveis em trânsito livre. Sem alterações artificiais de potência.
Pódio: três pilotos animados levantam os troféus do circuito. O jogador usa seu capacete e as cores escolhidas. Aparece nas corridas rápidas, fim de semana e premiações da carreira.
Garagem: Escritório → Garagem e personalização. Pinturas do kart, macacão, luvas, capacete, viseira e acabamento, com rotação por arraste, zoom por roda do mouse e botões equivalentes para controle/toque. Aplicar confirma, Cancelar descarta; salve a carreira para manter as escolhas. A personalização não muda equipe nem desempenho.
Circuitos: arquibancadas com público instanciado, publicidade fictícia, identidade/monumento em cada uma das 16 pistas. Vegetação e prédios respeitam a área das novas estruturas. Placas de distância usam espaçamento real ao longo do traçado.

Validação: 288 verificações de rig; 110 de troféus; situações de ultrapassagem, bloqueio, defesa, segurança lado a lado e passagem pela linha de chegada; corrida com 16 karts no seco e na chuva; 48 áreas de estruturas verificadas nas 16 pistas; garagem (prévia, aplicar, cancelar e persistência); fluxo desktop e web. Gravação de motor sem amostras saturadas.

Projeto local e web atualizados. O APK e a publicação no GitHub continuam na versão anterior. Novos objetivos de carreira não foram adicionados.


## Sensação de velocidade completa
Câmera com resposta amortecida à aceleração, frenagem e força lateral: inclinação limitada, deslocamento sutil da cabeça, distância dinâmica na câmera externa e abertura progressiva do campo de visão. Vibração de zebras/escape cresce com a velocidade e entra/sai suavemente. Efeitos periféricos discretos, sem desfocar a pista.
Opções → Sensação de velocidade: Desligada, Suave ou Forte. Desligada agora remove de fato o FOV dinâmico e as vibrações adicionais. Câmera de TV permanece estável. O som aprimorado foi mantido. Física, IA e desempenho dos karts não foram alterados nesta etapa.
Testes: limites de movimento, aceleração, frenagem, desligamento completo, reinicialização sem tranco e consistência a 30/120 FPS; renderização de cockpit no desktop e corrida no navegador.


## APK Android 1.4
APK de lançamento ARM64 exportado e assinado. Nova instalação com identificador com.jhovict.apexkartgp.atualizado, preservando o aplicativo antigo porque sua chave não estava disponível. Assinatura v2/v3, conteúdo e alinhamento de 16 KB verificados. Sem teste em dispositivo físico. Incluído na pasta android do pacote.


## Versão 1.5 — corrida e apresentação
- Replay dos últimos 12 segundos da chegada em 0,75×, câmera elevada acompanhando o kart e botão para pular.
- Rivais agressivos, defensivos e consistentes, com diferentes escolhas de ataque, defesa e margem de segurança. Estilo mostrado na classificação de pilotos.
- Clima variável nas corridas inicialmente secas ou chuvosas: chuva, aderência e secagem progressivas, avisos e troca de pneus pela IA. Neve, tempestade e contrarrelógio mantêm o clima escolhido.
- Rádio com 15 falas sintetizadas em português, legendas, prioridades e redução do volume do motor durante a voz. Funciona offline.
- Fantasma da melhor volta válida no contrarrelógio, salvo por pista, clima e pintura do kart. Sem colisões; uma volta mais lenta ou inválida não substitui o recorde.
- Sujeira progressiva, marcas nos pneus, riscos e pequena deformação visual nas peças afetadas por danos.
- Vencedor levanta uma mão após a chegada, com velocidade reduzida, baixa rotação do kart e fora dos boxes.
Rádio, clima variável, fantasma e replay podem ser ativados/desativados em Opções.

Android: APK 1.5 (código 6), ARM64, Android 7.0+. Mantém o identificador com.jhovict.apexkartgp.atualizado e a nova chave de assinatura. Instala separado do APK original cuja chave não está disponível. A instalação nova tem progresso próprio; não é necessário remover o jogo antigo. Atualiza a versão 1.4 deste mesmo aplicativo.
Validação: testes de replay, clima, persistência de fantasma e gesto; corrida com 16 karts e troca de pneus; contrarrelógio de duas voltas; captura visual de chuva, replay, desgaste e fantasma; 288 verificações de rig e 110 de troféus; fluxo de carreira desktop/web e corrida web. Assinatura v2/v3 e alinhamento de 16 KB verificados. Sem teste em celular físico.


## Versão 1.6 — menus redesenhados
Identidade azul profundo, painéis sólidos, textos claros e foco ciano. Removidas as texturas e formas decorativas atrás das opções. Controles com fonte sem itálico, espaçamento consistente e colunas separadas para nome e valor. Opções agrupadas por assunto, tabelas com linhas alternadas e largura ajustada à tela, textos longos com quebra controlada. Tabelas abrem no início, mostrando os cabeçalhos. Pausa e configurações usam painel opaco com rolagem. Nova renderização do kart atual nas telas iniciais.
Validação: capturas em 1280×720 e 960×720, verificação de separação das colunas dos seletores, navegação da carreira, aplicação/cancelamento da garagem, persistência e menu de pausa. Fluxo web e corrida web verificados. APK 1.6 (código 7), mesma assinatura e pacote da versão 1.5; pode atualizar o aplicativo Apex Kart GP Atualizado. Sem teste em celular físico.
