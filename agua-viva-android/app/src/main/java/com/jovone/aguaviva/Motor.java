package com.jovone.aguaviva;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.Shader;
import android.graphics.Typeface;

/**
 * Motor comum das cenas nativas: grade de letras com prioridade, utilitários de ruído
 * e cor, fundo em degradê, silhuetas e brilho. Mesma lógica da versão web (engine.js).
 * Cores são inteiros 0xRRGGBB.
 */
public abstract class Motor implements Cena {

    public static final float TAU = (float) (Math.PI * 2);

    /* ---------- o que cada cena define ---------- */
    protected abstract int cols();
    public abstract float loop();
    protected void init() { }
    /** Desenha a cena na grade; devolve brilho/fundo em this.dim, this.glow, this.bg* */
    protected abstract void frame(float t, float T);
    /** Silhuetas sólidas atrás das letras (opcional). */
    protected void paint(Canvas c, float dim) { }

    /* ---------- estado de saída de cada quadro ---------- */
    protected float dim = 1, glow = 0.8f;
    protected float[] bgPos;
    protected int[] bgCol;

    /* ---------- layout ---------- */
    protected int W, H, C, R;
    protected float cw, ch, ts, asp;

    /* ---------- grade ---------- */
    protected char[] gch;
    protected int[] grgb;
    protected float[] ga;
    protected int[] gp;
    private boolean inited;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint gpaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint blit = new Paint(Paint.FILTER_BITMAP_FLAG);
    private final Paint bgPaint = new Paint();
    private Bitmap glowBmp;
    private Canvas gc;
    private final Rect src = new Rect(), dst = new Rect(), dst2 = new Rect();
    private final char[] one = new char[1];
    private static final int GLOW_DIV = 5;

    protected Motor() {
        paint.setTypeface(Typeface.MONOSPACE);
        paint.setTextAlign(Paint.Align.CENTER);
        gpaint.setTypeface(Typeface.MONOSPACE);
        gpaint.setTextAlign(Paint.Align.CENTER);
        blit.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.ADD));
    }

    @Override
    public void setSize(int w, int h) {
        if (w == W && h == H) return;
        W = w; H = h;
        C = cols();
        cw = (float) W / C;
        paint.setTextSize(100);
        float adv = paint.measureText("M") / 100f;
        ts = cw / adv;
        ch = ts * 0.92f;
        asp = ch / cw;
        R = (int) Math.floor(H / ch);
        paint.setTextSize(ts);
        gpaint.setTextSize(ts / GLOW_DIV);
        int n = C * R;
        gch = new char[n]; grgb = new int[n]; ga = new float[n]; gp = new int[n];
        if (glowBmp != null) glowBmp.recycle();
        glowBmp = Bitmap.createBitmap(Math.max(1, W / GLOW_DIV), Math.max(1, H / GLOW_DIV), Bitmap.Config.ARGB_8888);
        gc = new Canvas(glowBmp);
        if (!inited){ init(); inited = true; }
    }

    private int frameNo;

    @Override
    public void draw(Canvas c, float T) {
        if (W == 0) return;
        float t = T % loop();
        java.util.Arrays.fill(gch, (char) 0);
        dim = 1; glow = 0.8f; bgPos = null; bgCol = null;
        frame(t, T);

        c.drawColor(Color.BLACK);
        if (bgPos != null){
            int[] cols = new int[bgCol.length];
            for (int i = 0; i < cols.length; i++) cols[i] = 0xff000000 | scale(bgCol[i], dim);
            bgPaint.setShader(new LinearGradient(0, 0, 0, H, cols, bgPos, Shader.TileMode.CLAMP));
            c.drawRect(0, 0, W, H, bgPaint);
            bgPaint.setShader(null);
        }
        paint(c, dim);

        boolean doGlow = glow > 0.01f;
        boolean refresh = doGlow && (frameNo++ % 2 == 0);       // o brilho é refeito a cada 2 quadros
        if (refresh) glowBmp.eraseColor(Color.TRANSPARENT);
        float base = ts * 0.33f, gs = 1f / GLOW_DIV;
        for (int i = 0; i < gch.length; i++){
            char k = gch[i];
            if (k == 0 || k == ' ') continue;
            int col = i % C, row = i / C;
            int a = (int) (255 * clamp(ga[i] * dim, 0, 1));
            if (a < 3) continue;
            int argb = (a << 24) | grgb[i];
            one[0] = k;
            float x = (col + 0.5f) * cw, y = (row + 0.5f) * ch + base;
            paint.setColor(argb);
            c.drawText(one, 0, 1, x, y, paint);
            if (refresh){ gpaint.setColor(argb); gc.drawText(one, 0, 1, x * gs, y * gs, gpaint); }
        }
        if (doGlow){
            src.set(0, 0, glowBmp.getWidth(), glowBmp.getHeight());
            dst.set(0, 0, W, H);
            blit.setAlpha((int) clamp(215 * glow, 0, 255));
            c.drawBitmap(glowBmp, src, dst, blit);
            int ox = (int) cw, oy = (int) (ch * 0.5f);
            dst2.set(-ox, -oy, W + ox, H + oy);
            blit.setAlpha((int) clamp(100 * glow, 0, 255));
            c.drawBitmap(glowBmp, src, dst2, blit);
        }
    }

    /* ============================================================ grade */
    protected final int idx(float c, float r) {
        int cc = Math.round(c), rr = Math.round(r);
        return (cc < 0 || rr < 0 || cc >= C || rr >= R) ? -1 : rr * C + cc;
    }

    protected final void put(float c, float r, char k, int rgb, float a, int p) {
        int i = idx(c, r);
        if (i < 0 || a <= 0.01f) return;
        if (gch[i] != 0 && p < gp[i]) return;
        gch[i] = k; grgb[i] = rgb & 0xffffff; ga[i] = Math.min(1, a); gp[i] = p;
    }

    protected final void addc(float c, float r, char k, int rgb, float a, int p) {
        int i = idx(c, r);
        if (i < 0 || a <= 0.01f) return;
        if (gch[i] == 0 || p > gp[i]){ put(c, r, k, rgb, a, p); return; }
        if (p < gp[i]) return;
        float oa = ga[i], wo = oa / (oa + a), wn = a / (oa + a);
        int o = grgb[i];
        int rr = (int) clamp(((o >> 16) & 255) * wo + ((rgb >> 16) & 255) * (wn + a * 0.25f), 0, 255);
        int gg = (int) clamp(((o >> 8) & 255) * wo + ((rgb >> 8) & 255) * (wn + a * 0.25f), 0, 255);
        int bb = (int) clamp((o & 255) * wo + (rgb & 255) * (wn + a * 0.25f), 0, 255);
        grgb[i] = (rr << 16) | (gg << 8) | bb;
        if (a > oa) gch[i] = k;
        ga[i] = Math.min(1, oa + a);
    }

    protected final void line(float c0, float r0, float c1, float r1, int rgb, float a, int p, char flat) {
        float dc = c1 - c0, dr = r1 - r0;
        int n = Math.max(1, (int) Math.ceil(Math.max(Math.abs(dc), Math.abs(dr))));
        char k = slopeChar(dc * cw, dr * ch, flat);
        for (int i = 0; i <= n; i++){ float q = (float) i / n; put(c0 + dc * q, r0 + dr * q, k, rgb, a, p); }
    }

    protected final void text(float c, float r, String s, int rgb, float a, int p) {
        for (int i = 0; i < s.length(); i++) if (s.charAt(i) != ' ') put(c + i, r, s.charAt(i), rgb, a, p);
    }

    protected interface DiscFn { void at(int c, int r, float d, float dx, float dy); }

    protected final void disc(float cc, float rr, float rad, DiscFn fn) {
        for (int r = (int) Math.floor(rr - rad - 1); r <= rr + rad + 1; r++)
            for (int c = (int) Math.floor(cc - rad * asp - 1); c <= cc + rad * asp + 1; c++){
                float dx = (c - cc) / asp, dy = r - rr, d = (float) Math.hypot(dx, dy) / rad;
                if (d <= 1) fn.at(c, r, d, dx / rad, dy / rad);
            }
    }

    /** estrelas: cada uma {x, y, fase, brilho, cor} */
    protected final float[][] makeStars(int n, int seed) {
        Rng R0 = new Rng(seed);
        float[][] s = new float[n][5];
        for (float[] e : s){ e[0] = R0.next(); e[1] = R0.next(); e[2] = R0.next(); e[3] = R0.next(); e[4] = mix(0xc8d7ff, 0xffecd2, R0.next()); }
        return s;
    }

    protected final int stars(float[][] list, float rowsMax, float alpha, float t, int p) {
        if (alpha <= 0.02f) return 0;
        int n = 0;
        for (float[] s : list){
            float tw = 0.4f + 0.6f * Math.max(0, sin(t * (1 + s[3]) + s[2] * 9));
            put(s[0] * C, s[1] * rowsMax, s[3] > 0.88f ? '+' : (tw > 0.85f ? '+' : '.'), (int) s[4], alpha * tw, p); n++;
        }
        return n;
    }

    protected final void bg(float[] pos, int[] col) { bgPos = pos; bgCol = col; }

    protected final void fillPath(Canvas cv, Path path, int rgb, float k) {
        bgPaint.setShader(null);
        bgPaint.setColor(0xff000000 | scale(rgb, k));
        cv.drawPath(path, bgPaint);
    }

    /* ============================================================ matemática */
    public static float clamp(float x, float a, float b) { return x < a ? a : (x > b ? b : x); }
    public static float smooth(float x) { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); }
    public static float sstep(float a, float b, float x) { return smooth((x - a) / (b - a)); }
    public static float lerp(float a, float b, float k) { return a + (b - a) * k; }
    public static float sin(float x) { return (float) Math.sin(x); }
    public static float cos(float x) { return (float) Math.cos(x); }
    public static float pow(float a, float b) { return (float) Math.pow(a, b); }
    public static float exp(float a) { return (float) Math.exp(a); }

    public static float hash(int i) {
        i = (i ^ 61 ^ (i >>> 16)) * 9;
        i ^= i >>> 4;
        i *= 0x27d4eb2d;
        i ^= i >>> 15;
        return (i & 0xffffffffL) / 4294967296f;
    }
    public static float h1(float x) { return hash(((int) x) * 374761393 ^ 0x5bd1e995); }
    public static float h2(float x, float y) { return hash(((int) x) * 73856093 ^ ((int) y) * 19349663); }
    public static float h3(float x, float y, float z) { return hash(((int) x) * 73856093 ^ ((int) y) * 19349663 ^ ((int) z) * 83492791); }

    public static float noise1(float x) {
        int i = (int) Math.floor(x);
        float f = x - i, u = f * f * (3 - 2 * f);
        return lerp(h1(i), h1(i + 1), u);
    }
    public static float noise2(float x, float y) {
        int i = (int) Math.floor(x), j = (int) Math.floor(y);
        float fx = x - i, fy = y - j, ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
        return lerp(lerp(h2(i, j), h2(i + 1, j), ux), lerp(h2(i, j + 1), h2(i + 1, j + 1), ux), uy);
    }
    public static float fbm1(float x) { return (noise1(x) * 0.5f + noise1(x * 2.03f + 7) * 0.25f + noise1(x * 4.01f + 13) * 0.125f) / 0.875f; }
    public static float fbm2(float x, float y) { return (noise2(x, y) * 0.5f + noise2(x * 2.03f + 7, y * 2.03f + 3) * 0.25f + noise2(x * 4.01f + 13, y * 4.01f + 5) * 0.125f) / 0.875f; }
    public static float ridged(float x) { return 1 - Math.abs(2 * fbm1(x) - 1); }

    public static final class Rng {
        int s;
        public Rng(int seed) { s = seed == 0 ? 1 : seed; }
        public float next() { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s & 0xffffffffL) / 4294967296f; }
    }

    /* ---------- cor ---------- */
    public static int mix(int a, int b, float k) {
        k = clamp(k, 0, 1);
        int r = (int) lerp((a >> 16) & 255, (b >> 16) & 255, k);
        int g = (int) lerp((a >> 8) & 255, (b >> 8) & 255, k);
        int bl = (int) lerp(a & 255, b & 255, k);
        return (r << 16) | (g << 8) | bl;
    }
    public static int scale(int a, float k) {
        int r = (int) clamp(((a >> 16) & 255) * k, 0, 255), g = (int) clamp(((a >> 8) & 255) * k, 0, 255), b = (int) clamp((a & 255) * k, 0, 255);
        return (r << 16) | (g << 8) | b;
    }
    /** keys: {t0, cor0, t1, cor1, ...} como pares (tempo em float, cor em int) */
    public static int keyColor(float[] ts, int[] cs, float t) {
        if (t <= ts[0]) return cs[0];
        for (int i = 0; i < ts.length - 1; i++) if (t <= ts[i + 1]) return mix(cs[i], cs[i + 1], smooth((t - ts[i]) / (ts[i + 1] - ts[i])));
        return cs[cs.length - 1];
    }

    /* ---------- letras ---------- */
    static final char[][] RAMP = {".`'".toCharArray(), ":;,".toCharArray(), "il!1|".toCharArray(), "rtcz=+<>".toCharArray(),
            "unxvjf{}[]".toCharArray(), "aeosQ%".toCharArray(), "$8B0&#".toCharArray(), "@#$8B%".toCharArray()};
    public static char letter(float b, int id) {
        char[] g = RAMP[(int) clamp(b * RAMP.length, 0, RAMP.length - 1)];
        return g[((int) (hash(id) * g.length)) % g.length];
    }
    public static char slopeChar(float dx, float dy, char flat) {
        float a = (float) Math.abs(Math.atan2(dy, dx));
        if (a > Math.PI / 2) a = (float) Math.PI - a;
        if (a > 1.18f) return '|';
        if (a < 0.40f) return flat;
        return (dx * dy < 0) ? '/' : '\\';
    }
}
