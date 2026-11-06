"""Sons do clima a partir de gravações do Freesound (CC0; créditos em sounds/CREDITOS.txt):
chuva em loop (a tempestade usa a mesma chuva mais alta) e dois trovões. Rodar dentro de tools/ com as
prévias em src/ (numpy e soundfile, que também lê mp3)."""
import numpy as np
import soundfile as sf

SR = 22050
OUT = '../sounds/'


def load(name, a, b):
    y, sr = sf.read('src/%s.mp3' % name)
    if y.ndim > 1:
        y = y.mean(1)
    y = y[int(a * sr): int(b * sr)]
    # reamostra para 22 050 Hz (interpolação linear depois de suavizar)
    k = max(1, int(round(sr / SR)))
    y = np.convolve(y, np.ones(k) / k, 'same')
    t = np.arange(0, len(y) / sr, 1.0 / SR)
    return np.interp(t, np.arange(len(y)) / sr, y)


def fade(x, a, b):
    x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    x[:na] *= np.linspace(0, 1, na)
    x[-nb:] *= np.linspace(1, 0, nb) ** 2
    return x


def loop(x, seconds, xf):
    L, X = int(seconds * SR), int(xf * SR)
    out = x[:L].copy()
    w = np.linspace(0, 1, X)
    out[:X] = x[:X] * np.sqrt(w) + x[L:L + X] * np.sqrt(1 - w)
    return out


def save(name, y, peak):
    y = y * (peak / (np.max(np.abs(y)) + 1e-9))
    sf.write(OUT + name, y.astype(np.float32), SR, subtype='PCM_16')
    print('%-14s %.1f s  rms %.3f' % (name, len(y) / SR, np.sqrt(np.mean(y ** 2))))


save('rain.wav', loop(load('w_200272', 2.0, 44.0), 40.0, 1.5), 0.7)
save('thunder_1.wav', fade(load('w_446753', 0.8, 16.0), 0.01, 5.0), 0.95)
save('thunder_2.wav', fade(load('w_244053', 6.2, 14.5), 0.01, 3.0), 0.9)
