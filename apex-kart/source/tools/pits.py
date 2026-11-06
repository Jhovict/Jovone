"""Escolhe onde fica o pit lane de cada pista e grava a chave "pit" em tracks/*.json (rodar depois do build.py).

O pit lane corre paralelo à pista, do lado e no trecho que tiver espaço livre (longe dos outros trechos e
das barreiras deles), com curvas suaves e de preferência na reta de largada. Formato:
  "pit": {"side": 1 = direita / -1 = esquerda, "s_in": início da rampa de entrada (m), "garages": cabem boxes}
Comprimentos (iguais aos de scripts/track.gd): rampa 28 m, 8 m de folga, 8 boxes de 8 m, 8 m, rampa 28 m.
Uso: python pits.py ../tracks"""
import sys, json, glob
import numpy as np

HW = 4.5
RAMP, PAD, BOX, NBOX = 28.0, 8.0, 8.0, 8
WIN = RAMP + PAD + BOX * NBOX + PAD + RAMP
LANE_OUT = HW + 1.1 + 5.5          # borda externa do pit lane
NEED_LANE = LANE_OUT + 1.5         # espaço livre para o pit lane
NEED_GARAGE = LANE_OUT + 10.0      # espaço livre para o prédio dos boxes


def analyse(d):
    P = np.array(d['pts'], float)
    n = len(P)
    xy = P[:, :2]
    L = float(np.sum(np.linalg.norm(np.roll(xy, -1, 0) - xy, axis=1)))
    ds = L / n
    t = np.roll(xy, -1, 0) - np.roll(xy, 1, 0)
    t /= np.linalg.norm(t, axis=1)[:, None]
    r = np.stack([-t[:, 1], t[:, 0]], 1)               # mesmo "direita" do jogo
    head = np.arctan2(-t[:, 0], -t[:, 1])
    dh = (np.roll(head, -1) - np.roll(head, 1) + np.pi) % (2 * np.pi) - np.pi
    curv = dh / (2 * ds)                                # > 0 = curva à esquerda
    k = np.convolve(np.concatenate([curv[-8:], curv, curv[:8]]), np.ones(17) / 17, 'same')[8:-8]
    wl, wr = np.array(d['wall_l'], float), np.array(d['wall_r'], float)
    br = np.array(d['bridge'])
    idx = np.arange(n)

    def clearance(i, side):
        ci = np.minimum(abs(idx - i), n - abs(idx - i))
        far = ci > 25
        for x in np.arange(6.0, NEED_GARAGE + 1.0, 1.0):
            p = xy[i] + r[i] * side * x
            rel = p - xy
            dist = np.linalg.norm(rel, axis=1)
            sd = np.einsum('ij,ij->i', rel, r)
            need = np.where(sd >= 0, wr, wl) + 1.0
            if np.any((dist < need) & far):
                return x
        return 99.0

    step = max(1, int(round(4.0 / ds)))
    clear = {1: np.zeros(n), -1: np.zeros(n)}
    for side in (1, -1):
        for i in range(0, n, step):
            clear[side][i:i + step] = clearance(i, side)
    best = None
    for i0 in range(0, n, step):
        span = (i0 + np.arange(int(WIN / ds) + 1)) % n
        if br[span].any():
            continue
        u = np.arange(len(span)) * ds
        ramp = (u < RAMP) | (u > WIN - RAMP)
        for side in (1, -1):
            if clear[side][span].min() < NEED_LANE:
                continue
            # pit no lado de dentro da curva: o raio encolhe pela largura do pit lane
            inside = np.sign(k[span]) == -side
            rad = 1.0 / np.maximum(np.abs(k[span]), 1e-4) - np.where(inside, LANE_OUT, 0.0)
            if rad[~ramp].min() < 45.0 or rad[ramp].min() < 22.0:
                continue
            boxes = span[(u >= RAMP + PAD) & (u <= WIN - RAMP - PAD)]
            garages = bool(clear[side][boxes].min() >= NEED_GARAGE)
            centre = (i0 * ds + WIN * 0.5) % L
            dist0 = min(centre, L - centre)
            cost = dist0 + (0.0 if garages else 150.0) + float(np.abs(k[span]).mean()) * 4000.0
            if best is None or cost < best[0]:
                best = (cost, side, i0 * ds, garages, dist0)
    return best, L


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '../tracks'
    for f in sorted(glob.glob(out + '/8*.json')):
        d = json.load(open(f))
        best, L = analyse(d)
        if best is None:
            d.pop('pit', None)
            print(f, 'SEM ESPAÇO PARA PIT LANE')
        else:
            cost, side, s_in, garages, dist0 = best
            d['pit'] = {'side': side, 's_in': round(s_in, 2), 'garages': garages}
            print('%s %-22s lado %+d  s_in %7.1f / %.0f  meio a %.0f m da largada  boxes %s'
                  % (f, d['name'], side, s_in, L, dist0, 'sim' if garages else 'não'))
        json.dump(d, open(f, 'w'), separators=(',', ':'))
