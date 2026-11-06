"""Grãos de explosão para o motor do jogador (síntese granular sincronizada com o RPM).

De cada gravação de motor (sounds/engine_*.wav, feitas pelo make_sounds.py) recorta ciclos de ignição
inteiros: acha a marca de cada explosão (pico da onda filtrada, um por período), corta dois períodos em
volta com janela de Hann e reduz para 22 050 Hz. No jogo, scripts/engine_audio.gd dispara um grão a cada
explosão do motor (frequência = RPM), somando os grãos que se sobrepõem: o timbre é o da gravação, mas o
ritmo segue o motor do kart na hora. Saída: ../sounds/engine_grains.json
Uso (dentro de tools/): python make_grains.py"""
import json
import wave
import numpy as np

SR = 44100
OUT_SR = 22050
N_GRAINS = 16
# gravação, frequência de ignição (Hz) e nome do conjunto
SETS = [('engine_idle', 47.5, 'idle'), ('engine_mid', 92.0, 'mid'), ('engine_high', 132.0, 'high')]


def read(name):
    w = wave.open('../sounds/%s.wav' % name)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return x


def smooth(x, n):
    return np.convolve(x, np.ones(n) / n, 'same')


out = {'rate': OUT_SR, 'sets': []}
for name, f0, key in SETS:
    x = read(name)
    P = SR / f0
    # marcas de ignição: máximo da onda suavizada (fundamental) em cada período
    low = smooth(smooth(x, int(P / 4)), int(P / 4))
    marks = []
    t = P
    while t < len(x) - 2 * P:
        a, b = int(t - P * 0.5), int(t + P * 0.5)
        m = a + int(np.argmax(low[a:b]))
        marks.append(m)
        t = m + P
    # grãos com energia típica (descarta os de volume fora do comum)
    L = int(round(2 * P))
    grains = []
    for m in marks:
        g = x[m - L // 2: m - L // 2 + L]
        if len(g) == L:
            grains.append(g * np.hanning(L))
    e = np.array([np.sqrt(np.mean(g ** 2)) for g in grains])
    med = np.median(e)
    good = [g for g, ee in zip(grains, e) if 0.7 * med < ee < 1.4 * med]
    step = max(1, len(good) // N_GRAINS)
    pick = good[::step][:N_GRAINS]
    # reduz para 22 050 Hz (média de pares depois de um passa-baixas simples)
    res = []
    for g in pick:
        g = smooth(g, 2)[::2]
        res.append(g)
    peak = max(np.max(np.abs(g)) for g in res)
    res = [g / peak * 0.9 for g in res]
    out['sets'].append({'name': key, 'f0': f0, 'grains': [[round(float(v), 4) for v in g] for g in res]})
    print('%-6s %.1f Hz  período %.0f amostras  %d marcas  %d grãos de %d amostras' % (key, f0, P, len(marks), len(res), len(res[0])))

json.dump(out, open('../sounds/engine_grains.json', 'w'), separators=(',', ':'))
print('ok')
