// Splits the textured kart into body + 4 wheel meshes (no vertex moved, only regrouped
// and expressed relative to each wheel centre) and extracts the driver from the segmented model.
import { NodeIO } from '@gltf-transform/core';
import { prune } from '@gltf-transform/functions';
const io = new NodeIO();
const doc = await io.read(process.argv[2] ?? 'kart_src.glb');
const root = doc.getRoot();
const prim = root.listMeshes()[0].listPrimitives()[0];
const P = prim.getAttribute('POSITION').getArray();
const N = prim.getAttribute('NORMAL').getArray();
const T = prim.getAttribute('TEXCOORD_0').getArray();
const I = prim.getIndices().getArray();
const n = P.length / 3;

function fit(xl, xh, zguess, yguess, R) {
  // centre (y,z) that puts the most tyre vertices on a circle of radius R
  let best = [0, yguess, zguess];
  for (let dz = -0.012; dz <= 0.012; dz += 0.0005) for (let dy = -0.006; dy <= 0.006; dy += 0.0005) {
    const yc = yguess + dy, zc = zguess + dz; let c = 0;
    for (let i = 0; i < n; i++) { const x = Math.abs(P[i*3]); if (x < xl || x > xh) continue;
      const rr = Math.hypot(P[i*3+1] - yc, P[i*3+2] - zc); if (Math.abs(rr - R) < 0.0025) c++; }
    if (c > best[0]) best = [c, yc, zc];
  }
  return best;
}
const F = fit(0.2207, 0.2937, -0.1855, -0.0949, 0.0760);
const Rr = fit(0.2286, 0.3216, 0.329, -0.0996, 0.0721);
console.log('front fit', F, 'rear fit', Rr);
const wheels = [
  ['wheel_fl', -1, 0.2207, 0.2937, F[1], F[2], 0.0760],
  ['wheel_fr',  1, 0.2207, 0.2937, F[1], F[2], 0.0760],
  ['wheel_rl', -1, 0.2286, 0.3216, Rr[1], Rr[2], 0.0721],
  ['wheel_rr',  1, 0.2286, 0.3216, Rr[1], Rr[2], 0.0721],
];
const owner = new Int8Array(n).fill(-1);
for (let i = 0; i < n; i++) {
  const x = P[i*3], y = P[i*3+1], z = P[i*3+2];
  wheels.forEach((w, k) => {
    const ax = x * w[1];
    if (ax >= w[2] - 0.002 && ax <= w[3] + 0.004 && Math.hypot(y - w[4], z - w[5]) <= w[6] + 0.004) owner[i] = k;
  });
}
const groups = [[], [], [], [], []];
for (let t = 0; t < I.length; t += 3) {
  const a = owner[I[t]], b = owner[I[t+1]], c = owner[I[t+2]];
  groups[(a >= 0 && a === b && a === c) ? a + 1 : 0].push(I[t], I[t+1], I[t+2]);
}
const mat = prim.getMaterial();
const buffer = root.listBuffers()[0];
const scene = root.listScenes()[0];
for (const nd of root.listNodes()) nd.dispose();
for (const me of root.listMeshes()) me.dispose();
const names = ['body', ...wheels.map(w => w[0])];
groups.forEach((tri, g) => {
  const remap = new Map(); const pos = [], nor = [], uv = [], idx = [];
  const off = g === 0 ? [0, 0, 0] : [wheels[g-1][1] * (wheels[g-1][2] + wheels[g-1][3]) / 2, wheels[g-1][4], wheels[g-1][5]];
  for (const v of tri) {
    let m = remap.get(v);
    if (m === undefined) { m = remap.size; remap.set(v, m);
      pos.push(P[v*3] - off[0], P[v*3+1] - off[1], P[v*3+2] - off[2]); nor.push(N[v*3], N[v*3+1], N[v*3+2]); uv.push(T[v*2], T[v*2+1]); }
    idx.push(m);
  }
  const acc = (arr, type, Ctor) => doc.createAccessor().setType(type).setArray(new Ctor(arr)).setBuffer(buffer);
  const pr = doc.createPrimitive().setMaterial(mat)
    .setAttribute('POSITION', acc(pos, 'VEC3', Float32Array)).setAttribute('NORMAL', acc(nor, 'VEC3', Float32Array))
    .setAttribute('TEXCOORD_0', acc(uv, 'VEC2', Float32Array)).setIndices(acc(idx, 'SCALAR', Uint32Array));
  const node = doc.createNode(names[g]).setMesh(doc.createMesh(names[g]).addPrimitive(pr)).setTranslation(off);
  scene.addChild(node);
  console.log(names[g], 'tris', tri.length / 3, 'centre', off.map(v => v.toFixed(4)).join(','));
});
await doc.transform(prune());
await io.write('../models/kart.glb', doc);

const d2 = await io.read(process.argv[3] ?? 'parts_src.glb');
const keep = { tripo_part_2: 'legs', tripo_part_4: 'torso', tripo_part_5: 'helmet', tripo_part_16: 'glove_l', tripo_part_17: 'glove_r' };
for (const nd of d2.getRoot().listNodes()) { if (keep[nd.getName()]) nd.setName(keep[nd.getName()]); else nd.dispose(); }
await d2.transform(prune());
await io.write('../models/driver.glb', d2);
console.log('done');
