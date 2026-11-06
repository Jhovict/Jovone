import json, sys, glob, numpy as np
for f in sorted(glob.glob('../apex_gp/tracks/8*.json')):
    d = json.load(open(f)); P = np.array([[p[0], p[1]] for p in d['pts']])
    t = np.roll(P, -1, 0) - P; h = np.unwrap(np.arctan2(t[:, 1], t[:, 0]))
    dh = np.diff(np.concatenate([h, h[:1] + (h[-1] - h[0]) * 0]))[:-1]
    k = dh  # rad por metro
    # zigue-zague: inversões de sentido de curva em curta distância com curvatura apreciável
    sgn = np.sign(np.where(np.abs(k) > 0.01, k, 0))
    flips = 0; last = 0; lasti = -99
    for i, s in enumerate(sgn):
        if s != 0:
            if last != 0 and s != last and i - lasti < 12: flips += 1
            last = s; lasti = i
    print(f.split('/')[-1], 'L=%d' % len(P), 'inversoes_curtas=%d' % flips, 'curv_rms=%.4f' % np.sqrt(np.mean(k**2)))
