"""Converte as polilinhas extraídas em pistas do jogo (JSON em apex_gp/tracks/).
- escala em metros garantindo espaço entre trechos vizinhos e raio mínimo de curva;
- relevo suave (subidas e descidas) e ponte nos cruzamentos;
- distância das barreiras e dos taludes por amostra, sem invadir outro trecho de pista."""
import json, math, sys
import numpy as np

HW = 4.5                 # meia largura do asfalto
WALL_MAX = 11.0          # barreira mais afastada
WALL_MIN = HW + 1.6      # barreira mais próxima (zebra + folga)
EMB_MAX = 30.0           # largura máxima do talude além da barreira
TARGET_LEN = 1350.0      # comprimento desejado (m)
MIN_RADIUS = 5.5
MIN_CLEAR = 2 * WALL_MIN + 1.0
BRIDGE_DH = 5.5

NAMES = {
    '813': ('Deserto Dourado', 'Planície árida', 'desert'),
    '814': ('Ilha das Garças', 'Parque às margens do rio', 'hills'),
    '815': ('Floresta Negra', 'Bosque de pinheiros', 'forest'),
    '816': ('Marina Azul', 'Porto e cais', 'coast'),
    '817': ('Cidade Alta', 'Planalto urbano', 'city'),
    '818': ('Vale do Dragão', 'Colinas orientais', 'hills'),
    '819': ('Campos Verdes', 'Interior rural', 'forest'),
    '820': ('Planalto Magiar', 'Campos abertos', 'hills'),
    '821': ('Oval Estrelado', 'Complexo esportivo', 'fast'),
    '822': ('Serra do Sol', 'Encostas do sul', 'hills'),
    '823': ('Estreito Oriental', 'Margem do estreito', 'desert'),
    '824': ('Bosque Imperial', 'Parque florestal', 'forest'),
    '825': ('Parque Real', 'Jardins do palácio', 'fast'),
    '826': ('Riviera', 'Ruas à beira-mar', 'coast'),
    '827': ('Selva Tropical', 'Floresta equatorial', 'tropical'),
    '828': ('Oito do Oriente', 'Parque de diversões', 'hills'),
}


def resample(xy, step, closed=True):
    pts = np.vstack([xy, xy[:1]]) if closed else xy
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)])
    L = cum[-1]
    n = max(8, int(round(L / step)))
    t = np.linspace(0, L, n, endpoint=False)
    x = np.interp(t, cum, pts[:, 0])
    y = np.interp(t, cum, pts[:, 1])
    return np.stack([x, y], axis=1), L


def smooth(xy, sigma):
    n = len(xy)
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = np.zeros_like(xy)
    for c in range(2):
        ext = np.concatenate([xy[-r:, c], xy[:, c], xy[:r, c]])
        out[:, c] = np.convolve(ext, k, mode='valid')
    return out


def blur1(a, r, passes=2):
    n = len(a)
    for _ in range(passes):
        ext = np.concatenate([a[-r:], a, a[:r]])
        c = np.cumsum(np.concatenate([[0], ext]))
        a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
    return a


def frames(xy):
    t = np.roll(xy, -1, axis=0) - np.roll(xy, 1, axis=0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    rgt = np.stack([-t[:, 1], t[:, 0]], axis=1)   # igual a track.gd: (-t.z, t.x)
    return t, rgt


def curvature(xy, ds):
    t, _ = frames(xy)
    h = np.arctan2(-t[:, 0], -t[:, 1])
    dh = (np.roll(h, -1) - np.roll(h, 1) + np.pi) % (2 * np.pi) - np.pi
    return dh / (2 * ds)


def arcdist(n, ds):
    i = np.arange(n)
    a = np.abs(i[:, None] - i[None, :])
    return np.minimum(a, n - a) * ds


def other_mask(xy, ds):
    """Pares (i, j) que pertencem a trechos diferentes da pista (não à mesma curva)."""
    D = np.linalg.norm(xy[:, None, :] - xy[None, :, :], axis=2)
    A = arcdist(len(xy), ds)
    return D, A > 1.8 * D + 8.0


def rdp(pts, eps):
    """Ramer-Douglas-Peucker (aberto): mantém só os pontos que se afastam mais de eps da corda."""
    keep = np.zeros(len(pts), dtype=bool)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        a, b = pts[i], pts[j]
        ab = b - a
        L = np.linalg.norm(ab)
        seg = pts[i + 1:j] - a
        if L < 1e-9:
            d = np.linalg.norm(seg, axis=1)
        else:
            d = np.abs(seg[:, 0] * ab[1] - seg[:, 1] * ab[0]) / L
        k = int(np.argmax(d))
        if d[k] > eps:
            m = i + 1 + k
            keep[m] = True
            stack += [(i, m), (m, j)]
    return pts[keep]


def catmull_closed(P, per_unit):
    """Catmull-Rom centrípeta fechada passando pelos vértices P (sem laços nem pontas)."""
    n = len(P)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % n], P[(i + 2) % n]
        def tj(ti, a, b):
            return ti + max(np.linalg.norm(b - a), 1e-6) ** 0.5
        t0 = 0.0
        t1 = tj(t0, p0, p1)
        t2 = tj(t1, p1, p2)
        t3 = tj(t2, p2, p3)
        steps = max(2, int(np.linalg.norm(p2 - p1) * per_unit))
        for t in np.linspace(t1, t2, steps, endpoint=False):
            a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            out.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
    return np.array(out)


def clean_path(xy_px, stroke):
    """Traçado limpo em pixels: retas viram retas (RDP) e as curvas passam suaves pelos vértices."""
    xy, _ = resample(xy_px, 1.0)
    xy = smooth(xy, 1.2)
    eps = max(1.4, stroke * 0.12)
    # fecha o polígono partindo do ponto mais distante do primeiro
    far = int(np.argmax(np.linalg.norm(xy - xy[0], axis=1)))
    a = rdp(np.vstack([xy[:far + 1]]), eps)
    b = rdp(np.vstack([xy[far:], xy[:1]]), eps)
    verts = np.vstack([a[:-1], b[:-1]])
    return fillet_closed(verts, stroke), len(verts)


def fillet_closed(V, stroke):
    """Polígono com cantos arredondados: cada vértice vira um arco tangente aos dois lados.
    Retas continuam retas, curvas não têm quinas nem curvatura invertida."""
    n = len(V)
    out = []
    r_cap = 0.8 * stroke                      # raio máximo nas pontas agudas (como a ponta do desenho)
    seg = [np.linalg.norm(V[(i + 1) % n] - V[i]) for i in range(n)]
    for i in range(n):
        a, b, c = V[i - 1], V[i], V[(i + 1) % n]
        la, lc = seg[i - 1], seg[i]
        d1 = (b - a) / max(la, 1e-9)
        d2 = (c - b) / max(lc, 1e-9)
        cross = d1[0] * d2[1] - d1[1] * d2[0]
        phi = np.arctan2(abs(cross), np.dot(d1, d2))       # quanto o traçado vira neste vértice
        if phi < 1e-3:
            out.append(b)
            continue
        t = min(0.5 * la, 0.5 * lc)
        if phi > np.radians(60):
            t = min(t, r_cap * np.tan(phi * 0.5))
        r = t / np.tan(phi * 0.5)
        p_in = b - d1 * t
        nrm = np.array([-d1[1], d1[0]]) * np.sign(cross)
        center = p_in + nrm * r
        a0 = np.arctan2(p_in[1] - center[1], p_in[0] - center[0])
        steps = max(2, int(r * phi / 0.5))
        for k in range(steps + 1):
            ang = a0 + np.sign(cross) * phi * k / steps
            out.append(center + r * np.array([np.cos(ang), np.sin(ang)]))
    return np.array(out)


def scale_for(xy_px):
    xy, L = resample(xy_px, 3.0)
    xy = smooth(xy, 2.0)
    ds = L / len(xy)
    k = np.abs(blur1(curvature(xy, ds), 2))
    rmin = 1.0 / max(np.percentile(k, 99.5), 1e-6)
    D, other = other_mask(xy, ds)
    # cruzamentos (viram ponte) não contam como trechos apertados
    A = arcdist(len(xy), 1.0)
    for i, j in np.argwhere(other & (D < 4.0)):
        near = (A[i][:, None] < 60.0) & (A[j][None, :] < 60.0)
        other &= ~(near | near.T)
    cmin = np.where(other, D, np.inf).min()
    s = max(TARGET_LEN / L, MIN_CLEAR / cmin, MIN_RADIUS / rmin)
    return s, L, rmin, cmin


def barriers(xy, y, ds):
    """Barreiras, taludes e pontes de um traçado já pronto (xy a cada ~1 m, relevo y)."""
    n = len(xy)
    t, rgt = frames(xy)
    D, other = other_mask(xy, ds)
    # espaço até outros trechos, por lado
    DY = np.abs(y[:, None] - y[None, :])
    rel = xy[None, :, :] - xy[:, None, :]
    side = np.sign(np.einsum('ijk,ik->ij', rel, rgt))
    inf = np.inf
    near_wall = other & (DY < 3.5)          # trechos no mesmo nível: barreira no meio
    clear = {}
    clear_all = {}
    for sg, key in [(-1, 'l'), (1, 'r')]:
        m = near_wall & (side == sg)
        clear[key] = np.where(m, D, inf).min(axis=1)
        m2 = other & (side == sg)
        Dm = np.where(m2, D, inf)
        jmin = Dm.argmin(axis=1)
        clear_all[key] = (Dm.min(axis=1), jmin)
    kr = (np.roll(rgt, -1, axis=0) - np.roll(rgt, 1, axis=0))
    kr = np.einsum('ik,ik->i', kr, t) / (2 * ds)          # derivada da normal ao longo da pista
    kr = blur1(kr, 2)
    out = {}
    bridge = np.zeros(n, dtype=int)
    for sg, key in [(-1, 'l'), (1, 'r')]:
        wall = np.minimum(WALL_MAX, clear[key] * 0.5 - 0.4)
        # lado de dentro da curva: a faixa deslocada não pode se dobrar sobre si mesma
        kk = kr * sg
        lim = np.where(kk < 0, 0.7 / np.maximum(-kk, 1e-6), inf)
        wall = np.minimum(wall, lim)
        # piso: em grampo muito fechado o lado de dentro é só uma "ilha"; a barreira fica junto à
        # borda da pista, sempre antes do centro da curva (assim nunca se dobra sobre o asfalto)
        radius_in = np.where(kk < 0, 1.0 / np.maximum(-kk, 1e-6), inf)
        floor = np.minimum(WALL_MIN, np.maximum(HW + 0.6, 0.95 * radius_in))
        floor = np.array([floor[(np.arange(i - 6, i + 7)) % n].min() for i in range(n)])
        wall = np.maximum(wall, floor)
        # mínimo numa janela e suavização: a barreira muda de distância gradualmente
        wm = np.array([wall[(np.arange(i - 8, i + 9)) % n].min() for i in range(n)])
        wall = np.maximum(blur1(wm, 6), floor)
        wall = np.minimum(wall, np.maximum(floor, wm + 0.0))
        dist_all, jmin = clear_all[key]
        emb = np.minimum(EMB_MAX, np.maximum(0.0, dist_all * 0.5 - wall))
        # o talude também não pode se dobrar por dentro das curvas
        emb = np.minimum(emb, np.maximum(0.0, lim - wall))
        emb = np.array([emb[(np.arange(i - 10, i + 11)) % n].min() for i in range(n)])
        emb_h = np.where(dist_all * 0.5 < wall + EMB_MAX, np.minimum(y, y[jmin]) - 0.25, np.nan)
        # ponte: outro trecho passa por baixo bem perto
        under = other & (side == sg) & (D < wall[:, None] + 6.0) & ((y[:, None] - y[None, :]) > 3.5)
        bridge |= under.any(axis=1).astype(int)
        out['wall_' + key] = np.round(wall, 3).tolist()
        out['emb_' + key] = np.round(np.minimum(blur1(emb, 4, 1), emb + 0.5), 3).tolist()
        out['embh_' + key] = [None if math.isnan(v) else round(float(v), 3) for v in emb_h]
    # alarga a zona de ponte para cobrir rampas curtas
    bz = blur1(bridge.astype(float), 12, 1) > 0
    out['bridge'] = bz.astype(int).tolist()
    return out


def build(name, raw, seed):
    xy_px = np.array(raw['xy'], dtype=float)
    # sentido horário visto de cima (como a maioria dos traçados)
    area = 0.5 * np.sum(xy_px[:, 0] * np.roll(xy_px[:, 1], -1) - np.roll(xy_px[:, 0], -1) * xy_px[:, 1])
    if area < 0:
        xy_px = xy_px[::-1].copy()
    xy_px, nverts = clean_path(xy_px, float(raw.get('stroke', 14.0)))
    s, Lpx, rmin, cmin = scale_for(xy_px)
    xy = xy_px * s
    xy, L = resample(xy, 1.0)
    xy = smooth(xy, 1.2)
    # alivia curvas fechadas demais (raio < MIN_RADIUS): só os pontos da própria curva (e uma margem
    # que cresce conforme a necessidade) se movem; as retas vizinhas ficam presas no lugar
    xy, L = resample(xy, 1.0)
    ever = np.zeros(len(xy), dtype=bool)
    cap = None
    for _ in range(600):
        seg = np.linalg.norm(np.roll(xy, -1, axis=0) - xy, axis=1)
        dsl = 0.5 * (seg + np.roll(seg, 1))
        t = np.roll(xy, -1, axis=0) - np.roll(xy, 1, axis=0)
        h = np.arctan2(t[:, 0], t[:, 1])
        dh = (np.roll(h, -1) - np.roll(h, 1) + np.pi) % (2 * np.pi) - np.pi
        k = np.abs(dh) / (2.0 * np.maximum(dsl, 0.05))
        bad = k > 1.0 / MIN_RADIUS
        if not bad.any():
            break
        if cap is None:
            # o arredondamento nunca passa de ~25 m em volta de cada curva fechada original
            cap = blur1(bad.astype(float), 25, 1) > 0
        ever |= bad & cap
        zone = (blur1(ever.astype(float), 5, 1) > 0) & cap
        avg = (np.roll(xy, 1, axis=0) + np.roll(xy, -1, axis=0)) * 0.5
        xy[zone] = xy[zone] * 0.5 + avg[zone] * 0.5
    xy, L = resample(xy, 1.0)
    n = len(xy)
    ds = L / n
    # largada no ponto mais perto da seta
    start = 0
    if raw['arrow']:
        a = np.array(raw['arrow']) * s
        start = int(np.argmin(np.linalg.norm(xy - a, axis=1)))
        # recua até um trecho reto, para o grid ficar alinhado
    k = blur1(np.abs(curvature(xy, ds)), 6)
    best = None
    for off in range(-120, 121, 2):
        i = (start + off) % n
        idx = [(i - j) % n for j in range(0, 80)]
        sc = k[idx].max() + abs(off) * 0.00002
        if best is None or sc < best[0]:
            best = (sc, i)
    start = best[1]
    xy = np.roll(xy, -start, axis=0)
    t, rgt = frames(xy)
    sarc = np.arange(n) * ds

    # relevo: ondulações suaves de comprimentos diferentes, plano perto da largada
    rng = np.random.default_rng(seed)
    y = np.zeros(n)
    for wl, amp in [(L / 2.0, 2.2), (L / 3.0, 1.5), (min(220.0, L / 5.0), 0.9), (min(110.0, L / 9.0), 0.35)]:
        cycles = max(1, round(L / wl))
        y += amp * rng.uniform(0.6, 1.0) * np.sin(2 * np.pi * cycles * sarc / L + rng.uniform(0, 2 * np.pi))
    dist0 = np.minimum(sarc, L - sarc)
    w = np.clip((dist0 - 70.0) / 90.0, 0, 1)
    w = w * w * (3 - 2 * w)
    y = y[0] + (y - y[0]) * w
    # pontes nos cruzamentos
    D, other = other_mask(xy, ds)
    crossings = []
    cand = np.argwhere(other & (D < 3.0))
    for i, j in cand:
        if i < j and not any(abs(i - a) < 30 and abs(j - b) < 30 for a, b in crossings):
            crossings.append((int(i), int(j)))
    for i, j in crossings:
        for _ in range(20):
            if abs(y[i] - y[j]) >= BRIDGE_DH:
                break
            up, dn = (i, j) if y[i] >= y[j] else (j, i)
            ad_up = np.minimum(np.abs(np.arange(n) - up), n - np.abs(np.arange(n) - up)) * ds
            ad_dn = np.minimum(np.abs(np.arange(n) - dn), n - np.abs(np.arange(n) - dn)) * ds
            need = BRIDGE_DH - abs(y[i] - y[j]) + 0.3
            y += need * 0.6 * np.exp(-0.5 * (ad_up / 55.0) ** 2)
            y -= need * 0.4 * np.exp(-0.5 * (ad_dn / 55.0) ** 2)
    y = blur1(y, 3)

    out = barriers(xy, y, ds)
    out['pts'] = [[round(float(p[0]), 3), round(float(p[1]), 3), round(float(h), 3)] for p, h in zip(xy, y)]
    nm, place, theme = NAMES[name]
    out.update({'name': nm, 'place': place, 'theme': theme, 'hw': HW, 'length': round(float(L), 1),
                'scale': round(float(s), 4), 'crossings': len(crossings)})
    print('%s %-18s L=%6.0f m  escala=%.3f m/px  rmin_px=%.1f  clear_px=%.1f  y=[%.1f, %.1f]  pontes=%d  muro_min=%.1f' % (
        name, nm, L, s, rmin, cmin, y.min(), y.max(), len(crossings), min(min(out['wall_l']), min(out['wall_r']))))
    return out


if __name__ == '__main__':
    raw = json.load(open('raw.json'))
    outdir = sys.argv[1]
    index = []
    for k, (fname, r) in enumerate(sorted(raw.items())):
        key = fname.split('.')[0]
        data = build(key, r, 1000 + k)
        json.dump(data, open('%s/%s.json' % (outdir, key), 'w'), separators=(',', ':'))
        index.append({'file': 'res://tracks/%s.json' % key, 'name': data['name'], 'place': data['place'], 'theme': data['theme'], 'length': data['length']})
    json.dump(index, open('%s/index.json' % outdir, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
