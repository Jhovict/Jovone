Preparação dos modelos (Node 18+, executar dentro desta pasta):
  npm install @gltf-transform/core@4.1.1 @gltf-transform/extensions@4.1.1 @gltf-transform/functions@4.1.1 meshoptimizer@0.22.0
  node decode.mjs <tripo_pbr_model...meshopt.glb> kart_src.glb
  node decode.mjs <tripo_mesh_seg...meshopt.glb> parts_src.glb
  node split.mjs kart_src.glb parts_src.glb
Gera ../models/kart.glb (corpo + 4 rodas, mesmos vértices) e ../models/driver.glb (piloto).

Pistas (Python 3 com numpy, scipy, scikit-image e pillow; executar dentro desta pasta):
  python extract.py raw.json ../../8*.jpg     (linha central de cada imagem de traçado)
  python sheet.py conferencia.png             (opcional: desenha as linhas extraídas sobre as imagens)
  python build.py ../tracks                   (escala, relevo, pontes, barreiras e taludes -> tracks/*.json)
  python pits.py ../tracks                    (lado e trecho do pit lane com espaço livre -> chave "pit"; rodar depois do build.py)
  python reshape.py ../tracks                 (curvas com raio < 9 m viram curvas suaves direto nos tracks/*.json; rodar pits.py depois)
Kart das 8 pinturas (coleção de .glb com a mesma geometria; usado pelo jogo em models/kart2/):
  node bake_kart2.mjs <pinturas/volt.glb> ../models/kart2     (malha simplificada: completa ~120 mil e leve ~37 mil triângulos)
  python bake_kart2.py <pasta das pinturas> ../models/kart2   (texturas JPG 1024 px e materiais das 27 peças -> liveries.json)
Cada equipe de scripts/game.gd aponta para uma pintura na chave "livery".

Modelo antigo (não usado mais pelo jogo). Volante, pneus e braços (depois de importar os modelos no Godot):
  Godot --headless --path .. -s tools/bake_kart.gd
Gera models/baked/: corpo do kart sem o volante, volante separado, textura dos pneus sem a luz
"pintada" (que girava junto com a roda) e o tronco do piloto com ossos de ombro e cotovelo.
tools/preview_rig.gd renderiza o kart com o volante em três posições para conferência.

Teste de entrada (controle e toque), com janela:
  Godot --path .. -s tools/ui_test.gd -- <pasta para capturas>

Versão leve (celular e navegador), depois do bake_kart.gd:
  Godot --headless --path .. -s tools/bake_lite.gd
Exportação (perfis em export_presets.cfg; os modelos completos ficam fora do APK e da web):
  Godot --headless --path .. --export-debug "Android" ../build/ApexKartGP.apk
  Godot --headless --path .. --export-release "Web" ../build/web/index.html

Imagens de destaque dos menus (kart com rastro de movimento em tom azul), com janela:
  Godot --path .. -s tools/make_heroes.gd        -> ui/hero_top.png, hero_side.png, hero_front.png
Capturas das telas de menu para conferência:
  Godot --path .. -s tools/menu_shots.gd -- <pasta>

Conferência do traçado (rodar depois do build.py):
  python wiggle.py               (conta inversões curtas de curva = zigue-zague; esperado < 10 por pista)
  python sheet_final.py out.png  (desenha a linha final do jogo por cima de cada imagem)
O traçado é limpo em três passos: as pontas da linha nas falhas de setor são aparadas, o contorno é
simplificado (Ramer–Douglas–Peucker, para retas ficarem retas) e cada vértice vira um arco tangente
(cantos arredondados). Curvas mais fechadas que 5,5 m de raio são abertas só em volta da própria curva.

Sons (Python 3 com numpy, scipy, soundfile e librosa; executar dentro desta pasta):
  python make_sounds.py          (prévias do Freesound em src/ -> ../sounds/*.wav; créditos em sounds/CREDITOS.txt)
  python make_weather_sounds.py  (chuva e trovões -> ../sounds/rain.wav, thunder_*.wav)
  python make_grains.py          (ciclos de explosão das gravações do motor -> ../sounds/engine_grains.json)
Conferência do áudio do jogo (grava 30 s de corrida com som e mede níveis e saturação):
  Godot --path .. --write-movie cap.avi --fixed-fps 30 --quit-after 900 -- --autotest=1 --laps=1
  python avi_audio.py cap.avi cap.wav
