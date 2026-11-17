package com.jovone.aguaviva;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.RadialGradient;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;

/**
 * Buraco negro realista (sem letras): fios de luz num disco quase de lado, o arco curvado
 * por cima da sombra, anel fino por baixo e névoa ao fundo. Loop perfeito de 20 s.
 * Porte de buraco-negro-realista/index.html.
 */
public class CenaBuracoNegro implements Cena {

    static final float TAU = (float) (Math.PI * 2), LOOP = 20;
    static final float INC = 1.36f, CI = (float) Math.cos(INC), ROLL_DEG = (float) Math.toDegrees(-0.33);
    static final float RS = 1, R_IN = 1.75f, R_OUT = 9.5f;

    // fios: raio, voltas por loop, ângulo inicial, comprimento, largura, alfa
    final float[][] strands, hood, stars;
    int W, H;
    float U, cx, cy, px;
    Bitmap fog;
    final Paint pStroke = new Paint(Paint.ANTI_ALIAS_FLAG), pFill = new Paint(Paint.ANTI_ALIAS_FLAG), pBmp = new Paint(Paint.FILTER_BITMAP_FLAG);
    final RectF oval = new RectF();
    final Rect src = new Rect(), dst = new Rect();
    SweepGradient doppler;

    public CenaBuracoNegro() {
        Motor.Rng R = new Motor.Rng(2024);
        strands = new float[1100][6];
        for (float[] s : strands){
            float u = (float) Math.pow(R.next(), 1.7);
            float r = R_IN + (R_OUT - R_IN) * u;
            s[0] = r; s[1] = Math.max(1, Math.round(6 * Math.pow(R_IN / r, 1.5)));
            s[2] = R.next() * TAU; s[3] = 0.5f + R.next() * (u < 0.3f ? 4.5f : 2.6f);
            s[4] = 0.5f + R.next() * 1.4f; s[5] = ((0.03f + 0.12f * R.next()) * (float) Math.pow(1 - u, 0.9) + 0.012f) * 1.25f;
        }
        hood = new float[650][6];
        for (float[] s : hood){
            float u = (float) Math.pow(R.next(), 1.2);
            s[0] = RS * (1.04f + 0.95f * (float) Math.pow(u, 0.8)); s[1] = Math.max(1, Math.round(6 / (1 + 4 * u)));
            s[2] = R.next() * TAU; s[3] = 1.2f + R.next() * 3.2f;
            s[4] = 0.6f + R.next() * 1.6f; s[5] = ((0.05f + 0.13f * R.next()) * (1 - 0.8f * u) + 0.015f) * 1.25f;
        }
        stars = new float[420][4];
        for (float[] s : stars){ s[0] = R.next(); s[1] = R.next(); s[2] = R.next(); s[3] = R.next(); }
        pStroke.setStyle(Paint.Style.STROKE);
        pStroke.setStrokeCap(Paint.Cap.BUTT);
        doppler = new SweepGradient(0, 0,
                new int[]{0xfffff6ff, 0xfff0bcec, 0xffa046aa, 0xfff0bcec, 0xfffff6ff},
                new float[]{0f, 0.2f, 0.5f, 0.8f, 1f});
    }

    @Override public float loop() { return LOOP; }

    @Override
    public void setSize(int w, int h) {
        if (w == W && h == H) return;
        W = w; H = h;
        boolean land = w > h;
        U = land ? h * 0.26f : w * 0.3f;
        cx = w * (land ? 0.62f : 0.56f); cy = h * (land ? 0.34f : 0.42f);
        px = Math.max(1, w / 400f);                         // 1 "pixel" da versão web
        // névoa: feita uma vez
        int fw = Math.max(2, w / 3), fh = Math.max(2, h / 3);
        if (fog != null) fog.recycle();
        fog = Bitmap.createBitmap(fw, fh, Bitmap.Config.ARGB_8888);
        Canvas f = new Canvas(fog);
        Paint p = new Paint();
        p.setShader(new LinearGradient(0, 0, fw, fh, new int[]{0xff080a0a, 0xff121817, 0xff060707}, new float[]{0, 0.45f, 1}, Shader.TileMode.CLAMP));
        f.drawRect(0, 0, fw, fh, p);
        Motor.Rng Rf = new Motor.Rng(7);
        for (int i = 0; i < 90; i++){
            float k = Rf.next();
            float x = fw * (0.1f + 0.9f * k) + (Rf.next() - 0.5f) * fw * 0.5f, y = fh * (0.95f - 0.95f * k) + (Rf.next() - 0.5f) * fh * 0.35f;
            float rr = (0.08f + 0.2f * Rf.next()) * Math.max(fw, fh);
            int a = (int) (255 * (0.025f + 0.035f * Rf.next()));
            p.setShader(new RadialGradient(x, y, rr, (a << 24) | 0x46605c, 0x0046605c, Shader.TileMode.CLAMP));
            f.drawRect(x - rr, y - rr, x + rr, y + rr, p);
        }
    }

    void arcs(Canvas c, float[][] list, float t, float from, float to, float mult, boolean disk) {
        for (float[] s : list){
            float a1 = s[2] + TAU * s[1] * t / LOOP, a2 = a1 + s[3];
            float rad = s[0] * U;
            oval.set(-rad, -rad, rad, rad);
            pStroke.setStrokeWidth(s[4] * px * (disk ? 0.9f / CI : 1));
            pStroke.setAlpha((int) Motor.clamp(255 * s[5] * mult, 0, 255));
            for (int k = -1; k <= 1; k++){
                float lo = Math.max(a1, from + k * TAU), hi = Math.min(a2, to + k * TAU);
                if (hi <= lo) continue;
                c.drawArc(oval, (float) Math.toDegrees(lo), (float) Math.toDegrees(hi - lo), false, pStroke);
            }
        }
    }

    void disk(Canvas c, float t, boolean front) {
        c.save();
        c.translate(cx, cy); c.rotate(ROLL_DEG); c.scale(1, CI);
        final float PI = (float) Math.PI, FADE = 0.5f, BACK = 0.1f;
        final int STEPS = 3;
        if (front){
            arcs(c, strands, t, 0, PI, 1, true);
            for (int k = 0; k < STEPS; k++){
                float m = 1 - (k + 0.5f) / STEPS * (1 - BACK), w = FADE / STEPS;
                arcs(c, strands, t, -w * (k + 1), -w * k, m, true);
                arcs(c, strands, t, PI + w * k, PI + w * (k + 1), m, true);
            }
        } else arcs(c, strands, t, PI + FADE, TAU - FADE, BACK, true);
        c.restore();
    }

    @Override
    public void draw(Canvas c, float T) {
        if (W == 0) return;
        float t = ((T % LOOP) + LOOP) % LOOP;
        // fundo
        src.set(0, 0, fog.getWidth(), fog.getHeight()); dst.set(0, 0, W, H);
        pBmp.setXfermode(null);
        c.drawBitmap(fog, src, dst, pBmp);
        pFill.setXfermode(null); pFill.setShader(null); pFill.setStyle(Paint.Style.FILL);
        for (float[] s : stars){
            float tw = 0.4f + 0.6f * Math.max(0, (float) Math.sin(TAU * Math.round(1 + 3 * s[3]) * t / LOOP + s[2] * 9));
            pFill.setColor(Color.argb((int) (255 * (0.15f + 0.55f * s[3]) * tw), 220, 230, 240));
            c.drawCircle(s[0] * W, s[1] * H, (s[3] > 0.96f ? 1.0f : 0.6f) * px, pFill);
        }
        // halo suave em volta (substitui o brilho borrado da versão web)
        pFill.setShader(new RadialGradient(cx, cy, U * 3.2f, new int[]{0x40f0c8f0, 0x18b070c0, 0x00000000}, new float[]{0.25f, 0.55f, 1}, Shader.TileMode.CLAMP));
        c.drawCircle(cx, cy, U * 3.2f, pFill);
        pFill.setShader(null);

        pStroke.setShader(doppler);
        pStroke.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.ADD));
        disk(c, t, false);                                   // metade de trás, fraca
        // a sombra
        pStroke.setXfermode(null);
        pFill.setColor(0xff050506);
        c.drawCircle(cx, cy, RS * U, pFill);
        pStroke.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.ADD));
        // o arco por cima
        c.save();
        c.translate(cx, cy); c.rotate(ROLL_DEG);
        arcs(c, hood, t, (float) Math.PI - 0.12f, TAU + 0.12f, 1, false);
        // anel fino por baixo
        pStroke.setShader(null);
        float r0 = RS * U * 1.04f;
        oval.set(-r0, -r0, r0, r0);
        pStroke.setColor(0xfff096eb); pStroke.setAlpha(128); pStroke.setStrokeWidth(1.4f * px);
        c.drawArc(oval, (float) Math.toDegrees(0.05), (float) Math.toDegrees(Math.PI - 0.1), false, pStroke);
        for (int k = 0; k < 6; k++){
            float rr = RS * U * (1.1f + k * 0.035f);
            oval.set(-rr, -rr, rr, rr);
            pStroke.setColor(0xffe178e1); pStroke.setAlpha((int) (255 * (0.09f - k * 0.012f))); pStroke.setStrokeWidth((1 + k * 0.6f) * px);
            c.drawArc(oval, (float) Math.toDegrees(0.08), (float) Math.toDegrees(Math.PI - 0.16), false, pStroke);
        }
        c.restore();
        pStroke.setShader(doppler);
        disk(c, t, true);                                    // metade da frente, por cima da sombra
        pStroke.setXfermode(null);
    }
}
