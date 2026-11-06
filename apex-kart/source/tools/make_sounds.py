"""Sons do jogo a partir de gravações reais do Freesound (CC0 e CC-BY 4.0; créditos em sounds/CREDITOS.txt).
Motor em três camadas gravadas (marcha lenta de kart, kart em andamento gravado a bordo, 2 tempos em
giro alto), cada uma recortada num trecho de tom estável, com loop de comprimento múltiplo do ciclo de
ignição e emenda cruzada. Rodar dentro de tools/ com as prévias em tools/src/."""
import numpy as np, soundfile as sf, librosa
from scipy.signal import butter, sosfilt

SR = 44100
OUT = '../sounds/'

def load(name, a=0.0, b=None):
    y, _ = librosa.load('src/%s.mp3' % name, sr=SR, mono=True, offset=a, duration=None if b is None else b - a)
    return y

def hp(x, f):
    return sosfilt(butter(2, f, 'hp', fs=SR, output='sos'), x)

def lp(x, f):
    return sosfilt(butter(2, f, 'lp', fs=SR, output='sos'), x)

def rms_norm(x, target=0.16):
    return x * (target / (np.sqrt(np.mean(x ** 2)) + 1e-9))

def peak_norm(x, peak=0.9):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))

def loop(x, f0, seconds, xf=0.06):
    """Loop com um número inteiro de ciclos de ignição e emenda cruzada (sem estalo na repetição)."""
    L = int(round(round(seconds * f0) * SR / f0)) if f0 > 0 else int(seconds * SR)
    X = int(xf * SR)
    seg = x[: L + X].copy()
    out = seg[:L].copy()
    w = np.sqrt(np.linspace(0, 1, X))
    out[:X] = seg[:X] * w + seg[L:L + X] * np.sqrt(1 - np.linspace(0, 1, X))
    return out

def fade(x, a=0.005, b=0.03):
    x = x.copy(); na, nb = int(a * SR), int(b * SR)
    x[:na] *= np.linspace(0, 1, na); x[-nb:] *= np.linspace(1, 0, nb)
    return x

def save(name, y, peak=None):
    y = np.clip(y, -1, 1) if peak is None else peak_norm(y, peak)
    sf.write(OUT + name, y.astype(np.float32), SR, subtype='PCM_16')
    print('%-18s %.2f s  rms %.3f' % (name, len(y) / SR, np.sqrt(np.mean(y ** 2))))

# motor: três camadas com volume médio igual (a mistura no jogo decide o peso de cada uma)
idle = hp(load('178666', 8.0, 12.0), 30)            # kart de verdade em marcha lenta, 47,5 Hz
mid = hp(load('194630', 13.45, 14.75), 35)          # a bordo de um kart acelerando, 92 Hz
high = hp(load('148855', 13.0, 14.45), 45)          # 2 tempos (Honda CRM 250) em giro alto, 132 Hz
save('engine_idle.wav', rms_norm(loop(idle, 47.5, 3.0)), None)
save('engine_mid.wav', rms_norm(loop(mid, 92.0, 1.1)), None)
save('engine_high.wav', rms_norm(loop(high, 132.0, 1.25)), None)

# partida do kart: duas puxadas, o motor pega e estabiliza (o jogo emenda na marcha lenta)
start = hp(load('178666', 0.0, 7.0), 30)
start[-int(1.5 * SR):] *= np.linspace(1, 0, int(1.5 * SR))
save('start.wav', fade(start), 0.9)

# pneu cantando (trecho tonal) e batida (o fim de uma gravação de acidente)
skid = hp(load('p_614627', 4.0, 5.8), 300)
save('skid.wav', rms_norm(loop(skid, 0, 1.5, 0.2), 0.2), None)
crash = hp(load('p_426021', 1.33, 3.2), 60)
save('crash_1.wav', fade(crash, 0.002, 0.3), 0.92)
save('crash_2.wav', fade(lp(crash, 2500.0), 0.002, 0.3), 0.75)   # variação mais abafada

# bipe da largada (sinal de contagem) e ambiente de kartódromo (karts ao longe e público)
beep = load('p_566343', 0.88, 1.2)
save('beep.wav', fade(beep, 0.003, 0.03), 0.8)
amb = hp(load('p_317471', 20.0, 62.0), 80)
save('ambience.wav', loop(amb, 0, 40.0, 1.0), 0.7)
