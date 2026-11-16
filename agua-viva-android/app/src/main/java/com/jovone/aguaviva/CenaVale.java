package com.jovone.aguaviva;

import android.graphics.Canvas;
import android.graphics.Path;

/** Vale: viagem ao entardecer em parallax, com água, veleiro e trem (40 s). Porte de vale.js. */
public class CenaVale extends Motor {

    @Override protected int cols() { return 84; }
    @Override public float loop() { return 40; }

    static final float[][] KEYS = {{0, 15.5f}, {6, 17.4f}, {13, 19.2f}, {16, 20.5f}, {26, 28.5f}, {31, 30.5f}, {35, 32.5f}, {40, 39.5f}};
    float[][] starsL, flies, smoke;

    @Override protected void init() {
        Rng R0 = new Rng(33);
        starsL = makeStars(150, 9);
        flies = new float[22][4];
        for (float[] f : flies){ f[0] = R0.next(); f[1] = R0.next(); f[2] = R0.next() * TAU; f[3] = R0.next(); }
        smoke = new float[16][2];
        for (int i = 0; i < 16; i++){ smoke[i][0] = i / 16f; smoke[i][1] = R0.next(); }
    }

    float hourAt(float t) {
        for (int i = 0; i < KEYS.length - 1; i++) if (t <= KEYS[i + 1][0]) return lerp(KEYS[i][1], KEYS[i + 1][1], (t - KEYS[i][0]) / (KEYS[i + 1][0] - KEYS[i][0]));
        return KEYS[KEYS.length - 1][1];
    }

    // estado do quadro usado pelas funções auxiliares e por paint()
    float sunX, dusk, day, off1, off2, RS;
    int HOR, SH, top, hor, m1, m2, fg;
    static final int EMBER = 0xff7a3c, ROSE = 0xff5a8a;

    int skyCol(float k, float c) {
        float near = exp(-pow((c - sunX) / (C * 0.38f), 2));
        return mix(mix(top, hor, pow(k, 1.4f)), mix(ROSE, EMBER, k), dusk * pow(k, 1.1f) * (0.35f + 0.65f * near));
    }
    float ridge1(float c) { return HOR - 3 - 17 * RS * (0.65f * ridged((c + off1) * 0.045f + 3) + 0.35f * fbm1((c + off1) * 0.1f + 9)); }
    float ridge2(float c) { return HOR - 1 - 7 * RS * fbm1((c + off2) * 0.07f + 11); }

    void pine(float c, int base, int hgt, int pc, int prio) {
        for (int j = 0; j < hgt; j++){
            int r = base - hgt + j, hw = (int) Math.floor(j * 0.6f);
            if (j == 0){ put(c, r, '^', pc, 1, prio); continue; }
            put(c - hw - 1, r, '/', pc, 1, prio); put(c + hw + 1, r, '\\', pc, 1, prio);
            for (int q = -hw; q <= hw; q++) put(c + q, r, q == 0 ? '|' : '#', pc, 1, prio);
        }
    }

    @Override protected void frame(float t, float T) {
        HOR = Math.round(R * 0.52f); SH = Math.round(R * 0.74f);
        final int RAIL = R - 9;
        float hour = hourAt(t) % 24;
        final float sunE = sin((hour - 6) / 12 * (float) Math.PI), moonE = sin((hour - 18) / 12 * (float) Math.PI);
        day = sstep(-0.12f, 0.3f, sunE);
        final float night = 1 - day;
        dusk = clamp(1 - Math.abs(sunE + 0.03f) / 0.32f, 0, 1);
        sunX = C * (0.06f + 0.88f * ((hour - 6) / 12));
        float moonX = C * (0.06f + 0.88f * (((hour - 18 + 24) % 24) / 12));
        float sunR = HOR - 2 - lift(sunE) * (HOR - 6), moonR = HOR - 2 - lift(moonE) * (HOR - 7);

        top = mix(0x04081a, 0x2a64c8, day); hor = mix(0x0c1834, 0x9ccaf0, day);

        for (int r = 0; r < HOR; r++){
            float k = (float) r / HOR;
            for (int c = 0; c < C; c++){
                float v = h2(c, r), dens = 0.06f + 0.16f * k + 0.08f * day;
                if (v < dens) put(c, r, v < dens * 0.35f ? '-' : '.', skyCol(k, c), 0.3f + 0.35f * k + 0.15f * day, 0);
            }
        }
        stars(starsL, HOR - 6, night * 0.95f, T, 1);
        for (float ts : new float[]{18.5f, 23.2f, 27.8f}){
            float a = t - ts; if (a < 0 || a > 0.9f) continue;
            float x0 = C * (0.25f + 0.5f * h1(ts * 10)), y0 = R * 0.05f;
            for (int k = 0; k < 8; k++){ float s = Math.max(0, a - k * 0.035f); put(x0 - s * 40, y0 + s * 13, k > 0 ? '/' : '*', 0xffffff, (1 - a / 0.9f) * (1 - k / 8f), 3); }
        }
        if (sunE > -0.25f){
            final float low = clamp(1 - sunE / 0.45f, 0, 1);
            disc(sunX, sunR, 3.4f, (c, r, d, dx, dy) -> put(c, r, letter(clamp(1.05f - d * 0.6f, 0, .99f), c * 13 + r), mix(mix(0xfffbe0, 0xffb347, d * 0.6f), 0xff4a24, low * (0.4f + 0.6f * d)), 1, 2));
            final int gc = mix(0xffd27a, EMBER, dusk);
            disc(sunX, sunR, 7.0f, (c, r, d, dx, dy) -> { if (d > 0.48f && h2(c, r) < 0.6f) addc(c, r, '.', gc, (1 - d) * 0.9f, 1); });
        }
        if (moonE > -0.2f) disc(moonX, moonR, 2.6f, (c, r, d, dx, dy) -> {
            float cr = noise2(dx * 3 + 1, dy * 3 + 4) > 0.6f ? 0.6f : 1;
            put(c, r, letter(clamp((1 - d * 0.4f) * cr, 0, .99f), c * 7 + r), scale(0xe2eaff, cr * (0.55f + 0.45f * night)), 1, 2);
        });

        int cloudLit = mix(mix(0x262e48, 0xf4f6ff, day), 0xff9a7a, dusk * 0.85f);
        for (int r = 2; r < HOR * 0.6f; r++) for (int c = 0; c < C; c++){
            float v = fbm2((c + T * 1.1f) * 0.042f, r * 0.2f + 3) - 0.07f * Math.abs(r - HOR * 0.3f) / 4;
            if (v > 0.55f){
                float d = clamp((v - 0.55f) / 0.25f, 0, 0.99f), under = clamp((r - HOR * 0.22f) / (HOR * 0.3f), 0, 1);
                put(c, r, ".,-~=+*%".charAt((int) (d * 8)), mix(cloudLit, scale(cloudLit, 0.55f), under * 0.6f), 0.55f + 0.45f * d, 3);
            }
        }
        if (hour > 16.6f && hour < 19.6f){
            float a = sstep(16.6f, 17.2f, hour) * (1 - sstep(19.0f, 19.6f, hour));
            float base = C + 10 - (hour - 16.6f) / 3.0f * (C + 30);
            for (int i = 0; i < 9; i++){
                int side = i == 0 ? 0 : ((i % 2 == 1) ? 1 : -1) * (int) Math.ceil(i / 2f);
                put(base + Math.abs(side) * 2.4f, R * 0.18f + side * 1.1f + sin(T * 3 + i) * 0.3f, ((int) (T * 8 + i)) % 2 == 1 ? 'v' : '-', 0x18101c, a, 9);
            }
        }

        off1 = T * 0.45f; off2 = T * 1.3f; RS = Math.max(1, R / 62f);
        int rim = mix(0xffd27a, EMBER, dusk);
        m1 = mix(mix(0x161e36, 0x6c82aa, day), mix(hor, EMBER, dusk * 0.4f), 0.25f);
        m2 = mix(0x0c1620, 0x3e6a4a, day);
        for (int c = 0; c < C; c++){
            float r1 = ridge1(c); int q1 = Math.round(r1);
            float sl1 = (ridge1(c + 1) - ridge1(c - 1)) * ch;
            float sunward = clamp(1 - Math.abs(c - sunX) / (C * 0.5f), 0, 1);
            put(c, q1, slopeChar(cw * 2, sl1, '_'), mix(m1, rim, 0.2f + 0.5f * dusk * sunward), 1, 4);
            for (int r = q1 + 1; r < HOR; r++){
                boolean snowy = r - q1 < 2 && r1 < HOR - 13 * RS;
                float v = h2((float) Math.floor(c + off1), r);
                put(c, r, snowy ? (r == q1 + 1 ? '^' : '*') : (v < 0.4f ? ':' : '.'), snowy ? mix(0x4a5a7a, 0xffffff, 0.35f + 0.65f * day) : scale(m1, 1 - 0.3f * (r - q1) / 12f), snowy ? 0.95f : 0.7f, 4);
            }
            float r2 = ridge2(c); int q2 = Math.round(r2);
            put(c, q2, slopeChar(cw * 2, (ridge2(c + 1) - ridge2(c - 1)) * ch, '_'), mix(m2, rim, 0.25f * dusk * sunward), 1, 5);
            for (int r = q2 + 1; r < HOR; r++){ float v = h2((float) Math.floor(c + off2) * 3, r); put(c, r, v < 0.35f ? '%' : (v < 0.7f ? ';' : ':'), m2, 0.85f, 5); }
        }
        int pineC = mix(0x050c08, 0x1e3a26, day);
        for (int wc = (int) Math.floor(off2) - 4; wc < off2 + C + 4; wc++){
            if (h1(wc * 11) > 0.2f) continue;
            float c = wc - off2;
            pine(c, Math.round(ridge2(c)), 2 + (int) (h1(wc * 13) * 4), pineC, 6);
        }

        float bx = C + 12 - ((T * 2.2f + 20) % (C + 34));
        int br = HOR + 2;
        int sail = mix(0x3a4258, 0xf2f4fa, 0.25f + 0.75f * day), hull = mix(0x1a120c, 0x7a4a2a, day);
        text(bx, br - 3, "   |\\  ", sail, 1, 8); text(bx, br - 2, "   | \\ ", sail, 1, 8); text(bx, br - 1, "   |__\\", sail, 1, 8); text(bx, br, " \\_____/", hull, 1, 8);
        if (night > 0.4f) put(bx + 3, br - 4, '*', 0xffd56a, night, 9);

        int waterTint = mix(0x06101e, 0x1a3a5a, day);
        for (int r = HOR; r < SH; r++){
            int d = r - HOR;
            float persp = (float) d / (SH - HOR);
            float mr = HOR - 1 - d * (HOR - 2) / (float) (SH - HOR) * 0.55f;
            for (int c = 0; c < C; c++){
                float w = 0.6f * sin(c * 0.5f * (1 - 0.45f * persp) + T * 2.2f + d * 1.3f) + 0.4f * sin(c * 1.25f - T * 1.7f + d * 2.1f + sin(c * 0.07f + T * 0.3f) * 2);
                char k = w > 0.55f ? '~' : (w > 0.05f ? '-' : (w < -0.7f ? '_' : (h2(c, r + (int) (T * 3)) < 0.25f ? '.' : 0)));
                if (k == 0) continue;
                int rgb = skyCol(clamp(mr / HOR, 0, 1), c);
                if (mr >= ridge2(c)) rgb = scale(m2, 0.9f);
                else if (mr >= ridge1(c)) rgb = mix(m1, waterTint, 0.3f);
                rgb = mix(rgb, waterTint, 0.35f + 0.25f * persp);
                put(c, r, k, rgb, 0.45f + (w > 0.55f ? 0.4f : 0) + 0.1f * persp, 3);
            }
            path(r, persp, sunX, sunE, mix(0xfff2b0, EMBER, dusk), T);
            path(r, persp, moonX, moonE, 0xdfe8ff, T);
        }
        String[] refl = {"   | / ", "   |/  "};
        float[] ra = {0.35f, 0.2f};
        for (int i = 0; i < 2; i++) for (int k = 0; k < refl[i].length(); k++) if (refl[i].charAt(k) != ' ') put(bx + k + Math.round(sin(T * 3 + i) * 0.6f), br + 1 + i, refl[i].charAt(k), sail, ra[i], 8);
        for (int c = 0; c < C; c++){ float f = sin(c * 0.3f + T * 1.8f) + sin(c * 0.11f - T * 0.9f); if (f > 0.6f) put(c, SH - 1, '~', 0xdcebff, 0.35f + 0.3f * day, 7); }

        float off3 = T * 4.2f;
        fg = mix(0x04070a, 0x24361e, day * 0.8f);
        for (int r = SH; r < R; r++) for (int c = 0; c < C; c++){
            float v = h2((float) Math.floor(c + off3), r);
            if (r < RAIL && v < 0.5f) put(c, r, ",.;'".charAt(Math.min(3, (int) (v * 8))), fg, 0.85f, 10);
        }
        int pole = mix(0x1a1410, 0x5a4030, day), wire = mix(0x20242c, 0x6a7080, day);
        for (int wc = (int) Math.floor(off3) - 10; wc < off3 + C + 10; wc++){
            float c = wc - off3;
            if (Math.floorMod(wc, 26) == 0){
                for (int r = RAIL - 9; r < RAIL; r++) put(c, r, '|', pole, 1, 12);
                text(c - 1, RAIL - 10, "-T-", pole, 1, 12);
                for (int k = 1; k < 26; k++){ float sag = sin(k / 26f * (float) Math.PI) * 1.6f; put(c + k, RAIL - 10 + sag, '_', wire, 0.7f, 11); }
            }
            if (h1(wc * 7) < 0.045f){
                int hgt = 7 + (int) (h1(wc * 3) * 6);
                for (int j = 0; j < hgt; j++){
                    int r = RAIL - hgt + j, hw = (int) Math.floor(j * 0.55f);
                    if (j == 0){ put(c, r, '^', fg, 1, 13); continue; }
                    put(c - hw - 1, r, '/', fg, 1, 13); put(c + hw + 1, r, '\\', fg, 1, 13);
                    for (int q = -hw; q <= hw; q++) put(c + q, r, q == 0 ? '|' : '#', scale(fg, 0.8f), 1, 13);
                }
            }
        }
        int steel = mix(0x3a3e48, 0x9aa2b2, 0.3f + 0.7f * day), gravel = mix(0x2a1e14, 0x6a5038, day);
        for (int c = 0; c < C; c++){
            int wc = (int) Math.floor(c + off3);
            put(c, RAIL, Math.floorMod(wc, 3) == 0 ? '#' : '=', steel, 0.9f, 14);
            put(c, RAIL + 1, h1(wc) < 0.5f ? ':' : '.', gravel, 0.6f, 14);
            for (int r = RAIL + 2; r < R; r++) if (h2(wc, r) < 0.35f) put(c, r, h2(wc, r) < 0.12f ? ',' : '.', fg, 0.45f, 14);
        }

        float PERIOD = 20, ph = T % PERIOD, speed = 16;
        float tx = C + 4 - ph * speed;
        int cars = 4, carW = 11, trainLen = 10 + cars * carW;
        int body = mix(0x3a1a1a, 0xb8342a, 0.35f + 0.65f * day), trim = mix(0x2a2a30, 0xd8d2c4, 0.3f + 0.7f * day);
        int win = night > 0.35f ? 0xffd56a : mix(0x5a7a9a, 0xbfe0ff, day);
        if (tx < C + 2 && tx + trainLen > -2){
            text(tx, RAIL - 3, "  _||___ ", trim, 1, 20);
            text(tx, RAIL - 2, " /  [] |", body, 1, 20);
            text(tx, RAIL - 1, "'-o--o--'", trim, 1, 20);
            put(tx + 4, RAIL - 2, '[', win, 1, 21); put(tx + 5, RAIL - 2, ']', win, 1, 21);
            for (int k = 0; k < cars; k++){
                float x = tx + 9 + k * carW;
                text(x, RAIL - 3, "_________ ", trim, 1, 20);
                text(x - 1, RAIL - 2, "-|        |", body, 1, 20);
                for (int w = 0; w < 3; w++){ put(x + 1 + w * 3, RAIL - 2, '[', win, 1, 21); put(x + 2 + w * 3, RAIL - 2, ']', win, 1, 21); }
                text(x, RAIL - 1, "'-o----o-'", trim, 1, 20);
            }
            if (night > 0.35f) for (int k = 1; k < 12; k++) addc(tx - k, RAIL - 2, '-', 0xfff0b0, night * (1 - k / 12f) * 0.7f, 19);
            int smk = mix(0x6a6e78, 0xe8eaf0, day);
            for (float[] s : smoke){
                float a = (s[0] + T * 0.9f) % 1;
                float x = tx + 3 + a * 16 + sin(a * 7 + s[1] * 9) * 1.2f, y = RAIL - 4 - a * 6;
                put(x, y, a < 0.25f ? 'O' : (a < 0.55f ? 'o' : '.'), smk, (1 - a) * 0.75f, 18);
            }
        }
        if (night > 0.3f) for (float[] f : flies){
            float x = f[0] * C + 6 * sin(T * 0.3f + f[2]) + 3 * noise1(T * 0.5f + f[3] * 9);
            float y = SH + 1 + f[1] * (RAIL - SH - 3) + 1.5f * sin(T * 0.7f + f[2] * 2);
            float blink = Math.max(0, sin(T * 2.3f + f[2] * 5));
            if (blink > 0.1f) addc(x, y, blink > 0.7f ? '*' : '.', 0xd8ff6a, (night - 0.3f) * 1.4f * blink, 16);
        }

        int bTop = mix(0x000004, 0x0b2448, day), bHor = mix(mix(0x02060f, 0x25496e, day), 0x6a2c14, dusk * 0.8f);
        float hy = (float) HOR / R, sy = (float) SH / R;
        bg(new float[]{0, hy * 0.7f, hy, hy + 0.002f, sy, sy + 0.002f, 1},
           new int[]{bTop, mix(bTop, bHor, 0.5f), bHor, scale(bHor, 0.45f), scale(bTop, 0.4f), 0x020304, 0});
        dim = 1; glow = 0.72f;
    }

    static float lift(float e) { return e > 0 ? pow(e, 0.45f) : e; }

    void path(int r, float persp, float x, float e, int rgb, float T) {
        if (e < -0.04f) return;
        float width = 1.2f + persp * 6;
        for (int c = (int) Math.floor(x - width - 3); c <= x + width + 3; c++){
            float jit = sin(r * 1.7f + T * 3 + c * 0.4f) * (1 + persp * 2);
            if (Math.abs(c - x + jit) < width && h3(c, r, (int) (T * 8)) < 0.55f) put(c, r, Math.abs(c - x + jit) < width * 0.4f ? '=' : '~', rgb, 0.95f, 7);
        }
    }

    @Override protected void paint(Canvas cv, float dm) {
        Path pm = new Path(), ph = new Path();
        pm.moveTo(0, HOR * ch); ph.moveTo(0, HOR * ch);
        for (int c = -1; c <= C + 1; c++){
            float x = (c + 0.5f) * cw;
            pm.lineTo(x, (ridge1(c) + 0.5f) * ch);
            ph.lineTo(x, (ridge2(c) + 0.5f) * ch);
        }
        pm.lineTo(W, HOR * ch); pm.close();
        ph.lineTo(W, HOR * ch); ph.close();
        fillPath(cv, pm, m1, 0.42f * dm);
        fillPath(cv, ph, m2, 0.38f * dm);
        Path sh = new Path();
        sh.moveTo(0, SH * ch); sh.lineTo(W, SH * ch); sh.lineTo(W, H); sh.lineTo(0, H); sh.close();
        fillPath(cv, sh, fg, 0.35f * dm);
    }
}
