// Torcedor leve: o piloto do modelo segmentado (sentado), unido e simplificado para multidões.
import { NodeIO } from '@gltf-transform/core';
import { flatten, join, simplify, weld, prune, dedup } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
await MeshoptSimplifier.ready;
const io = new NodeIO();
const doc = await io.read(process.argv[2]);
const scene = doc.getRoot().listScenes()[0];
const mat = doc.createMaterial('fan');
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) p.setMaterial(mat);
await doc.transform(flatten(), join({ keepNamed: false }), weld(), simplify({ simplifier: MeshoptSimplifier, ratio: 0.004, error: 0.02 }), dedup(), prune());
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) console.log('tris', p.getIndices().getCount() / 3);
await io.write(process.argv[3], doc);
