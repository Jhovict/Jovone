// Kart das 8 pinturas: as oito versões têm a mesma geometria (27 peças), então a malha é simplificada uma
// vez (versão completa para PC e leve para celular/navegador) e cada pintura vira só materiais + texturas
// (feito por bake_kart2.py). Uso (mesmas dependências Node de decode.mjs):
//   node bake_kart2.mjs <pinturas/volt.glb> ../models/kart2
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { weld, simplify, prune, dedup } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';

await MeshoptSimplifier.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const [inp, outDir] = process.argv.slice(2);

for (const [name, ratio, error] of [['kart2_full', 0.06, 0.003], ['kart2_lite', 0.018, 0.008]]) {
  const doc = await io.read(inp);
  const root = doc.getRoot();
  // sem texturas e materiais no arquivo da malha: o jogo aplica os da pintura de cada equipe
  for (const t of root.listTextures()) t.dispose();
  for (const m of root.listMaterials()) m.dispose();
  await doc.transform(weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error, lockBorder: false }), dedup(), prune());
  let tris = 0;
  for (const m of root.listMeshes()) for (const p of m.listPrimitives()) tris += p.getIndices().getCount() / 3;
  await io.write(`${outDir}/${name}.glb`, doc);
  console.log(name, 'triângulos', tris);
}
