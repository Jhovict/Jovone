package com.jovone.aguaviva;

/** Árvore de Natal que se monta sozinha, girando (21 s). Porte de natal.js. */
public class CenaNatal extends Motor {

    @Override protected int cols() { return 110; }
    @Override public float loop() { return 21; }

    static final String WORD = "FELIZNATALBOASFESTASJOVONE", GREETING = "FELIZ NATAL 2026";
    static final float[][] TIERS = {{0.00f, 0.40f, 0.00f, 0.30f}, {0.30f, 0.70f, 0.22f, 0.45f}, {0.60f, 1.00f, 0.24f, 0.60f}};
    static final float T_END = 19.4f;

    // pontos da copa: h, a, r, u, k, id, neve, interno
    float[] ph, pa, pr, pu; int[] pk, pid; boolean[] psnow, pinner;
    float[][] lights; int[] lightInk;
    float[][] orns; int[] ornInk;
    float[][] gifts; int[] giftBox, giftRib;
    float[][][] gpts;
    float[][] snow;

    @Override protected void init() {
        Rng R0 = new Rng(7);
        int[] N = {5200, 8400, 12400};
        int tot = N[0] + N[1] + N[2];
        ph = new float[tot]; pa = new float[tot]; pr = new float[tot]; pu = new float[tot]; pk = new int[tot]; pid = new int[tot]; psnow = new boolean[tot]; pinner = new boolean[tot];
        int n = 0;
        for (int k = 0; k < 3; k++){
            float top = TIERS[k][0], bot = TIERS[k][1], r0 = TIERS[k][2], rmax = TIERS[k][3];
            for (int i = 0; i < N[k]; i++, n++){
                float u = pow(R0.next(), k == 0 ? 0.85f : 0.75f);
                float a = R0.next() * TAU;
                float hb = top + (bot - top) * u;
                float lobe = 1 + 0.12f * sin(a * 9 + k * 1.7f) * u * u;
                float droop = 0.045f * sin(a * 9 + k * 1.7f) * pow(u, 4);
                float rr = rmax * (r0 + (1 - r0) * pow(u, k == 0 ? 1.15f : 1)) * lobe * (float) Math.sqrt(0.82f + 0.18f * R0.next());
                ph[n] = hb + droop; pa[n] = a; pr[n] = rr; pu[n] = u; pk[n] = k; pid[n] = i * 3 + k;
                psnow[n] = R0.next() < 0.035f && u > 0.6f; pinner[n] = R0.next() < 0.18f;
            }
        }
        int[] inks = {0xffd56a, 0xffb347, 0xfff2c8, 0xff6a4a};
        lights = new float[176][4]; lightInk = new int[176];
        for (int i = 0; i < 176; i++){ float s = i / 176f; lights[i][0] = s; lights[i][1] = 0.97f - s * 0.92f; lights[i][2] = s * TAU * 6.5f; lightInk[i] = inks[(int) (R0.next() * 4) % 4]; lights[i][3] = R0.next() * TAU; }
        int[] oinks = {0xff2a2a, 0xe01818, 0xffcc33, 0xff3a5a};
        orns = new float[46][4]; ornInk = new int[46];
        for (int i = 0; i < 46; i++){ orns[i][0] = 0.12f + 0.84f * pow(R0.next(), 0.8f); orns[i][1] = R0.next() * TAU; orns[i][2] = 6.6f + R0.next() * 3.8f; ornInk[i] = oinks[(int) (R0.next() * 4) % 4]; orns[i][3] = 0.8f + 0.6f * R0.next(); }
        gifts = new float[][]{{0.3f, 0.40f, 0.075f, 0.09f, 10.6f}, {1.6f, 0.46f, 0.06f, 0.11f, 10.9f}, {2.7f, 0.38f, 0.08f, 0.07f, 11.2f}, {3.9f, 0.44f, 0.055f, 0.10f, 11.5f}, {5.0f, 0.42f, 0.07f, 0.08f, 11.8f}, {5.8f, 0.50f, 0.05f, 0.06f, 12.1f}};
        giftBox = new int[]{0x2a4cff, 0xff2a3a, 0xffcc33, 0xff5ab4, 0x2fd2a0, 0xff2a3a};
        giftRib = new int[]{0xffd23a, 0xffffff, 0xff2a3a, 0xffffff, 0xff2a3a, 0xffd23a};
        gpts = new float[gifts.length][700][5];
        for (int g = 0; g < gifts.length; g++){
            Rng Rg = new Rng(100 + g);
            for (int i = 0; i < 700; i++){
                int face = (int) (Rg.next() * 5) % 5; float p = Rg.next() * 2 - 1, q = Rg.next() * 2 - 1, x, y, z;
                if (face == 0){ x = p; y = 1; z = q; } else if (face == 1){ x = 1; y = q; z = p; } else if (face == 2){ x = -1; y = q; z = p; } else if (face == 3){ x = p; y = q; z = 1; } else { x = p; y = q; z = -1; }
                gpts[g][i][0] = x; gpts[g][i][1] = y; gpts[g][i][2] = z; gpts[g][i][3] = (Math.abs(x) < 0.16f || Math.abs(z) < 0.16f) ? 1 : 0; gpts[g][i][4] = (int) (Rg.next() * 1e6f);
            }
        }
        snow = new float[700][5];
        for (float[] s : snow){ s[0] = R0.next(); s[1] = R0.next(); s[2] = 0.6f + 2.2f * R0.next(); s[3] = R0.next() * TAU; s[4] = R0.next(); }
    }

    float rot, cp, sp, Sc, cxm, baseRow;
    final float[] P = new float[3];
    void proj(float x, float y, float z) {
        float cr = cos(rot), sr = sin(rot);
        float xr = x * cr - z * sr, zr = x * sr + z * cr;
        float y1 = y * cp + zr * sp, z1 = -y * sp + zr * cp;
        P[0] = cxm + xr * Sc * asp; P[1] = baseRow - y1 * Sc; P[2] = z1;
    }
    static int zp(float z) { return 1000 + Math.round(z * 800); }
    static float ramp(float t, float a, float b) { return clamp((t - a) / (b - a), 0, 1); }
    static float ease(float x) { return 1 - pow(1 - x, 3); }

    float radiusAt(float h) {
        float m = 0;
        for (float[] T4 : TIERS){ float u = (h - T4[0]) / (T4[1] - T4[0]); if (u >= 0 && u <= 1) m = Math.max(m, T4[3] * (T4[2] + (1 - T4[2]) * u)); }
        return m;
    }

    @Override protected void frame(float t, float T) {
        int groundRow = Math.round(R * 0.86f);
        Sc = Math.min(R * 0.6f, C / (2 * 0.66f * asp));
        cxm = C * 0.5f; baseRow = groundRow - Sc * 0.075f;
        rot = T * 0.26f;
        cp = cos(0.16f); sp = sin(0.16f);
        final float end = 1 - ramp(t, T_END, T_END + 1.0f);
        int nW = WORD.length();

        for (float[] s : snow){
            if (s[4] > 0.75f) continue;
            float y = ((s[1] * R + T * s[2]) % R + R) % R, x = s[0] * C + sin(T * 0.6f + s[3]) * 1.5f;
            put(x, y, s[4] < 0.06f ? '+' : '.', 0xebf0ff, 0.35f + 0.4f * s[4], 1);
        }
        float g = ease(ramp(t, 0, 1));
        if (g > 0) for (int r = groundRow; r < R; r++) for (int c = 0; c < C; c++){
            float v = h2(c, r);
            if (v < 0.75f * g) put(c, r, v < 0.06f ? '+' : WORD.charAt(Math.floorMod(c * 7 + r * 13, nW)), mix(0x1a2a6a, 0x4a5aa8, h2(r, c) * 0.6f), 0.22f + 0.25f * (r - groundRow) / (float) (R - groundRow), 10);
        }
        float tg = ease(ramp(t, 0.6f, 1.3f));
        if (tg > 0){
            float th = 0.10f * tg;
            for (int i = 0; i < 900; i++){
                float a = h1(i) * TAU, y = -0.075f + h1(i + 7) * (th + 0.075f);
                proj(cos(a) * 0.05f, y, sin(a) * 0.05f);
                float lit = 0.5f + 0.5f * cos(a + rot + 2.2f);
                put(P[0], P[1], WORD.charAt(i % nW), mix(0x4a2410, 0xc87a3a, lit), end, zp(P[2]));
            }
        }

        float grow = ramp(t, 1.2f, 6.0f);
        float reveal = 1 - ease(grow) * 1.02f;
        final float Lx = -0.55f, Ly = 0.45f, Lz = 0.70f;
        if (grow > 0) for (int i = 0; i < ph.length; i++){
            if (ph[i] < reveal) continue;
            float fresh = clamp((ph[i] - reveal) / 0.06f, 0, 1);
            float y = (1 - ph[i]) + 0.08f;
            float rr = pinner[i] ? pr[i] * 0.6f : pr[i];
            proj(cos(pa[i]) * rr, y, sin(pa[i]) * rr);
            float ca = cos(pa[i] + rot), sa = sin(pa[i] + rot);
            float lam = clamp(ca * 0.85f * Lx + 0.5f * Ly + sa * 0.85f * Lz, 0, 1);
            float b = 0.3f + 0.7f * lam;
            if (pu[i] > 0.9f) b *= 0.6f;
            int k = pk[i];
            if (k > 0){ float above = TIERS[k - 1][1]; if (ph[i] > above - 0.01f && ph[i] < above + 0.09f) b *= 0.3f + 0.7f * clamp((ph[i] - above) / 0.09f, 0, 1); }
            if (pinner[i]) b *= 0.45f;
            int rgb = mix(0x0a3a16, 0x62ff74, b);
            char chr = WORD.charAt(pid[i] % nW);
            if (psnow[i] && b > 0.4f){ rgb = 0xeef6ff; chr = (pid[i] % 3 != 0) ? '*' : 'o'; }
            if (fresh < 1) rgb = mix(0xffffff, rgb, fresh);
            put(P[0], P[1], chr, rgb, end * (0.7f + 0.3f * b), zp(P[2]));
        }

        float lt = ramp(t, 6.0f, 10.0f);
        int lit = 0;
        for (int i = 0; i < lights.length; i++){
            float[] L0 = lights[i];
            if (L0[0] > lt || L0[1] < reveal) continue;
            float rr = radiusAt(L0[1]) * 1.02f;
            proj(cos(L0[2]) * rr, (1 - L0[1]) + 0.08f, sin(L0[2]) * rr);
            float tw = 0.55f + 0.45f * sin(T * 4 + L0[3]);
            boolean front = P[2] > -0.05f;
            put(P[0], P[1], tw > 0.75f ? '*' : 'o', lightInk[i], end * (front ? tw : tw * 0.35f), zp(P[2]) + 5);
            if (front && tw > 0.8f) addc(P[0], P[1] - 1, '\'', lightInk[i], 0.35f * tw * end, zp(P[2]) + 5);
            lit++;
        }
        if (lt > 0) for (int i = 0; i < 900; i++){
            float s = i / 900f; if (s > lt) break;
            float h = 0.97f - s * 0.92f; if (h < reveal) continue;
            float rr = radiusAt(h), a = s * TAU * 6.5f;
            proj(cos(a) * rr, (1 - h) + 0.08f, sin(a) * rr);
            if (P[2] > -0.05f) put(P[0], P[1], '~', 0xc8a040, 0.55f * end, zp(P[2]) + 3);
        }
        for (int i = 0; i < orns.length; i++){
            final float[] o = orns[i];
            float k = ease(clamp((t - o[2]) / 0.35f, 0, 1));
            if (k <= 0 || o[0] < reveal) continue;
            float rr = radiusAt(o[0]) * 0.98f;
            proj(cos(o[1]) * rr, (1 - o[0]) + 0.08f, sin(o[1]) * rr);
            if (P[2] < -0.1f) continue;
            final int ink = ornInk[i], zz = zp(P[2]) + 10;
            float rad = (0.9f + 0.5f * o[3]) * k * (0.75f + 0.35f * P[2]);
            disc(P[0], P[1], rad, (cc, r2, d, dx, dy) -> {
                float hl = clamp(-dx * 0.6f - dy * 0.7f + 0.4f, 0, 1);
                put(cc, r2, d < 0.45f && hl > 0.6f ? 'o' : '@', mix(scale(ink, 0.55f), 0xfff0dc, hl * hl * 0.7f), end, zz);
            });
        }

        float stt = ramp(t, 10.2f, 11.0f);
        if (stt > 0 && reveal <= 0.02f){
            proj(0, 1.08f, 0);
            float sc0 = P[0], sr0 = P[1];
            float k = ease(stt), pulse = 0.8f + 0.2f * sin(T * 5);
            String[] STAR = {"  .  ", " *+* ", "*+#+*", " *+* ", " / \\ "};
            for (int i = 0; i < STAR.length; i++) for (int j = 0; j < STAR[i].length(); j++) if (STAR[i].charAt(j) != ' ') put(sc0 - 2 + j, sr0 - 3 + i, STAR[i].charAt(j), mix(0xfff2b0, 0xffcc33, i / 4f), k * end, 3000);
            for (int nn = 0; nn < 22; nn++){
                float a = nn / 22f * TAU + T * 0.15f, len = (8 + 10 * h1(nn)) * k;
                for (float s = 3; s < len; s += 0.9f){
                    addc(sc0 + cos(a) * s * asp, sr0 - 1 + sin(a) * s, slopeChar(cos(a) * cw, sin(a) * ch, '-'), 0xffe08a, 0.45f * (1 - s / len) * pulse * end, 2900);
                }
            }
        }
        for (int gi = 0; gi < gifts.length; gi++){
            float[] gf = gifts[gi];
            float k = ease(clamp((t - gf[4]) / 0.45f, 0, 1));
            if (k <= 0) continue;
            for (float[] p : gpts[gi]){
                float x = p[0], y = p[1], z = p[2];
                float X = cos(gf[0]) * gf[1] + x * gf[2], Z = sin(gf[0]) * gf[1] + z * gf[2], Y = -0.075f + (y + 1) * 0.5f * gf[3] * k;
                proj(X, Y, Z);
                float off = x == 1 ? 0 : x == -1 ? (float) Math.PI : z == 1 ? (float) Math.PI / 2 : (float) -Math.PI / 2;
                float shade = y == 1 ? 1 : 0.55f + 0.35f * cos(rot + gf[0] + off - 1);
                boolean rib = p[3] > 0.5f;
                put(P[0], P[1], rib ? '#' : WORD.charAt(((int) p[4]) % nW), scale(rib ? giftRib[gi] : giftBox[gi], clamp(shade, 0.3f, 1)), end, zp(P[2]) + 2);
            }
        }
        float tx = ramp(t, 12.6f, 15.6f);
        if (tx > 0){
            int n = (int) Math.floor(tx * GREETING.length());
            String s = GREETING.substring(0, n) + (n < GREETING.length() && ((int) (T * 3)) % 2 == 1 ? "_" : "");
            int c0 = Math.round(cxm - (GREETING.length() * 2 - 1) / 2f), r0 = groundRow + 2;
            for (int c = c0 - 3; c < c0 + GREETING.length() * 2 + 3; c++) put(c, r0, ' ', 0, 1, 3500);
            for (int i = 0; i < s.length(); i++) if (s.charAt(i) != ' ') put(c0 + i * 2, r0, s.charAt(i), 0xffcc55, end, 3600);
        }
        for (float[] s : snow){
            if (s[4] <= 0.75f) continue;
            float y = ((s[1] * R + T * s[2] * 1.4f) % R + R) % R, x = s[0] * C + sin(T * 0.8f + s[3]) * 2;
            put(x, y, s[4] > 0.97f ? '*' : (s[4] > 0.88f ? '+' : '.'), 0xffffff, 0.55f + 0.4f * s[4], 4000);
        }
        bg(new float[]{0, 0.8f, 0.86f, 1}, new int[]{0x010206, 0x040610, 0x060a1e, 0x0a0e28});
        dim = sstep(0, 0.4f, t) * (1 - sstep(20.4f, 21, t));
        glow = 0.85f;
    }
}
