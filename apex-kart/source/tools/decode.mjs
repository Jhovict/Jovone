import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize } from '@gltf-transform/functions';
import { MeshoptDecoder } from 'meshoptimizer';
await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
const [inp, out] = process.argv.slice(2);
const doc = await io.read(inp);
await doc.transform(dequantize());
for (const e of doc.getRoot().listExtensionsUsed()) {
  if (['EXT_meshopt_compression', 'KHR_mesh_quantization'].includes(e.extensionName)) e.dispose();
}
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) {
  const pos = p.getAttribute('POSITION'); const idx = p.getIndices();
  console.log('prim verts', pos.getCount(), 'tris', idx ? idx.getCount()/3 : 0, 'attrs', p.listSemantics().join(','), 'min', pos.getMin([]), 'max', pos.getMax([]));
}
await io.write(out, doc);
console.log('ok', out);
