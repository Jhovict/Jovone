package com.jovone.aguaviva;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.Typeface;

/**
 * Água-viva ASCII — o mesmo cálculo da versão web, desenhado em Canvas.
 * Linha do tempo (24,2 s em loop): montagem → clarão → tentáculos →
 * troca de paleta a cada batida → cintilações → fogos → escurece → recomeça.
 */
public final class Renderer {

    /* ---------- constantes ---------- */
    static final float LOOP = 24.2f, TAU = (float) (Math.PI * 2);
    static final int PETALS = 8, LAPPETS = 16;
    static final float CURL = 1.75f, BELL_R = 0.92f, BELL_H = 1.2f;
    static final float FLARE = 0.12f, RIM_LAG = 0.20f, SPIN = 0.35f, PITCH = -0.13f;
    static final int N_TENT = 14;
    static final float TENT_LEN = 2.7f, TENT_LAG = 0.25f, TENT_T0 = 3.0f, TENT_DROP = 1.6f;
    static final int N_ARMS = 4;
    static final float ARM_LEN = 1.95f, ARM_T0 = 3.3f, ARM_DROP = 1.8f;
    static final float BEAT0 = 0.2f, PERIOD = 2.0f, LAST_BEAT = 18.2f;
    static final float COLOUR_FROM = 6.2f;
    static final float GLINT_FROM = 10.2f, GLINT_LIFE = 1.6f;
    static final int N_GLINTS = 28;
    static final float[] T_FINALE = {16.2f, 18.2f};
    static final int BURST_SPARKS = 90;
    static final float BURST_SPEED = 4.2f, DRAG = 1.7f, TAIL_GAP = 0.035f;
    static final int TAILS = 5;
    static final float OUTRO = 19.6f;
    static final int NU = 46, NTH = 168;

    static final int[][] PALETTES = {
            {0x2445d8, 0xeef3ff, 0x7d6cff, 0x9fb2ff},
            {0x2fc9dc, 0x9a5cff, 0xff4f9e, 0x6fd3e0},
            {0xff3fb4, 0x5468ff, 0x36dcff, 0xe07ad0},
            {0x3ee070, 0xf2e640, 0xff9a22, 0x44c9a4},
            {0xff4a1c, 0xffc22e, 0xa674ff, 0xe8a248},
            {0x4a5cff, 0x3fe2ff, 0xffd52e, 0x8c74e8},
            {0xff2424, 0xffd400, 0xefe6e6, 0xc86a78},
            {0x2fd2ff, 0xc4d2e2, 0xff3f86, 0xc27fb4},
    };
    static final int[] SPARK_INK = {0xffffff, 0xffe066, 0xff5a5a, 0x5ad8ff, 0xb78cff, 0x7dff9a, 0xff8de0};
    static final char[][] RAMP = {
            ".`'".toCharArray(), ":;,".toCharArray(), "il!1|".toCharArray(), "rtcz=+<>".toCharArray(),
            "unxvjf{}[]".toCharArray(), "aeosQ%".toCharArray(), "$8B0&#".toCharArray(), "@#$8B%".toCharArray()};

    /* ---------- layout ---------- */
    int W, H, COLS, ROWS;
    float cw, ch, ts, S, Sx, Sy, OXc, OYr;
    final float D = 7f;

    /* ---------- grade com z-buffer ---------- */
    float[] zb;
    char[] chr;
    int[] rgb;
    float[] alp;
    int[] used;
    int nUsed;

    final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    final Paint gPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    final Paint blit = new Paint(Paint.FILTER_BITMAP_FLAG);
    final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    Bitmap glow;
    Canvas gc;
    final Rect src = new Rect(), dst = new Rect(), dst2 = new Rect();
    final char[] one = new char[1];
    static final int GLOW_DIV = 5;

    /* dados fixos */
    final float[][] start = new float[NU * NTH][3];
    final float[][][] glint;
    final float[] glintT0;
    final Spark[] sparks;
    final float[][] stars = new float[150][5];

    static final class Spark {
        float t0, life, seed;
        float[] start = new float[3], vel = new float[3];
        int ink;
    }

    public Renderer() {
        Typeface mono = Typeface.MONOSPACE;
        paint.setTypeface(mono);
        paint.setTextAlign(Paint.Align.CENTER);
        gPaint.setTypeface(mono);
        gPaint.setTextAlign(Paint.Align.CENTER);
        bgPaint.setTypeface(mono);
        blit.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.ADD));

        Rng r = new Rng(7);
        for (int i = 0; i < start.length; i++) {
            float ang = r.next() * TAU, rad = (float) Math.pow(r.next(), 0.6);
            start[i][0] = 0.5f + (float) Math.cos(ang) * rad * 0.42f + (r.next() - .5f) * .1f;
            start[i][1] = 0.30f + (float) Math.sin(ang) * rad * 0.22f + (r.next() - .5f) * .1f;
            start[i][2] = r.next() * 0.9f;
        }

        int ng = 0;
        for (float tb = GLINT_FROM; tb <= LAST_BEAT + 1e-4f; tb += PERIOD) ng++;
        glintT0 = new float[ng];
        glint = new float[ng][N_GLINTS][2];
        for (int n = 0; n < ng; n++) {
            glintT0[n] = GLINT_FROM + n * PERIOD + 0.3f;
            Rng g = new Rng(14 + n * 7);
            for (int i = 0; i < N_GLINTS; i++) { glint[n][i][0] = g.next(); glint[n][i][1] = g.next(); }
        }

        Rng R = new Rng(12);
        sparks = new Spark[T_FINALE.length * BURST_SPARKS];
        int si = 0;
        float[] P = new float[4], centre = new float[3];
        for (float tb : T_FINALE) {
            float t0 = tb + 0.30f;
            pose(t0, P);
            carry(0, 0.30f, 0, P, centre);
            float[][] dirs = fibSphere(BURST_SPARKS);
            for (int i = dirs.length - 1; i > 0; i--) { int j = (int) (R.next() * (i + 1)); float[] tmp = dirs[i]; dirs[i] = dirs[j]; dirs[j] = tmp; }
            for (float[] d : dirs) {
                float wx = d[0], wy = d[1] + 0.10f, wz = -Math.abs(d[2]) * 0.55f;
                float l = (float) Math.sqrt(wx * wx + wy * wy + wz * wz);
                wx /= l; wy /= l; wz /= l;
                float sp = BURST_SPEED * (0.45f + 0.55f * R.next());
                Spark s = new Spark();
                s.t0 = t0;
                s.start[0] = centre[0] + 0.3f * wx; s.start[1] = centre[1] + 0.3f * wy; s.start[2] = centre[2] + 0.3f * wz;
                s.vel[0] = wx * sp; s.vel[1] = wy * sp; s.vel[2] = wz * sp;
                s.ink = SPARK_INK[(int) (R.next() * SPARK_INK.length)];
                s.life = 1.4f + 0.8f * R.next();
                s.seed = R.next() * TAU;
                sparks[si++] = s;
            }
        }

        Rng st = new Rng(3);
        for (float[] s : stars) { s[0] = st.next(); s[1] = st.next(); s[2] = 0.004f + 0.01f * st.next(); s[3] = st.next() * TAU; s[4] = st.next() < 0.12f ? 1 : 0; }
    }

    /* ============================================================ layout */
    public void setSize(int w, int h) {
        if (w == W && h == H) return;
        W = w; H = h;
        COLS = w > h ? 110 : 72;
        cw = (float) W / COLS;
        paint.setTextSize(100);
        float adv = paint.measureText("M") / 100f;
        ts = cw / adv;
        ch = ts * 0.92f;
        ROWS = (int) Math.ceil(H / ch);
        paint.setTextSize(ts);
        gPaint.setTextSize(ts / GLOW_DIV);
        S = Math.min(W * 0.27f, H * 0.135f);
        Sx = S / cw; Sy = S / ch;
        OXc = COLS * 0.5f;
        OYr = (H * 0.37f) / ch;
        int n = COLS * ROWS;
        zb = new float[n]; chr = new char[n]; rgb = new int[n]; alp = new float[n]; used = new int[n];
        nUsed = 0;
        if (glow != null) glow.recycle();
        glow = Bitmap.createBitmap(Math.max(1, W / GLOW_DIV), Math.max(1, H / GLOW_DIV), Bitmap.Config.ARGB_8888);
        gc = new Canvas(glow);
    }

    /* ============================================================ matemática */
    static float clamp(float x, float a, float b) { return x < a ? a : (x > b ? b : x); }
    static float smooth(float x) { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); }
    static float sstep(float a, float b, float x) { return smooth((x - a) / (b - a)); }
    static float lerp(float a, float b, float k) { return a + (b - a) * k; }
    static float sin(float x) { return (float) Math.sin(x); }
    static float cos(float x) { return (float) Math.cos(x); }

    static float hash(int i) {
        i = (i ^ 61 ^ (i >>> 16)) * 9;
        i ^= i >>> 4;
        i *= 0x27d4eb2d;
        i ^= i >>> 15;
        return (i & 0xffffffffL) / 4294967296f;
    }

    static final class Rng {
        int s;
        Rng(int seed) { s = seed == 0 ? 1 : seed; }
        float next() { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s & 0xffffffffL) / 4294967296f; }
    }

    static float[][] fibSphere(int n) {
        float[][] out = new float[n][3];
        double ga = Math.PI * (3 - Math.sqrt(5));
        for (int i = 0; i < n; i++) {
            float y = 1 - 2f * (i + .5f) / n, r = (float) Math.sqrt(1 - y * y);
            out[i][0] = (float) Math.cos(ga * i) * r; out[i][1] = y; out[i][2] = (float) Math.sin(ga * i) * r;
        }
        return out;
    }

    static char letter(float b, int id) {
        char[] g = RAMP[(int) clamp(b * RAMP.length, 0, RAMP.length - 1)];
        return g[(int) (hash(id) * g.length) % g.length];
    }

    static char slopeChar(float dx, float dy, char flat) {
        float a = (float) Math.abs(Math.atan2(dy, dx));
        if (a > Math.PI / 2) a = (float) Math.PI - a;
        if (a > 1.18f) return '|';
        if (a < 0.40f) return flat;
        return (dx * dy < 0) ? '/' : '\\';
    }

    static int beatIndex(float t) {
        if (t < BEAT0) return -1;
        return Math.min((int) Math.floor((t - BEAT0) / PERIOD), Math.round((LAST_BEAT - BEAT0) / PERIOD));
    }

    static float squeeze(float t) {
        if (t < BEAT0) return 0;
        int k = beatIndex(t);
        float x = t - (BEAT0 + k * PERIOD);
        float c = x < 0.3f ? sin(x / 0.3f * (float) Math.PI / 2) : (float) Math.exp(-(x - 0.3f) * 2.0f);
        return c * sstep(1.0f, 2.4f, t);
    }

    static float dropped(float t, float t0, float dur) {
        float g = clamp((t - t0) / dur, 0, 1);
        return 1 - (1 - g) * (1 - g);
    }

    static int paletteAt(float t, float d) {
        int n = 0;
        for (int k = 0; ; k++) {
            float tb = COLOUR_FROM + k * PERIOD;
            if (tb > LAST_BEAT + 1e-4f) break;
            if (t >= tb + d * 0.32f) n = k + 1;
        }
        return n;
    }

    /* pose do corpo: P = {cos roll, sin roll, bob, bx} */
    static void pose(float tt, float[] P) {
        float roll = 0.32f * sin(TAU * (tt - 1) / 13f);
        float c = squeeze(tt);
        P[0] = cos(roll); P[1] = sin(roll);
        P[2] = 0.10f * c + 0.05f * sin(0.6f * tt) - 0.05f;
        P[3] = 0.06f * sin(0.31f * tt);
    }

    static final float CP = (float) Math.cos(PITCH), SP = (float) Math.sin(PITCH);

    static void carry(float x, float y, float z, float[] P, float[] o) {
        float y1 = y * CP - z * SP, z1 = y * SP + z * CP;
        o[0] = x * P[0] - y1 * P[1] + P[3];
        o[1] = x * P[1] + y1 * P[0] + P[2];
        o[2] = z1;
    }

    static void carryN(float x, float y, float z, float[] P, float[] o) {
        float y1 = y * CP - z * SP, z1 = y * SP + z * CP;
        o[0] = x * P[0] - y1 * P[1];
        o[1] = x * P[1] + y1 * P[0];
        o[2] = z1;
    }

    static void bellProfile(float u, float th, float c, float[] out) {
        float a = u * CURL;
        float wide = BELL_R * (float) Math.pow(Math.sin(a), 0.9) * (1 + 0.05f * (float) Math.pow(u, 6) * cos(LAPPETS * th));
        float tall = BELL_H * (cos(a) - cos(CURL)) / (1 - cos(CURL));
        float r = wide * (1 + FLARE * (float) Math.pow(u, 8) - 0.30f * (float) Math.pow(u, 1.6) * c);
        out[0] = r;
        out[1] = tall * (1 + 0.15f * c);
    }

    void proj(float[] p, float[] o) {
        float k = D / (D - p[2]);
        o[0] = OXc + Sx * p[0] * k;
        o[1] = OYr - Sy * p[1] * k;
        o[2] = p[2];
    }

    /* ============================================================ grade */
    void clearGrid() {
        for (int j = 0; j < nUsed; j++) chr[used[j]] = 0;
        nUsed = 0;
        java.util.Arrays.fill(zb, -1e9f);
    }

    void plot(float colf, float rowf, float z, char c, int col, float a, float bri) {
        int cx = Math.round(colf), ry = Math.round(rowf);
        if (cx < 0 || ry < 0 || cx >= COLS || ry >= ROWS) return;
        int i = ry * COLS + cx;
        if (z <= zb[i]) return;
        if (chr[i] == 0) used[nUsed++] = i;
        zb[i] = z;
        chr[i] = c;
        int r = (int) clamp(((col >> 16) & 255) * bri, 0, 255);
        int g = (int) clamp(((col >> 8) & 255) * bri, 0, 255);
        int b = (int) clamp((col & 255) * bri, 0, 255);
        rgb[i] = (r << 16) | (g << 8) | b;
        alp[i] = a;
    }

    void line(float[] a, float[] b, int col, float alpha, float bri, char flat) {
        float dc = b[0] - a[0], dr = b[1] - a[1];
        int n = Math.max(1, (int) Math.ceil(Math.max(Math.abs(dc), Math.abs(dr))));
        char c = slopeChar(dc * cw, dr * ch, flat);
        for (int i = 0; i <= n; i++) {
            float k = (float) i / n;
            plot(a[0] + dc * k, a[1] + dr * k, lerp(a[2], b[2], k) + 0.001f, c, col, alpha, bri);
        }
    }

    static int mix(int a, int b, float k) {
        int r = (int) lerp((a >> 16) & 255, (b >> 16) & 255, k);
        int g = (int) lerp((a >> 8) & 255, (b >> 8) & 255, k);
        int bl = (int) lerp(a & 255, b & 255, k);
        return (r << 16) | (g << 8) | bl;
    }

    /* ============================================================ peças */
    final float[] P = new float[4], tmp = new float[3], tmpN = new float[3], tmp2 = new float[3];
    final float[] pr = new float[3], p2 = new float[3], prof = new float[2], prof2 = new float[2];

    void drawBell(float t) {
        pose(t, P);
        boolean assembling = t < 1.6f;
        float flash = (t > 2.05f && t < 3.6f) ? (float) Math.exp(-Math.max(0, t - 2.25f) * 2.4f) * sstep(2.05f, 2.25f, t) : 0;
        final float Lx = -0.42f, Ly = 0.62f, Lz = 0.66f;
        for (int iu = 0; iu < NU; iu++) {
            float u = (iu + 0.5f) / NU;
            float c = squeeze(t - RIM_LAG * u);
            int[] pal = PALETTES[paletteAt(t, u)];
            for (int it = 0; it < NTH; it++) {
                float th0 = (float) it / NTH * TAU, th = th0 + SPIN * t;
                bellProfile(u, th, c, prof);
                bellProfile(Math.min(1, u + 0.01f), th, c, prof2);
                float dr = prof2[0] - prof[0], dy = prof2[1] - prof[1];
                float nr = -dy, ny = dr, nl = (float) Math.hypot(nr, ny);
                if (nl == 0) nl = 1;
                nr /= nl; ny /= nl;
                float ct = cos(th), st = sin(th);
                carry(prof[0] * ct, prof[1], prof[0] * st, P, tmp);
                carryN(nr * ct, ny, nr * st, P, tmpN);
                proj(tmp, pr);
                int id = iu * NTH + it;
                float facing = tmpN[2];
                if (assembling) {
                    float[] s = start[id];
                    float k = smooth((t - 0.05f - s[2] * 0.7f) / 0.75f);
                    if (k < 1) {
                        float sc = s[0] * COLS, sr = s[1] * ROWS;
                        if (hash(id * 3 + 1) < 0.07f && t > s[2] * 0.4f)
                            plot(lerp(sc, pr[0], k), lerp(sr, pr[1], k), pr[2] - 3, hash(id) < 0.5f ? '+' : '.', 0xdce6ff, 0.55f + 0.45f * k, 1);
                        continue;
                    }
                }
                float stripe = sstep(0.38f, 0.62f, 0.5f + 0.5f * cos(PETALS * th0));
                int base = mix(pal[0], pal[1], stripe);
                if (flash > 0) base = mix(base, 0xebf0ff, flash * 0.9f);
                char cc;
                int col;
                float bri, alpha = 1;
                if (facing < -0.02f) {
                    carry(prof2[0] * ct, prof2[1], prof2[0] * st, P, tmp2);
                    proj(tmp2, p2);
                    cc = (it % 2 == 1) ? slopeChar((p2[0] - pr[0]) * cw, (p2[1] - pr[1]) * ch, '-') : (u > 0.5f ? ':' : '.');
                    col = mix(base, pal[3], 0.4f); bri = 0.42f; alpha = 0.9f;
                } else if (u > 0.93f) {
                    float th2 = th + 0.02f;
                    bellProfile(u, th2, c, prof2);
                    carry(prof2[0] * cos(th2), prof2[1], prof2[0] * sin(th2), P, tmp2);
                    proj(tmp2, p2);
                    cc = slopeChar((p2[0] - pr[0]) * cw, (p2[1] - pr[1]) * ch, '_');
                    col = base; bri = 0.95f;
                } else if (facing < 0.2f) {
                    cc = slopeChar(tmpN[1], tmpN[0], '-');
                    col = base; bri = 0.9f;
                } else {
                    float lam = Math.max(0, tmpN[0] * Lx + tmpN[1] * Ly + tmpN[2] * Lz);
                    float b = clamp((0.18f + 0.82f * lam) * (0.55f + 0.45f * stripe) + 0.25f * flash, 0, 0.999f);
                    cc = letter(b, id + (u > 0.6f ? 0 : 7));
                    col = base; bri = 0.5f + 0.5f * b;
                }
                plot(pr[0], pr[1], pr[2], cc, col, alpha, bri);
            }
        }
    }

    final float[] la = new float[3], lb = new float[3];

    int drawTentacles(float t) {
        float g = dropped(t, TENT_T0, TENT_DROP);
        if (g <= 0) return 0;
        final int N = 52;
        float[] Pt = new float[4];
        for (int kk = 0; kk < N_TENT * 2; kk++) {
            int k = kk >> 1, strand = kk & 1;
            float ph = k * 2.399f, th0 = (float) k / N_TENT * TAU + 0.11f + strand * 0.075f;
            boolean has = false;
            for (int i = 0; i <= N; i++) {
                float s = (float) i / N, reach = TENT_LEN * g * s;
                float td = t - RIM_LAG - TENT_LAG * reach;
                float c = squeeze(td);
                float th = th0 + SPIN * td + 0.55f * s * sin(0.8f * t - 2.6f * reach + ph);
                float r = 0.97f * BELL_R * (1 - 0.34f * c) * (1 - 0.22f * smooth(1.1f * reach / TENT_LEN * 2)) + strand * 0.05f;
                r += 0.13f * (float) Math.pow(s, 0.7) * (strand == 1 ? 1.15f : 1f) * sin(1.7f * t - 6.5f * reach / TENT_LEN + 3 * ph);
                float y = -reach * (1 + 0.08f * c) + 0.02f * s * sin(2.3f * t - 7 * reach + ph);
                pose(td, Pt);
                carry(r * cos(th), y, r * sin(th), Pt, tmp);
                proj(tmp, lb);
                if (has) {
                    int[] pal = PALETTES[paletteAt(t, 1 + s * 1.6f)];
                    float depth = clamp(0.8f + 0.25f * lb[2], 0.5f, 1);
                    line(la, lb, pal[3], 1, depth * (1 - 0.25f * s) * (strand == 1 ? 0.8f : 1f), '_');
                }
                la[0] = lb[0]; la[1] = lb[1]; la[2] = lb[2];
                has = true;
            }
        }
        return N_TENT;
    }

    void drawArms(float t) {
        float g = dropped(t, ARM_T0, ARM_DROP);
        if (g <= 0) return;
        final int NU2 = 34, NV = 9;
        float[] Pa = new float[4];
        float[] eL = new float[3], eR = new float[3], pp = new float[3];
        for (int k = 0; k < N_ARMS; k++) {
            float phk = (float) k / N_ARMS * TAU + 0.4f;
            boolean hasL = false, hasR = false;
            for (int iu = 0; iu <= NU2; iu++) {
                float u = (float) iu / NU2, reach = ARM_LEN * g * u;
                float td = t - 0.12f - 0.35f * reach;
                pose(td, Pa);
                float c = squeeze(td);
                float phi = phk + SPIN * 0.6f * td + 0.35f * sin(0.7f * t - 2.2f * reach + k);
                float rad = 0.10f + 0.06f * sin(1.3f * t + k + 3 * u);
                float cx = rad * cos(phi) + 0.12f * u * u * sin(0.9f * t - 3 * reach + k);
                float cz = rad * sin(phi);
                float cy = 0.05f - reach * (1 + 0.06f * c);
                float w = 0.27f * (1 - 0.55f * u) * (1 + 0.28f * sin(9 * u - 3.1f * t + k * 1.7f)) * (0.5f + 0.5f * g);
                float psi = phi + (float) Math.PI / 2 + 1.3f * u + 0.4f * sin(0.5f * t + k);
                float ex = cos(psi), ez = sin(psi);
                int[] pal = PALETTES[paletteAt(t, 1.0f + u * 1.2f)];
                float facing = Math.abs(sin(psi - 0.3f));
                for (int iv = 0; iv <= NV; iv++) {
                    float v = (float) iv / NV * 2 - 1;
                    carry(cx + v * w * ex, cy + 0.03f * sin(5 * v + 3 * t), cz + v * w * ez, Pa, tmp);
                    proj(tmp, pp);
                    if (iv == 0) {
                        if (hasL) line(eL, pp, pal[2], 0.95f, 0.6f, '_');
                        eL[0] = pp[0]; eL[1] = pp[1]; eL[2] = pp[2]; hasL = true;
                        continue;
                    }
                    if (iv == NV) {
                        if (hasR) line(eR, pp, pal[2], 0.95f, 0.6f, '_');
                        eR[0] = pp[0]; eR[1] = pp[1]; eR[2] = pp[2]; hasR = true;
                        continue;
                    }
                    float b = clamp((0.35f + 0.6f * facing) * (1 - 0.6f * Math.abs(v)) * (1 - 0.35f * u) + 0.15f, 0, 0.99f);
                    plot(pp[0], pp[1], pp[2], letter(b, (k * 97 + iu) * 31 + iv), pal[2], 1, 0.55f + 0.5f * b);
                }
            }
        }
    }

    int drawGlints(float t) {
        int count = 0;
        float[] Pg = new float[4], o = new float[3], ex = new float[3], ez = new float[3], p = new float[3];
        for (int n = 0; n < glintT0.length; n++) {
            float age = t - glintT0[n];
            if (age < 0 || age >= GLINT_LIFE) continue;
            pose(glintT0[n], Pg);
            carry(0, 0, 0, Pg, o); carryN(1, 0, 0, Pg, ex); carryN(0, 0, 1, Pg, ez);
            float r = 0.9f * BELL_R + 1.15f * (1 - (float) Math.exp(-1.5f * age));
            float fade = (float) Math.pow(1 - age / GLINT_LIFE, 0.6);
            for (int i = 0; i < N_GLINTS; i++) {
                float[] G = glint[n][i];
                float a = (G[0] + i) * TAU / N_GLINTS, ca = cos(a), sa = sin(a);
                p[0] = o[0] + r * (ca * ex[0] + sa * ez[0]);
                p[1] = o[1] + r * (ca * ex[1] + sa * ez[1]) - 0.10f * age - 0.05f * age * age;
                p[2] = o[2] + r * (ca * ex[2] + sa * ez[2]);
                float tw = clamp(sin(t * (5 + 6 * G[1]) + G[0] * 50), 0, 1);
                proj(p, pr);
                plot(pr[0], pr[1], pr[2] + 0.5f, tw > 0.6f ? '*' : '+', 0xffffff, fade, 0.75f + 0.25f * tw);
                count++;
            }
        }
        return count;
    }

    static void sparkAt(Spark s, float age, float[] o) {
        float k = (1 - (float) Math.exp(-DRAG * Math.max(age, 0))) / DRAG;
        o[0] = s.start[0] + s.vel[0] * k;
        o[1] = s.start[1] + s.vel[1] * k - 0.07f * age * age;
        o[2] = s.start[2] + s.vel[2] * k;
    }

    int drawSparks(float t) {
        int count = 0;
        float[] h = new float[3], b = new float[3], ph = new float[3], pb = new float[3];
        for (Spark s : sparks) {
            float age = t - s.t0;
            if (age < 0 || age > s.life) continue;
            count++;
            boolean dying = age > s.life - 0.6f;
            float fade = dying ? (s.life - age) / 0.6f : 1;
            float fl = sin(age * 38 + s.seed * 9);
            char head = dying ? (fl > 0.3f ? '.' : (fl > -0.4f ? ':' : ' ')) : (fl > 0 ? '*' : '+');
            for (int k = 1; k <= TAILS; k++) {
                float a1 = Math.max(0, age - TAIL_GAP * (k - 1)), a2 = Math.max(0, age - TAIL_GAP * k);
                sparkAt(s, a1, h); proj(h, ph);
                sparkAt(s, a2, b); proj(b, pb);
                if (dying && hash((k * 131 + (int) (t * 30)) ^ (int) (s.seed * 1e4f)) < 0.5f) continue;
                line(ph, pb, s.ink, fade * (1 - (float) k / (TAILS + 1)), 0.9f, '_');
            }
            sparkAt(s, age, h); proj(h, ph);
            if (head != ' ') plot(ph[0], ph[1], ph[2] + 1, head, s.ink, fade, 1);
        }
        return count;
    }

    /* ============================================================ fundo */
    static final float[][] MINI = {
            {0.07f, 0.16f, 0xc23a52, 1.0f, 0.0f}, {0.86f, 0.22f, 0xd0405a, 1.15f, 1.7f},
            {0.08f, 0.45f, 0x2e8c8c, 1.1f, 2.9f}, {0.85f, 0.66f, 0x3a6fd0, 1.05f, 4.0f},
            {0.09f, 0.74f, 0x6a4ac0, 1.1f, 5.1f}, {0.80f, 0.06f, 0x4a5ab8, 0.9f, 0.9f},
            {0.20f, 0.90f, 0x3a8a9a, 0.8f, 3.3f}, {0.78f, 0.88f, 0xb0405a, 0.9f, 2.2f},
    };

    void drawBackground(Canvas c, float t, float dim) {
        bgPaint.setTextAlign(Paint.Align.LEFT);
        bgPaint.setTextSize(ts * 0.85f);
        for (float[] s : stars) {
            float y = (((s[1] - s[2] * t) % 1) + 1) % 1;
            float x = s[0] + 0.01f * sin(t * 0.3f + s[3]);
            float tw = 0.35f + 0.65f * Math.max(0, sin(t * 1.3f + s[3] * 3));
            bgPaint.setColor(Color.argb((int) (255 * (0.25f + 0.55f * tw) * dim), 200, 215, 255));
            c.drawText((s[4] > 0 || tw > 0.7f) ? "+" : ".", x * W, y * H, bgPaint);
        }
        float fs = ts * 0.78f;
        bgPaint.setTextSize(fs);
        for (float[] m : MINI) {
            float bob = sin(t * 0.9f + m[4]) * fs * 0.6f, sq = sin(t * 1.8f + m[4]);
            float x0 = m[0] * W, y0 = m[1] * H + bob;
            int col = (int) m[2];
            bgPaint.setColor(Color.argb((int) (255 * 0.38f * dim), (col >> 16) & 255, (col >> 8) & 255, col & 255));
            String[] lines = {" .-\"\"\"-. ", "/  ' .  \\", sq > 0 ? "'-~~~~~-'" : " '-~~~-' ", "", "", "", ""};
            for (int i = 0; i < 4; i++) lines[3 + i] = (((i + (int) (t * 2)) & 1) == 1) ? " ) ( ) ( " : " ( ) ( ) ";
            for (int i = 0; i < lines.length; i++) c.drawText(lines[i], x0, y0 + i * fs * 1.05f * m[3], bgPaint);
        }
    }

    /* ============================================================ quadro */
    public void draw(Canvas c, float t) {
        if (W == 0) return;
        float dimOut = 1 - 0.75f * sstep(OUTRO, OUTRO + 1.4f, t);
        float fadeIn = 0.25f + 0.75f * sstep(0, 0.25f, t), endFade = 1 - 0.75f * sstep(LOOP - 0.5f, LOOP, t);
        float dim = dimOut * Math.min(fadeIn, 1) * endFade;
        if (t < 0.25f) dim = Math.max(dim, 0.25f);

        clearGrid();
        drawBell(t);
        drawArms(t);
        drawTentacles(t);
        if (t >= GLINT_FROM) drawGlints(t);
        if (t >= T_FINALE[0]) drawSparks(t);

        c.drawColor(Color.BLACK);
        drawBackground(c, t, dim);

        // brilho: letras desenhadas em tamanho reduzido e ampliadas por cima
        glow.eraseColor(Color.TRANSPARENT);
        float gs = 1f / GLOW_DIV, base = ts * 0.33f;
        for (int j = 0; j < nUsed; j++) {
            int i = used[j];
            int col = i % COLS, row = i / COLS;
            int a = (int) (255 * clamp(alp[i] * dim, 0, 1));
            gPaint.setColor((a << 24) | rgb[i]);
            one[0] = chr[i];
            gc.drawText(one, 0, 1, (col + 0.5f) * cw * gs, ((row + 0.5f) * ch + base) * gs, gPaint);
        }
        for (int j = 0; j < nUsed; j++) {
            int i = used[j];
            int col = i % COLS, row = i / COLS;
            int a = (int) (255 * clamp(alp[i] * dim, 0, 1));
            paint.setColor((a << 24) | rgb[i]);
            one[0] = chr[i];
            c.drawText(one, 0, 1, (col + 0.5f) * cw, (row + 0.5f) * ch + base, paint);
        }
        src.set(0, 0, glow.getWidth(), glow.getHeight());
        dst.set(0, 0, W, H);
        blit.setAlpha(215);
        c.drawBitmap(glow, src, dst, blit);
        int ox = (int) cw, oy = (int) (ch * 0.5f);
        dst2.set(-ox, -oy, W + ox, H + oy);
        blit.setAlpha(90);
        c.drawBitmap(glow, src, dst2, blit);
    }
}
