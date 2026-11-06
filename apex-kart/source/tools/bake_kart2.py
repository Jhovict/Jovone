"""Pinturas do kart: lê os oito .glb da coleção (mesma geometria, materiais e texturas diferentes) e grava,
para cada pintura, as texturas em JPG 1024 px e os materiais das 27 peças em models/kart2/liveries.json.
A malha simplificada vem de bake_kart2.mjs. Uso: python bake_kart2.py <pasta dos .glb> ../models/kart2"""
import sys, os, io, json, struct, glob
from PIL import Image

TEX = 1024


def read_glb(path):
    b = open(path, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    off = 20 + n
    bn = struct.unpack('<I', b[off:off + 4])[0]
    return j, b[off + 8:off + 8 + bn]


def srgb(c):
    # baseColorFactor é linear; o jogo usa cores sRGB (Color) no albedo
    return [round((x * 12.92) if x <= 0.0031308 else (1.055 * x ** (1 / 2.4) - 0.055), 4) for x in c[:3]]


if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    data = {}
    for path in sorted(glob.glob(os.path.join(src, '*.glb'))):
        key = os.path.splitext(os.path.basename(path))[0]
        j, bin_ = read_glb(path)
        os.makedirs(os.path.join(out, key), exist_ok=True)
        tex_names = []
        for t in j.get('textures', []):
            im = j['images'][t['source']]
            bv = j['bufferViews'][im['bufferView']]
            raw = bin_[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
            img = Image.open(io.BytesIO(raw)).convert('RGB').resize((TEX, TEX), Image.LANCZOS)
            img.save(os.path.join(out, key, im['name'] + '.jpg'), quality=88)
            tex_names.append(im['name'])
        # material de cada peça, pela ordem dos nós tripo_part_N
        parts = {}
        for node in j['nodes']:
            mesh = j['meshes'][node['mesh']]
            mat = j['materials'][mesh['primitives'][0]['material']]
            pbr = mat.get('pbrMetallicRoughness', {})
            p = {'c': srgb(pbr.get('baseColorFactor', [1, 1, 1, 1])),
                 'm': pbr.get('metallicFactor', 1.0), 'r': pbr.get('roughnessFactor', 1.0)}
            if 'baseColorTexture' in pbr:
                p['tex'] = tex_names[pbr['baseColorTexture']['index']]
            parts[node['name']] = p
        team = mat['name'].split(' / ')[0]
        data[key] = {'name': team, 'parts': parts}
        print(key, team, len(parts), 'peças', tex_names)
    json.dump(data, open(os.path.join(out, 'liveries.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
