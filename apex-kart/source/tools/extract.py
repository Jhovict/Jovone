"""Extrai a linha central fechada de cada imagem de traçado (linha branca sobre fundo preto).
Saída: JSON com a polilinha em pixels (ordenada, fechada), ponto da seta de largada e cruzamentos."""
import sys, json, math
import numpy as np
from PIL import Image
from scipy import ndimage
from skimage.morphology import skeletonize

N8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def load(path):
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.int32)
    bright = rgb.sum(axis=2)
    blue = rgb[:, :, 2] - rgb[:, :, 0]
    # a seta de largada é azulada; a linha da pista é branca/rosada
    arrow_mask = (bright > 330) & (blue >= 20)
    arrow_mask = ndimage.binary_dilation(arrow_mask, iterations=2) & (bright > 200)
    mask = (bright > 360) & ~arrow_mask
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    big = max(sizes)
    keep = np.zeros_like(mask)
    smalls = []
    for k, sz in enumerate(sizes, 1):
        if sz > big * 0.04:
            keep |= lab == k
        elif sz > 15:
            ys, xs = np.nonzero(lab == k)
            smalls.append((sz, xs.mean(), ys.mean()))
    # preenche furos internos pequenos da linha
    keep = ndimage.binary_closing(keep, structure=np.ones((3, 3)), iterations=1)
    if arrow_mask.sum() > 20:
        alab, an = ndimage.label(arrow_mask)
        asz = ndimage.sum(arrow_mask, alab, range(1, an + 1))
        k = int(np.argmax(asz)) + 1
        ys, xs = np.nonzero(alab == k)
        smalls = [(1e9, xs.mean(), ys.mean())] + smalls
    return keep, smalls


def graph(skel):
    H, W = skel.shape
    pts = set(zip(*np.nonzero(skel)))

    def nb(p):
        return [(p[0] + a, p[1] + b) for a, b in N8 if (p[0] + a, p[1] + b) in pts]

    deg = {p: len(nb(p)) for p in pts}
    nodes_px = [p for p in pts if deg[p] != 2]
    # agrupa pixels de nó vizinhos em um nó
    node_id = {}
    nodes = []
    for p in nodes_px:
        if p in node_id:
            continue
        stack = [p]
        node_id[p] = len(nodes)
        members = []
        while stack:
            q = stack.pop()
            members.append(q)
            for r in nb(q):
                if deg[r] != 2 and r not in node_id:
                    node_id[r] = len(nodes)
                    stack.append(r)
        nodes.append(members)
    edges = []
    seen = set()
    for ni, members in enumerate(nodes):
        for m in members:
            for r in nb(m):
                if r in node_id or (m, r) in seen:
                    continue
                path = [m, r]
                prev, cur = m, r
                while cur not in node_id:
                    nxt = [x for x in nb(cur) if x != prev and x not in path[-3:]]
                    if not nxt:
                        break
                    prev, cur = cur, nxt[0]
                    path.append(cur)
                seen.add((m, r))
                if cur in node_id:
                    seen.add((cur, path[-2]))
                    edges.append([ni, node_id[cur], path])
    # anéis sem nó (traçado sem falhas): vira um nó artificial
    if not nodes and pts:
        p = next(iter(pts))
        return None, p
    return (nodes, edges), None


def ring_from_loop(skel, start):
    pts = set(zip(*np.nonzero(skel)))
    path = [start]
    prev = None
    cur = start
    while True:
        nxt = [(cur[0] + a, cur[1] + b) for a, b in N8 if (cur[0] + a, cur[1] + b) in pts and (cur[0] + a, cur[1] + b) != prev and (cur[0] + a, cur[1] + b) not in path[-4:]]
        if not nxt:
            break
        prev, cur = cur, nxt[0]
        if cur == start:
            break
        path.append(cur)
    return path


def center(members):
    a = np.array(members, dtype=float)
    return a.mean(axis=0)


def direction(path, from_start, k=10):
    a = np.array(path[:k] if from_start else path[::-1][:k], dtype=float)
    d = a[-1] - a[0]
    return d / (np.linalg.norm(d) + 1e-9)


def extract(path):
    mask, smalls = load(path)
    err = None
    # traçados com trechos quase encostados: tenta afinar a linha até separá-los
    for it in range(0, 5):
        m = ndimage.binary_erosion(mask, iterations=it) if it else mask
        try:
            return extract_mask(m, smalls)
        except RuntimeError as ex:
            err = ex
    raise err


def extract_mask(mask, smalls):
    skel = skeletonize(mask)
    g, loop_start = graph(skel)
    if g is None:
        poly = ring_from_loop(skel, loop_start)
        return finish(poly, smalls, mask)
    nodes, edges = g
    # remove ramos curtos (espinhos do esqueleto) repetidamente
    for _ in range(6):
        deg = [0] * len(nodes)
        for e in edges:
            deg[e[0]] += 1
            deg[e[1]] += 1
        keep = []
        removed = False
        for e in edges:
            a, b, p = e
            if len(p) < 45 and (deg[a] == 1) != (deg[b] == 1) and (deg[a] >= 3 or deg[b] >= 3):
                removed = True
                continue
            keep.append(e)
        edges = keep
        if not removed:
            break
    # grampo desenhado tão fechado que vira um anel com "cabo": não dá para separar as duas pernas;
    # o anel e o cabo são removidos e o traçado segue pelo nó de entrada
    loops = [e for e in edges if e[0] == e[1] and len(e[2]) < 150]
    for lp in loops:
        n = lp[0]
        edges = [e for e in edges if e is not lp]
        stem = [e for e in edges if n in e[:2]]
        if len(stem) == 1 and len(stem[0][2]) < 40:
            edges = [e for e in edges if e is not stem[0]]
    deg = [0] * len(nodes)
    for e in edges:
        deg[e[0]] += 1
        deg[e[1]] += 1
    used = [n for n in range(len(nodes)) if deg[n] > 0]
    cen = {n: center(nodes[n]) for n in used}
    # funde nós de cruzamento muito próximos (um X vira dois nós de grau 3)
    parent = {n: n for n in used}

    def root(n):
        while parent[n] != n:
            n = parent[n]
        return n

    for e in edges:
        a, b, p = e
        if a != b and deg[a] >= 3 and deg[b] >= 3 and len(p) < 22:
            parent[root(b)] = root(a)
            e.append('merge')
    edges = [e for e in edges if len(e) == 3]
    for e in edges:
        e[0], e[1] = root(e[0]), root(e[1])
    deg = {}
    for e in edges:
        deg[e[0]] = deg.get(e[0], 0) + 1
        deg[e[1]] = deg.get(e[1], 0) + 1
    # liga as pontas soltas (falhas de setor) ao par mais próximo
    ends = [n for n, d in deg.items() if d == 1]
    # a ponta de uma linha grossa vira um "gancho" no esqueleto: corta alguns pixels de cada ponta
    # solta e prolonga a ponte a partir do trecho reto
    TRIM = 7
    endp = {}
    for e in edges:
        for side in (0, 1):
            n = e[side]
            if n in ends and len(e[2]) > 3 * TRIM:
                if side == 0:
                    e[2] = e[2][TRIM:]
                    endp[n] = np.array(e[2][0], dtype=float)
                else:
                    e[2] = e[2][:-TRIM]
                    endp[n] = np.array(e[2][-1], dtype=float)
    for n in ends:
        if n not in endp:
            endp[n] = center(nodes[n])
    pairs = []
    for i, a in enumerate(ends):
        for b in ends[i + 1:]:
            pairs.append((np.linalg.norm(endp[a] - endp[b]), a, b))
    pairs.sort()
    linked = set()
    for dist, a, b in pairs:
        if a in linked or b in linked or dist > 60:
            continue
        linked.add(a)
        linked.add(b)
        pa, pb = endp[a], endp[b]
        steps = max(2, int(dist))
        bridge = [tuple(np.round(pa + (pb - pa) * t / steps).astype(int)) for t in range(steps + 1)]
        edges.append([a, b, bridge])
    deg = {}
    for e in edges:
        deg[e[0]] = deg.get(e[0], 0) + 1
        deg[e[1]] = deg.get(e[1], 0) + 1
    bad = {n: d for n, d in deg.items() if d not in (2, 4)}
    if bad:
        raise RuntimeError('graus inesperados %s' % bad)
    crossings = [n for n, d in deg.items() if d == 4]
    # percorre: em cada nó segue a aresta mais alinhada com a direção de chegada
    inc = {}
    for k, e in enumerate(edges):
        inc.setdefault(e[0], []).append((k, True))
        inc.setdefault(e[1], []).append((k, False))
    used_e = set()
    k0 = max(range(len(edges)), key=lambda k: len(edges[k][2]))
    poly = []
    k, fwd = k0, True
    while k not in used_e:
        used_e.add(k)
        a, b, p = edges[k]
        seq = p if fwd else p[::-1]
        poly.extend(seq)
        node = b if fwd else a
        din = direction(seq, False)
        din = -din
        best = None
        for (kk, ff) in inc[node]:
            if kk in used_e and kk != k0:
                continue
            if kk == k and len(inc[node]) > 1:
                continue
            seq2 = edges[kk][2] if ff else edges[kk][2][::-1]
            dout = direction(seq2, True)
            score = float(np.dot(din, dout))
            if best is None or score > best[0]:
                best = (score, kk, ff)
        if best is None:
            break
        k, fwd = best[1], best[2]
    if len(used_e) != len(edges):
        raise RuntimeError('arestas não percorridas: %d de %d' % (len(edges) - len(used_e), len(edges)))
    return finish(poly, smalls, mask, [cen.get(c, center(nodes[c])) for c in crossings])


def finish(poly, smalls, mask, crossings=()):
    # remove duplicados consecutivos
    out = [poly[0]]
    for p in poly[1:]:
        if p != out[-1]:
            out.append(p)
    xy = [[float(p[1]), float(p[0])] for p in out]
    arrow = None
    if smalls:
        # a seta de largada: componente pequeno mais próximo da linha
        best = None
        for sz, x, y in smalls:
            d = min(math.hypot(x - q[0], y - q[1]) for q in xy[::5])
            if d < 60 and (best is None or sz > best[0]):
                best = (sz, x, y)
        if best:
            arrow = [best[1], best[2]]
    width = float(mask.sum()) / max(len(xy), 1)
    return {'xy': xy, 'arrow': arrow, 'crossings': [[float(c[1]), float(c[0])] for c in crossings], 'stroke': width}


if __name__ == '__main__':
    res = {}
    for f in sys.argv[2:]:
        try:
            r = extract(f)
            res[f.split('/')[-1].split('\\')[-1]] = r
            print(f, 'pts', len(r['xy']), 'arrow', r['arrow'], 'cross', len(r['crossings']), 'stroke %.1f' % r['stroke'])
        except Exception as ex:
            print(f, 'ERRO', ex)
    json.dump(res, open(sys.argv[1], 'w'))
