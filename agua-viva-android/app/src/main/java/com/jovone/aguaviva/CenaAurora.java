package com.jovone.aguaviva;

/** Aurora boreal: só o céu, cortinas 3D em perspectiva (30 s). Porte de aurora.js. */
public class CenaAurora extends Motor {

    @Override protected int cols() { return 110; }
    @Override public float loop() { return 30; }

    static final String WORD = "AURORABOREALISNORTHERNLIGHTS";
    // profundidade, largura, amplitude da dobra, frequência, altura, ganho, fase
    static final float[][] CURT = {{9.5f, 30, 2.6f, 1.2f, 2.4f, 0.6f, 0.0f}, {6.4f, 20, 2.0f, 1.6f, 2.8f, 0.9f, 2.1f}, {4.6f, 14, 1.4f, 2.0f, 2.6f, 1.05f, 4.2f}};
    float[][] st, bright, met;

    @Override protected void init() {
        Rng R0 = new Rng(55);
        st = new float[620][5];
        for (float[] s : st){ s[0] = R0.next(); s[1] = R0.next(); s[2] = R0.next(); s[3] = R0.next(); s[4] = mix(0xbecdff, 0xffeed6, R0.next()); }
        bright = new float[16][4];
        for (float[] b : bright){ b[0] = R0.next(); b[1] = R0.next() * 0.8f; b[2] = R0.next() * TAU; b[3] = mix(0xcfe0ff, 0xffe2b8, R0.next()); }
        float[] ts = {4.2f, 8.9f, 14.4f, 19.6f, 25.3f};
        met = new float[ts.length][6];
        for (int i = 0; i < ts.length; i++){
            met[i][0] = ts[i]; met[i][1] = 0.15f + 0.7f * R0.next(); met[i][2] = 0.03f + 0.25f * R0.next();
            met[i][3] = (R0.next() < 0.5f ? -1 : 1) * (40 + 25 * R0.next()); met[i][4] = 14 + 10 * R0.next(); met[i][5] = 0.55f + 0.35f * R0.next();
        }
    }

    @Override protected void frame(float t, float T) {
        float calm = sstep(1.5f, 7, t) * (1 - sstep(24, 28.5f, t)) * (0.85f + 0.2f * sin(t * 0.55f));
        float sub = exp(-pow((t - 13.5f) / 2.0f, 2)), sub2 = 0.6f * exp(-pow((t - 20) / 1.6f, 2));
        float E = calm + 0.6f * sub + 0.45f * sub2, surge = Math.max(sub, sub2);
        float HZ = R * 1.06f, F = R * 0.92f, cx = C * 0.5f;

        float starA = clamp(0.25f + sstep(0, 2, t), 0, 1) * (1 - 0.35f * clamp(E, 0, 1));
        for (float[] s : st){
            float tw = 0.35f + 0.65f * Math.max(0, sin(T * (0.8f + 1.6f * s[3]) + s[2] * 9));
            put(s[0] * C, s[1] * R, s[3] > 0.93f ? '+' : '.', (int) s[4], starA * tw * (0.45f + 0.55f * s[3]), 1);
        }
        for (float[] b : bright){
            float tw = 0.6f + 0.4f * sin(T * 2 + b[2] * 7), c = b[0] * C, r = b[1] * R, a = starA * tw;
            int col = (int) b[3];
            put(c, r, '*', col, a, 2); put(c - 1, r, '-', col, a * 0.4f, 2); put(c + 1, r, '-', col, a * 0.4f, 2); put(c, r - 1, '\'', col, a * 0.3f, 2); put(c, r + 1, '.', col, a * 0.3f, 2);
        }

        final int GREEN = 0x3dff8e, LIME = 0xb8ff9a, TEAL = 0x26e6c4, VIOLET = 0xa85cff, PINK = 0xff4fa8, WHITE = 0xe8fff0;
        int nW = WORD.length();
        for (int k = 0; k < CURT.length; k++){
            float[] K = CURT[k];
            final int N = 520;
            float prevCol = Float.NaN;
            for (int i = 0; i <= N; i++){
                float s = (float) i / N;
                float x = (s - 0.5f) * K[1] + 0.8f * sin(T * 0.07f + k);
                float z = K[0] + K[2] * sin(s * TAU * K[3] + T * 0.22f + K[6]) + K[0] * 0.18f * (fbm1(s * 5 + T * 0.08f + k * 7) - 0.5f)
                        + surge * 0.35f * sin(s * 40 - T * 4 + k);
                if (z < 1.5f) continue;
                float col = cx + F * asp * x / z;
                float dir = Float.isNaN(prevCol) ? 0 : Math.signum(prevCol - col);
                int span = Float.isNaN(prevCol) ? 1 : Math.min(3, Math.max(1, Math.round(Math.abs(col - prevCol))));
                prevCol = col;
                if (col < -4 || col > C + 4) continue;
                float yb = 1.55f + 0.18f * sin(s * 9 + T * 0.5f + k) + 0.12f * surge * sin(s * 30 - T * 6);
                float Hh = K[4] * (0.65f + 0.7f * fbm1(s * 4.5f + T * 0.13f + k * 3));
                float pulse = 0.55f + 0.45f * Math.max(0, sin(s * 22 - T * (1.6f + 2.5f * surge) + k));
                float amp = E * K[5] * (0.25f + 0.75f * fbm1(s * 3.2f - T * 0.11f + k * 3)) * pulse;
                if (amp < 0.03f) continue;
                float rn = noise1(s * 150 + T * 1.3f + k * 11);
                float rays = 0.12f + 0.88f * rn * rn * (0.6f + 0.4f * noise1(s * 18 - T * 0.5f));
                float r0 = HZ - F * yb / z, r1 = HZ - F * (yb + Hh) / z;
                int steps = Math.max(2, (int) Math.ceil((r0 - r1) * 1.2f));
                float depthFade = clamp(1.25f - K[0] / 14, 0.45f, 1);
                for (int j = 0; j <= steps; j++){
                    float v = (float) j / steps;
                    float prof = v < 0.05f ? sstep(0, 0.05f, v) * 1.5f : pow(1 - v, 1.8f) * (0.25f + 0.95f * rays);
                    float b = amp * prof * depthFade;
                    if (b < 0.05f || hash(((i + 1) * (int) 2654435761L) ^ ((j + 7) * 40503) ^ k) > b * 3.5f) continue;
                    int rgb = v < 0.08f ? mix(WHITE, LIME, v / 0.08f) : v < 0.4f ? mix(GREEN, TEAL, (v - 0.08f) / 0.32f) : mix(TEAL, VIOLET, (v - 0.4f) / 0.6f);
                    if (v < 0.06f && surge > 0.2f) rgb = mix(rgb, PINK, surge * 0.7f);
                    float r = lerp(r0, r1, v);
                    char chr = WORD.charAt((i * 7 + j * 3 + k * 5) % nW);
                    for (int q = 0; q < span; q++) addc(col + q * dir, r, chr, rgb, clamp(b * 1.15f, 0, 1), 5);
                }
                addc(col, r0 + 1, ((int) (s * 300 + T * 8)) % 3 == 0 ? '~' : '-', mix(GREEN, PINK, 0.25f + 0.6f * surge), clamp(amp * 0.6f * depthFade, 0, 1), 5);
            }
        }
        for (float[] m : met){
            float a = t - m[0]; if (a < 0 || a > m[5]) continue;
            for (int k = 0; k < 11; k++){
                float s = Math.max(0, a - k * 0.025f);
                put(m[1] * C + s * m[3], m[2] * R + s * m[4], k > 0 ? slopeChar(m[3] * cw, m[4] * ch, '-') : '*', 0xffffff, (1 - a / m[5]) * (1 - k / 11f), 8);
            }
        }
        for (int r = R - 6; r < R; r++) for (int c = 0; c < C; c++){
            float k = (r - (R - 6)) / 6f;
            if (h3(c, r, (int) (T * 2)) < 0.14f * k) put(c, r, '.', mix(0x2a7a50, 0xc8763a, 0.35f + 0.3f * sin(c * 0.05f)), 0.25f + 0.3f * k, 1);
        }
        float Ec = clamp(E, 0, 1.3f);
        bg(new float[]{0, 0.3f, 0.65f, 1},
           new int[]{0x02030a, mix(0x03050f, 0x0e0822, Ec * 0.5f), mix(0x030712, 0x041614, Ec * 0.45f), mix(0x060a16, 0x061612, Ec * 0.45f)});
        dim = sstep(0, 0.6f, t) * (1 - sstep(29.4f, 30, t));
        glow = 0.95f;
    }
}
