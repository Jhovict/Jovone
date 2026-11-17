package com.jovone.aguaviva;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/** Ipê: nasce, floresce rosa, fica verde, enferruja e dorme sob a neve (34 s). Porte de tree.js. */
public class CenaIpe extends Motor {

    @Override protected int cols() { return 84; }
    @Override public float loop() { return 34; }

    static final class Branch { int parent, depth, id; float rel, len, birth, dur, bend, sway, w0, w1; boolean tip; }
    static final class Root { float x, a, len, w, bend; int id; }
    static final class Cluster { int b, id; float ox, oy, r, z, seed, appear, green, turn, gone; int ink0, ink1; }
    static final class Loose { int c; boolean petal; float t, ox, oy, seed, v; }

    final List<Branch> B = new ArrayList<>();
    final List<Root> roots = new ArrayList<>();
    final List<Cluster> clusters = new ArrayList<>();
    final List<Loose> loose = new ArrayList<>();
    float[] ex, ey, ang;
    float[][] snow, flakes, flies;
    float hills, extH, extW;
    Rng R0;

    void grow(int parent, float rel, float len, int depth, float birth) {
        float dur = 0.35f + len * 0.08f;
        Branch b = new Branch();
        b.parent = parent; b.rel = rel; b.len = len; b.depth = depth; b.birth = birth; b.dur = dur; b.id = B.size();
        b.bend = (R0.next() - 0.5f) * 0.55f; b.sway = R0.next() * TAU;
        float W0 = 4.0f;
        b.w0 = W0 * pow(0.56f, depth); b.w1 = W0 * pow(0.56f, depth + 1);
        B.add(b);
        int i = b.id;
        if (depth >= 6 || len < 1.0f){ b.tip = true; return; }
        if (depth == 0){
            grow(i, -0.42f - 0.12f * R0.next(), len * 0.78f, 1, birth + dur * 0.9f);
            grow(i, 0.38f + 0.12f * R0.next(), len * 0.74f, 1, birth + dur * 0.85f);
            grow(i, (R0.next() - 0.5f) * 0.15f, len * 0.55f, 1, birth + dur * 0.95f);
            return;
        }
        grow(i, (R0.next() - 0.5f) * 0.35f, len * (0.70f + 0.12f * R0.next()), depth + 1, birth + dur * (0.7f + 0.25f * R0.next()));
        float side = R0.next() < 0.5f ? 1 : -1;
        grow(i, side * (0.5f + 0.35f * R0.next()), len * (0.55f + 0.15f * R0.next()), depth + 1, birth + dur * (0.6f + 0.3f * R0.next()));
        if (R0.next() < 0.35f) grow(i, -side * (0.45f + 0.3f * R0.next()), len * (0.5f + 0.15f * R0.next()), depth + 1, birth + dur * (0.75f + 0.2f * R0.next()));
    }

    @Override protected void init() {
        R0 = new Rng(21);
        grow(-1, 0.03f, 8.6f, 0, 0.6f);
        int n = B.size();
        ex = new float[n]; ey = new float[n]; ang = new float[n];
        for (int k = 0; k < 6; k++){
            float side = k % 2 == 1 ? 1 : -1;
            Root r = new Root();
            r.x = side * (0.8f + 0.7f * R0.next());
            r.a = side > 0 ? 0.10f + 0.30f * R0.next() : (float) Math.PI - 0.10f - 0.30f * R0.next();
            r.len = 3.0f + 3.5f * R0.next(); r.w = 1.4f + 0.7f * R0.next(); r.bend = (R0.next() - 0.5f) * 0.5f; r.id = 900 + k;
            roots.add(r);
        }
        int[][] inks = {{0x7a2a0c, 0xff9a2a}, {0x6a140c, 0xff4a2a}, {0x7a5a0a, 0xffd23a}, {0x5a2a10, 0xe0702a}};
        for (Branch b : B){
            if (!(b.tip || b.depth >= 3)) continue;
            int cnt = b.tip ? 4 : (b.depth >= 4 ? 2 : 1);
            for (int k = 0; k < cnt; k++){
                Cluster c = new Cluster();
                c.b = b.id; c.ox = (R0.next() - 0.5f) * 3.4f; c.oy = (R0.next() - 0.5f) * 2.6f - 0.8f; c.r = 1.9f + 1.4f * R0.next();
                c.z = R0.next(); c.seed = R0.next(); c.id = (int) (R0.next() * 1e9f);
                c.appear = 5.6f + R0.next() * 2.6f; c.green = 12.2f + R0.next() * 1.8f; c.turn = 18.6f + R0.next() * 3.0f; c.gone = 21.5f + R0.next() * 3.6f;
                int[] ink = inks[(int) (R0.next() * 4) % 4]; c.ink0 = ink[0]; c.ink1 = ink[1];
                clusters.add(c);
            }
        }
        clusters.sort((a, b) -> Float.compare(a.z, b.z));
        for (int i = 0; i < clusters.size(); i++){
            Cluster c = clusters.get(i);
            if (R0.next() < 0.35f){ Loose l = new Loose(); l.c = i; l.petal = true; l.t = 10.4f + R0.next() * 3.2f; l.ox = (R0.next() - 0.5f) * 3; l.oy = (R0.next() - 0.5f) * 2; l.seed = R0.next(); l.v = 4.2f + 2.0f * R0.next(); loose.add(l); }
            for (int k = 0; k < 1; k++){ Loose l = new Loose(); l.c = i; l.petal = false; l.t = c.turn + 0.8f + R0.next() * (c.gone - c.turn); l.ox = (R0.next() - 0.5f) * 3; l.oy = (R0.next() - 0.5f) * 2; l.seed = R0.next(); l.v = 4.5f + 2.5f * R0.next(); loose.add(l); }
        }
        snow = new float[180][4];
        for (float[] s : snow){ s[0] = R0.next(); s[1] = 2.5f + 3.5f * R0.next(); s[2] = R0.next() * TAU; s[3] = R0.next(); }
        flakes = makeStars(120, 4);
        flies = new float[3][3];
        for (int i = 0; i < 3; i++){ flies[i][0] = R0.next() * TAU; flies[i][1] = 0.6f + 0.5f * R0.next(); flies[i][2] = i; }
        hills = R0.next() * 100;
        pose(40, 0);
        float top = 0, half = 0;
        for (int i = 0; i < n; i++){ top = Math.min(top, ey[i]); half = Math.max(half, Math.abs(ex[i])); }
        extH = -top + 3.2f; extW = half + 3.2f;
    }

    float windAt(float t) { return 0.28f * sin(t * 0.45f) + 0.12f * sin(t * 1.7f + 1) + 0.28f * sstep(18, 22, t) * (1 - sstep(25, 27, t)) + 0.08f; }

    void pose(float t, float wind) {
        for (int i = 0; i < B.size(); i++){
            Branch b = B.get(i);
            float sx = b.parent < 0 ? 0 : ex[b.parent], sy = b.parent < 0 ? 0 : ey[b.parent];
            float a0 = b.parent < 0 ? (float) -Math.PI / 2 : ang[b.parent];
            float a = a0 + b.rel + wind * 0.014f * pow(b.depth + 1, 1.35f) + 0.016f * b.depth * sin(t * 2.1f + b.sway);
            a += ((float) -Math.PI / 2 - a) * 0.07f;
            float g = clamp((t - b.birth) / b.dur, 0, 1);
            ang[i] = a;
            float L = b.len * g, ae = a + b.bend * 0.5f;
            ex[i] = sx + cos(a) * L * 0.5f + cos(ae) * L * 0.5f;
            ey[i] = sy + sin(a) * L * 0.5f + sin(ae) * L * 0.5f;
        }
    }

    // mapeamento de unidades para a grade (definido a cada quadro)
    float sc, scY, cxm, GRr;
    float col(float X) { return cxm + X * sc * asp; }
    float row(float Y) { return GRr + Y * scY; }

    static final String BARK = "|!l1{}[]%#";
    static final String FOL = "..,::;*oo%&8@@#";

    void band(float sx, float sy, float a, float len, float w0, float w1, float bend, float flare, int id, int prio, float winter, float frost) {
        int n = Math.max(2, (int) Math.ceil(len * sc * 1.4f));
        int barkD = mix(0x2e1a0e, 0x3c4a60, frost * 0.5f), barkL = mix(0xb8875a, 0xe6eef8, frost * 0.6f);
        for (int i = 0; i <= n; i++){
            float s = (float) i / n;
            float as = a + bend * (s - 0.5f) * 0.5f + bend * 0.25f;
            float along = len * s;
            float px = sx + cos(a) * along * (1 - s * 0.5f) + cos(a + bend * 0.5f) * along * s * 0.5f;
            float py = sy + sin(a) * along * (1 - s * 0.5f) + sin(a + bend * 0.5f) * along * s * 0.5f;
            float w = lerp(w0, w1, s) * (1 + flare * pow(1 - s, 5));
            float nx = -sin(as), ny = cos(as);
            float halfCols = Math.abs(w * 0.5f * sc * asp * nx) + Math.abs(w * 0.5f * sc * ny);
            char tch = slopeChar(cos(as) * cw * asp, sin(as) * ch, '_');
            if (w * sc * asp < 1.3f){ put(col(px), row(py), tch, mix(barkD, barkL, 0.75f), 1, prio); continue; }
            int steps = Math.max(2, (int) Math.ceil(halfCols * 2.2f));
            for (int q = 0; q <= steps; q++){
                float u = (float) q / steps * 2 - 1;
                float qx = px + nx * u * w * 0.5f, qy = py + ny * u * w * 0.5f;
                float lit = clamp(0.55f - 0.6f * (nx * u) / (Math.abs(nx) + 0.3f), 0, 1);
                char k; int rgb;
                if (Math.abs(u) > 0.78f){ k = tch; rgb = mix(barkD, barkL, lit * 0.8f + 0.1f); }
                else {
                    float v = noise2(s * len * 1.6f + id * 3.7f, u * 2.2f + id);
                    k = BARK.charAt(Math.min(9, (int) (v * 10)));
                    rgb = mix(barkD, barkL, clamp(lit * 0.85f + (v - 0.5f) * 0.3f, 0, 1));
                }
                put(col(qx), row(qy), k, rgb, 1, prio);
            }
            if (winter > 0.3f && Math.abs(cos(as)) > 0.35f && h1(id * 31 + i) < 0.7f){
                float topU = ny < 0 ? 1 : -1;
                put(col(px + nx * topU * w * 0.5f), row(py + ny * topU * w * 0.5f) - 1, h1(id + i) < 0.5f ? '.' : '*', 0xf4f8ff, winter, prio + 1);
            }
        }
    }

    static final float[] SKY_T = {0, 7, 14, 20, 25, 27.5f, 34};
    static final int[] SKY_TOP = {0x03070f, 0x081a2c, 0x0a2238, 0x1a1008, 0x120a06, 0x060a18, 0x060a18};
    static final int[] SKY_HOR = {0x0a1420, 0x2a2440, 0x1e4660, 0x40240e, 0x24140a, 0x16203a, 0x16203a};
    static final float[] SEAS_T = {0, 8, 14, 20, 26, 28, 34};
    static final int[] HILL = {0x16301e, 0x2a5a34, 0x24502c, 0x5a4220, 0x3a3020, 0xa8b8d0, 0xa8b8d0};
    static final float[] GRASS_T = {0, 7, 13, 20, 26, 28, 34};
    static final int[] GRASS = {0x3a6a2e, 0x5fd068, 0x3fae4f, 0xc08a2a, 0x7a5a30, 0xe8f0ff, 0xe8f0ff};

    @Override protected void frame(float t, float T) {
        int GR = R - 6;
        sc = Math.min((GR - 4) / extH, (C * 0.6f) / (extW * asp));
        scY = Math.max(sc, Math.min((GR - R * 0.1f) / extH, sc * 1.6f));   // em tela alta, a árvore cresce para cima
        cxm = C * 0.5f; GRr = GR;
        float wind = windAt(t);
        float spring = sstep(5.5f, 8, t) * (1 - sstep(12.5f, 14.5f, t));
        float summer = sstep(12.5f, 14.5f, t) * (1 - sstep(19, 22, t));
        float autumn = sstep(18.5f, 21, t) * (1 - sstep(25.5f, 27, t));
        final float winter = sstep(25.5f, 27.5f, t) * (1 - sstep(33.3f, 34, t));
        final float dayish = Math.max(spring, Math.max(summer, autumn * 0.8f));

        stars(flakes, GR - 8, 0.35f + 0.5f * winter + 0.2f * (1 - dayish), t, 0);
        if (dayish > 0.05f){
            final float sx = C * 0.82f, sy = R * 0.12f;
            final int sunC = mix(0xfff2b0, 0xffb04a, autumn);
            disc(sx, sy, 3.0f, (c, r, d, dx, dy) -> put(c, r, letter(clamp(1.05f - d * 0.7f, 0, .99f), c * 31 + r), mix(sunC, 0xff8a3a, d * 0.5f), dayish, 2));
            for (int k = 0; k < 9; k++){
                float a = (float) Math.PI * (0.55f + k * 0.06f) + sin(t * 0.3f + k) * 0.02f, len = R * (0.45f + 0.2f * h1(k));
                for (float s = 5; s < len; s += 1.0f){
                    float c = sx + cos(a) * s * asp, r = sy + sin(a) * s;
                    if (h3(c, r, k) < 0.32f) put(c, r, '.', sunC, dayish * 0.22f * (1 - s / len), 1);
                }
            }
        }
        if (winter > 0.02f) disc(C * 0.82f, R * 0.12f, 2.6f, (c, r, d, dx, dy) -> {
            float cr = noise2(dx * 3 + 5, dy * 3) > 0.62f ? 0.55f : 1;
            put(c, r, letter(clamp((1 - d * 0.5f) * cr, 0, .99f), c * 17 + r), scale(0xe4ecff, cr), winter, 2);
        });
        int hillC = keyColor(SEAS_T, HILL, t);
        for (int c = 0; c < C; c++){
            float top = GR - 2 - 4 * fbm1(c * 0.05f + hills);
            for (int r = Math.round(top); r < GR; r++) if (h2(c, r) < 0.55f) put(c, r, r == Math.round(top) ? '_' : (h2(c, r) < 0.25f ? ':' : '.'), scale(hillC, 0.55f), 0.6f, 1);
        }
        int grassC = keyColor(GRASS_T, GRASS, t);
        for (int c = 0; c < C; c++){
            float hh = h1(c * 7 + 3), sway = sin(t * 2.4f + c * 0.3f) * 0.6f + wind * 1.3f;
            put(c, GR, ",.'\"`;:".charAt(Math.min(6, (int) (hh * 7))), grassC, 0.95f, 5);
            if (hh < 0.45f && winter < 0.5f) put(c, GR - 1, sway > 0.45f ? '/' : (sway < -0.25f ? '\\' : '|'), scale(grassC, 0.85f + 0.3f * hh), 0.85f, 5);
            if (hh > 0.93f && (spring + summer) > 0.3f) put(c, GR - 1, h1(c) < 0.5f ? '*' : 'o', h1(c * 3) < 0.5f ? 0xffd23a : 0xff8fd0, spring + summer, 6);
            for (int r = GR + 1; r < R; r++){ float v = h2(c, r); if (v < 0.5f) put(c, r, v < 0.14f ? ':' : '.', mix(0x5a3a22, 0xcfd8e8, winter * 0.8f), 0.3f + 0.3f * (r - GR) / 6f, 0); }
        }
        if (t < 1.2f) put(cxm, GR - 0.4f, 'o', 0xd8b48a, sstep(0, 0.4f, t), 50);

        pose(t, wind);
        float frost = winter;
        int nb = 0;
        float rootG = sstep(0.8f, 3.5f, t);
        if (rootG > 0) for (Root rt : roots) band(rt.x, 0.15f, rt.a, rt.len * rootG, rt.w, 0.15f, rt.bend, 0, rt.id, 36, 0, frost * 0.5f);
        for (int i = 0; i < B.size(); i++){
            Branch b = B.get(i);
            float g = clamp((t - b.birth) / b.dur, 0, 1);
            if (g <= 0) continue;
            nb++;
            float sx = b.parent < 0 ? 0 : ex[b.parent], sy = b.parent < 0 ? 0 : ey[b.parent];
            float gw = 0.35f + 0.65f * sstep(0, 1, (t - b.birth) / (b.dur * 3));
            band(sx, sy, ang[i], b.len * g, b.w0 * gw, b.w1 * gw, b.bend, b.depth == 0 ? 1.1f : 0, b.id, b.depth <= 2 ? 40 : 34, winter, frost);
        }

        for (Cluster cl : clusters){
            Branch b = B.get(cl.b);
            if (clamp((t - b.birth) / b.dur, 0, 1) < 1 || t < cl.appear || t > cl.gone + 1.2f) continue;
            float growR = sstep(cl.appear, cl.appear + 1.8f, t);
            float keep = 1 - sstep(cl.turn + 0.8f, cl.gone + 1.2f, t);
            float rad = cl.r * (float) Math.sqrt(growR) * (0.75f + 0.25f * keep);
            if (rad < 0.25f) continue;
            float sw = 0.3f * sin(t * 2.2f + cl.seed * 9) * (0.4f + wind);
            float X = ex[cl.b] + cl.ox + sw, Y = ey[cl.b] + cl.oy;
            float c0 = col(X), r0 = row(Y), rr = rad * scY * 0.9f, rc = rad * sc * asp * 1.1f;
            float toGreen = sstep(cl.green, cl.green + 1.6f, t), toAut = sstep(cl.turn, cl.turn + 1.6f, t);
            int dark = mix(mix(0xa02866, 0x0e4a22, toGreen), cl.ink0, toAut);
            int light = mix(mix(0xffb8e4, 0x9ef07a, toGreen), cl.ink1, toAut);
            int prio = 30 + Math.round(cl.z * 20);
            float shade = 0.72f + 0.28f * cl.z;
            for (int r = (int) Math.floor(r0 - rr - 1); r <= r0 + rr + 1; r++){
                for (int c = (int) Math.floor(c0 - rc - 1); c <= c0 + rc + 1; c++){
                    float dx = (c - c0) / rc, dy = (r - r0) / rr, d = (float) Math.hypot(dx, dy);
                    float edge = 1 + 0.42f * (noise2(c * 0.55f + cl.seed * 40, r * 0.7f + cl.seed * 17) - 0.5f);
                    if (d > edge) continue;
                    int cid = (c * 7919 + r * 104729) ^ cl.id;
                    if (hash(cid) > 0.35f + 0.65f * keep) continue;
                    float dn = Math.min(d / edge, 1);
                    float nz = (float) Math.sqrt(Math.max(0, 1 - dn * dn));
                    float lam = clamp(-0.5f * dx - 0.62f * dy + 0.62f * nz, 0, 1);
                    float b2 = clamp((0.18f + 0.82f * lam) * shade, 0, 0.99f);
                    char k = FOL.charAt(Math.min(14, (int) (b2 * 14.99f)));
                    if (toGreen < 0.5f && hash(cid + 1) < 0.08f) k = '*';
                    put(c, r, k, mix(dark, light, b2), 0.55f + 0.45f * growR, prio);
                }
            }
        }

        for (Loose f : loose){
            if (t < f.t) continue;
            Cluster cl = clusters.get(f.c);
            float X0 = ex[cl.b] + cl.ox + f.ox, Y0 = ey[cl.b] + cl.oy + f.oy;
            float s = t - f.t, land = -Y0 / f.v, wf = windAt(f.t);
            int rgb = f.petal ? mix(0xff8fd0, 0xffe4f4, f.seed) : cl.ink1;
            if (s < land){
                float x = X0 + 1.8f * sin(s * 3.0f + f.seed * 6) + (wf + 0.25f) * s * 3.0f;
                String set = f.petal ? "*'`." : "~,`*'";
                put(col(x), row(Y0 + f.v * s), set.charAt(((int) (s * 9 + f.seed * 4)) % set.length()), rgb, 1, 55);
            } else {
                float x = X0 + 1.8f * sin(land * 3.0f + f.seed * 6) + (wf + 0.25f) * land * 3.0f;
                float life = f.petal ? 1 - sstep(16, 19, t) : 1 - sstep(28, 30.5f, t);
                put(col(x), GR - (h1(f.seed * 1e4f) < 0.4f ? 1 : 0), f.petal ? '*' : "~,.%".charAt(Math.min(3, (int) (f.seed * 4))), scale(rgb, 0.85f), life, 7);
            }
        }

        float fly = Math.max(spring, summer * 0.6f);
        if (fly > 0.05f) for (float[] b : flies){
            float x = cxm + sin(t * 0.5f * b[1] + b[0]) * C * 0.38f, y = GR - 6 - 5 * Math.abs(sin(t * 0.7f + b[0] * 2)) - b[2] * 2;
            text(x, y, ((int) (t * 9 + b[2])) % 2 == 1 ? "}{" : "><", b[2] == 1 ? 0x8be0ff : 0xffd23a, fly, 60);
        }
        if (summer > 0.05f) for (int i = 0; i < 4; i++){
            float x = ((t - 12.5f) * 7 + i * 9) % (C + 24) - 12, y = R * 0.18f + i * 1.6f + sin(t * 2 + i) * 0.8f;
            text(x, y, ((int) (t * 7 + i * 1.3f)) % 2 == 1 ? "\\v/" : "-v-", 0xd2dcf0, summer * 0.9f, 60);
        }
        if (winter > 0.02f) for (float[] s : snow){
            float y = ((s[3] * R + (t - 25) * s[1]) % R + R) % R;
            put(s[0] * C + sin(t * 0.9f + s[2]) * 2 + y * 0.15f * wind, y, s[3] < 0.3f ? '*' : '.', 0xf4f8ff, winter * (0.6f + 0.4f * s[3]), 70);
        }

        int skyT = keyColor(SKY_T, SKY_TOP, t), skyH = keyColor(SKY_T, SKY_HOR, t);
        float gy = (float) GR / R;
        bg(new float[]{0, gy, gy + 0.002f, 1}, new int[]{scale(skyT, 0.7f), scale(skyH, 0.55f), scale(skyH, 0.18f), 0});
        dim = sstep(0, 0.6f, t) * (1 - sstep(33.3f, 34, t));
        glow = 0.7f;
    }
}
