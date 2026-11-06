"""Suaviza as curvas fechadas demais direto em tracks/*.json (o raw.json da extração não é necessário).

Cada curva com raio abaixo de R_TARGET é trocada por uma curva nova (Hermite quíntica, tangente e sem
curvatura nas duas pontas) entre um ponto da reta de chegada e um da reta de saída. Pontas e "força" das
tangentes são escolhidas por busca para dar o maior raio mínimo possível (até R_TARGET) sem chegar perto
de outro trecho da pista: grampos que obrigavam a quase parar viram curvas em U e o muro de dentro deixa
de se dobrar sobre o asfalto. O relevo é mantido pelo comprimento e barreiras, taludes e pontes são
recalculados com build.barriers. Depois rodar pits.py, porque o comprimento das pistas muda.
Uso: python reshape.py ../tracks [pista ...]"""
import sys, json, glob, os
import numpy as np
import build

R_TARGET = 9.0       # raio mínimo desejado (m)
CLEAR = 14.5         # distância mínima da curva nova até outros trechos (eixo a eixo), se a original já não era menor


def curv(xy, w=3):
    t = np.roll(xy, -1, 0) - np.roll(xy, 1, 0)
    h = np.arctan2(t[:, 1], t[:, 0])
    dh = (np.roll(h, -w) - np.roll(h, w) + np.pi) % (2 * np.pi) - np.pi
    return dh / (2.0 * w)


def resample_with(xy, y, step=1.0):
    seg = np.linalg.norm(np.roll(xy, -1, 0) - xy, axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    L = s[-1]
    n = int(round(L / step))
    st = np.arange(n) * L / n
    xc = np.vstack([xy, xy[:1]])
    yc = np.concatenate([y, y[:1]])
    return np.stack([np.interp(st, s, xc[:, 0]), np.interp(st, s, xc[:, 1])], 1), np.interp(st, s, yc), L


def hermite(P0, T0, P1, T1, m):
    t = np.linspace(0.0, 1.0, m)[:, None]
    h0 = 1 - 10 * t ** 3 + 15 * t ** 4 - 6 * t ** 5
    h1 = t - 6 * t ** 3 + 8 * t ** 4 - 3 * t ** 5
    h4 = -4 * t ** 3 + 7 * t ** 4 - 3 * t ** 5
    h5 = 10 * t ** 3 - 15 * t ** 4 + 6 * t ** 5
    return h0 * P0 + h1 * T0 + h4 * T1 + h5 * P1


def min_radius(c):
    d1 = np.gradient(c, axis=0)
    d2 = np.gradient(d1, axis=0)
    k = np.abs(d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]) / np.maximum(np.linalg.norm(d1, axis=1) ** 3, 1e-9)
    return 1.0 / max(k[2:-2].max(), 1e-6)


def tangent(xy, i):
    n = len(xy)
    d = xy[(i + 2) % n] - xy[(i - 2) % n]
    return d / np.linalg.norm(d)


def fix_corner(xy, y, a, b):
    """Troca o trecho em volta da curva [a, b] (índices sem dar a volta no zero). None se não melhora."""
    n = len(xy)
    k = np.abs(curv(xy))
    r_now = 1.0 / k[a:b + 1].max()
    best = None
    for mi in range(6, 61, 3):
        for mo in range(6, 61, 3):
            i0, i1 = a - mi, b + mo
            if i0 < 1 or i1 > n - 2:
                continue
            # as pontas ficam em trecho quase reto
            if k[i0] > 1.0 / 25.0 or k[i1] > 1.0 / 25.0:
                continue
            P0, P1 = xy[i0], xy[i1]
            d0, d1 = tangent(xy, i0), tangent(xy, i1)
            ref = max(np.linalg.norm(P1 - P0), 8.0)
            far = np.r_[0:max(0, i0 - 25), min(n, i1 + 25):n]
            # nunca mais perto de outro trecho do que a curva original já estava
            orig = np.min(np.linalg.norm(xy[i0:i1 + 1:2, None, :] - xy[None, far, :], axis=2))
            need = min(CLEAR, orig - 0.3)
            for lam in np.arange(0.4, 6.01, 0.2):
                L_est = ref * (1.0 + 0.5 * lam)
                c = hermite(P0, d0 * ref * lam, P1, d1 * ref * lam, max(30, int(L_est * 2)))
                r = min(min_radius(c), R_TARGET)
                if best is not None and r < best[0] - 1e-6:
                    continue
                dist = np.min(np.linalg.norm(c[::4, None, :] - xy[None, far, :], axis=2))
                if dist < need:
                    continue
                # empate no raio: prefere mexer menos na pista
                score = (round(r, 1), -(mi + mo))
                if best is None or score > best[3]:
                    best = (r, i0, i1, score, c)
    if best is None or best[0] < r_now * 1.15:
        return None
    r, i0, i1, _, c = best
    seg = np.linalg.norm(np.diff(c, axis=0), axis=1)
    f = np.concatenate([[0], np.cumsum(seg)]) / seg.sum()
    yo = y[i0:i1 + 1]
    so = np.linspace(0, 1, len(yo))
    new_xy = np.vstack([xy[:i0], c, xy[i1 + 1:]])
    new_y = np.concatenate([y[:i0], np.interp(f, so, yo), y[i1 + 1:]])
    return new_xy, new_y, r_now, r


def spread_hairpin(xy, a, b, W=40):
    """Grampo entre duas retas paralelas próximas demais: afasta as retas devagar (W m) até haver vão para
    um U de raio R_TARGET. None se não é um grampo assim ou se encostaria em outro trecho."""
    n = len(xy)
    if a - W < 1 or b + W > n - 2:
        return None
    ent = np.arange(a - W, a + 1)
    ext = np.arange(b, b + W + 1)
    gap = np.linalg.norm(xy[a - W] - xy[b + W])
    push = (2.0 * R_TARGET + 0.5 - gap) * 0.5
    if push <= 0.0 or push > 4.0:
        return None
    t_in, t_out = tangent(xy, a - W), tangent(xy, b + W)
    if np.dot(t_in, t_out) > -0.95:          # só grampos de ~180 graus entre retas paralelas
        return None
    out = xy.copy()
    for idx, other in [(ent, xy[b + W]), (ext, xy[a - W])]:
        for i in idx:
            f = abs(i - idx[0] if idx is ent else idx[-1] - i) / float(W)
            f = f * f * (3 - 2 * f)
            q = xy[i] - other
            nrm = q - np.dot(q, t_in) * t_in
            out[i] = xy[i] + nrm / max(np.linalg.norm(nrm), 1e-6) * push * f
    # o miolo do grampo acompanha (é trocado em seguida pela curva nova)
    mid = 0.5 * (xy[a] + xy[b])
    for i in range(a + 1, b):
        q = xy[i] - mid
        nrm = q - np.dot(q, t_in) * t_in
        out[i] = xy[i] + nrm / max(np.linalg.norm(nrm), 1e-6) * push
    far = np.r_[0:max(0, a - W - 25), min(n, b + W + 25):n]
    orig = np.min(np.linalg.norm(xy[a - W:b + W + 1:2, None, :] - xy[None, far, :], axis=2))
    new = np.min(np.linalg.norm(out[a - W:b + W + 1:2, None, :] - xy[None, far, :], axis=2))
    if new < min(CLEAR, orig - 0.3):
        return None
    return out


def zones(xy):
    k = np.abs(curv(xy))
    idx = np.where(k > 1.0 / R_TARGET)[0]
    out = []
    for i in idx:
        if out and i - out[-1][1] <= 12:
            out[-1][1] = i
        else:
            out.append([i, i])
    return out


def soften(xy, y):
    xy, y, _ = resample_with(xy, y)
    start = xy[0].copy()
    log = []
    skip = []
    for _ in range(40):
        zs = [z for z in zones(xy) if not any(np.linalg.norm(xy[(z[0] + z[1]) // 2] - q) < 6.0 for q in skip)]
        if not zs:
            break
        a, b = zs[0]
        # gira a pista para a curva ficar no meio (nenhum trecho trocado passa pelo índice 0)
        n = len(xy)
        sh = n // 2 - (a + b) // 2
        xr, yr = np.roll(xy, sh, 0), np.roll(y, sh)
        res = fix_corner(xr, yr, a + sh, b + sh)
        if res is None:
            wide = spread_hairpin(xr, a + sh, b + sh)
            if wide is not None:
                res = fix_corner(wide, yr, a + sh, b + sh)
                if res is not None:
                    res = res[0], res[1], 1.0 / np.abs(curv(xr))[a + sh:b + sh + 1].max(), res[3]
        if res is None:
            skip.append(xy[(a + b) // 2].copy())
            log.append('  curva em %.0f m: sem espaço para abrir (raio %.1f m)' % ((a + b) / 2, 1.0 / np.abs(curv(xy))[a:b + 1].max()))
            continue
        xr, yr, r0, r1 = res
        xr, yr, _ = resample_with(xr, yr)
        # volta a largada para o índice 0
        j = int(np.argmin(np.linalg.norm(xr - start, axis=1)))
        xy, y = np.roll(xr, -j, 0), np.roll(yr, -j)
        log.append('  curva em %.0f m: raio %.1f -> %.1f m' % ((a + b) / 2, r0, r1))
    xy, y, L = resample_with(xy, y)
    return xy, y, L, log


if __name__ == '__main__':
    outdir = sys.argv[1]
    only = set(sys.argv[2:])
    idx_path = '%s/index.json' % outdir
    index = json.load(open(idx_path, encoding='utf-8'))
    for path in sorted(glob.glob('%s/8*.json' % outdir)):
        key = os.path.basename(path)[:-5]
        if only and key not in only:
            continue
        d = json.load(open(path, encoding='utf-8'))
        P = np.array(d['pts'], float)
        xy, y, L, log = soften(P[:, :2], P[:, 2])
        out = build.barriers(xy, y, L / len(xy))
        d.update(out)
        d['pts'] = [[round(float(p[0]), 3), round(float(p[1]), 3), round(float(h), 3)] for p, h in zip(xy, y)]
        old_L = d['length']
        d['length'] = round(float(L), 1)
        json.dump(d, open(path, 'w', encoding='utf-8'), separators=(',', ':'), ensure_ascii=False)
        for e in index:
            if e['file'].endswith('/%s.json' % key):
                e['length'] = d['length']
        print('%s %-18s L %.0f -> %.0f m  raio mín %.1f m  muro_min %.1f' % (
            key, d['name'], old_L, L, 1.0 / np.abs(curv(xy)).max(), min(min(d['wall_l']), min(d['wall_r']))))
        print('\n'.join(log))
    json.dump(index, open(idx_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
