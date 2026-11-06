import sys, struct, numpy as np, soundfile as sf
d = open(sys.argv[1], 'rb').read()
# formato do áudio: strf do stream de áudio (WAVEFORMATEX)
i = d.find(b'auds'); j = d.find(b'strf', i)
fmt = struct.unpack('<HHIIHH', d[j + 8:j + 24])
ch, sr, bits = fmt[1], fmt[2], fmt[5]
chunks = []; k = 0
while True:
    k = d.find(b'01wb', k)
    if k < 0: break
    n = struct.unpack('<I', d[k + 4:k + 8])[0]
    if n > 0 and k + 8 + n <= len(d): chunks.append(d[k + 8:k + 8 + n])
    k += 8 + n
raw = b''.join(chunks)
dt = np.int16 if bits == 16 else np.int32
a = np.frombuffer(raw[: len(raw) // (bits // 8 * ch) * (bits // 8 * ch)], dtype=dt).reshape(-1, ch).astype(np.float32) / (2 ** (bits - 1))
sf.write(sys.argv[2], a, sr)
m = a.mean(axis=1)
print('audio %d Hz %d ch %d bits, %.1f s, pico %.2f, recortes %d' % (sr, ch, bits, len(m) / sr, np.abs(a).max(), int((np.abs(a) > 0.99).sum())))
h = sr // 2
print('RMS por 0,5 s:', ' '.join('%d' % int(1000 * np.sqrt(np.mean(m[i:i + h] ** 2))) for i in range(0, len(m), h)))
# tom dominante do motor (autocorrelação) a cada segundo
out = []
for i in range(0, len(m) - sr // 5, sr):
    seg = m[i:i + sr // 5] * np.hanning(sr // 5); ac = np.correlate(seg, seg, 'full')[len(seg) - 1:]
    lo, hi = sr // 600, sr // 40; kk = lo + int(np.argmax(ac[lo:hi])); out.append('%d' % (sr / kk))
print('f0 por segundo (Hz):', ' '.join(out))
