package com.jovone.aguaviva;

import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

/**
 * Buraco negro roxo em letras: disco de fios quase de lado e inclinado na diagonal,
 * arco liso por cima da sombra, horizonte com borda de luz, Via Láctea e estrelas.
 * Loop perfeito de 16 s. Porte de bh_roxo.js (versão anterior à realista).
 */
public class CenaBuracoNegro extends Motor {

    @Override protected int cols() { return 120; }
    @Override public float loop() { return 16; }

    static final float INC = 1.40f, ROLL = -0.36f, R_IN = 1.85f, R_OUT = 11f, RS = 1f;
    static final float CI = (float) Math.cos(INC), CA = (float) Math.cos(ROLL), SA = (float) Math.sin(ROLL);
    static final float[] PAL_K = {0, 0.12f, 0.3f, 0.5f, 0.7f, 0.88f, 1.05f};
    static final int[] PAL_C = {0x000000, 0x3a0e46, 0x7a2a8e, 0xc060c8, 0xf0a0ec, 0xffe0fa, 0xffffff};

    float[][] st, big, milky;
    final int[] turnsLUT = new int[1200];

    @Override protected void init() {
        Rng R0 = new Rng(91);
        st = new float[1700][5];
        for (float[] s : st){ s[0] = R0.next(); s[1] = R0.next(); s[2] = R0.next(); s[3] = R0.next(); s[4] = mix(0xc8d2f0, 0xffe8d6, R0.next()); }
        big = new float[22][4];
        for (float[] b : big){ b[0] = R0.next(); b[1] = R0.next(); b[2] = R0.next(); b[3] = mix(0xcfe0ff, 0xffe2c8, R0.next()); }
        milky = new float[2600][4];
        for (float[] m : milky){ m[0] = R0.next(); m[1] = (R0.next() + R0.next() + R0.next() - 1.5f) * 0.11f; m[2] = R0.next(); m[3] = R0.next(); }
    }

    static float pnoise(float x, float u, int P) {
        int i = (int) Math.floor(x), j = (int) Math.floor(u);
        float fx = x - i, fy = u - j, ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
        int j0 = Math.floorMod(j, P), j1 = (j0 + 1) % P;
        return lerp(lerp(h2(i, j0), h2(i + 1, j0), ux), lerp(h2(i, j1), h2(i + 1, j1), ux), uy);
    }
    static int turns(float r) { return Math.max(1, Math.round(8 * pow(R_IN / r, 1.5f))); }

    float emit(float r, float phi, float t, float smoothK) {
        if (r < R_IN || r > R_OUT) return 0;
        float a = phi - TAU * turns(r) * t / 16f;
        float u = ((a / TAU) % 1 + 1) % 1;
        float fib = 0.5f + 0.5f * sin(r * 7.5f + 5 * pnoise(r * 0.9f, u * 5, 5));
        float clump = pnoise(r * 3.2f + 9, u * 10, 10);
        float strands = lerp(pow(fib, 1.6f) * (0.5f + 0.8f * clump), 0.95f, smoothK);
        float radial = pow(R_IN / r, 0.9f) * sstep(R_IN, R_IN + 0.25f, r) * sstep(R_OUT, R_OUT - 3, r);
        float dop = 1 + 0.55f * cos(phi);
        return clamp(radial * (0.2f + strands) * dop * 2.0f, 0, 1.4f);
    }

    static int ink(float b) {
        b = clamp(b, 0, 1.05f);
        for (int i = 0; i < PAL_K.length - 1; i++) if (b <= PAL_K[i + 1]) return mix(PAL_C[i], PAL_C[i + 1], (b - PAL_K[i]) / (PAL_K[i + 1] - PAL_K[i]));
        return PAL_C[PAL_C.length - 1];
    }

    float cxs, cys, U, pulse;

    @Override protected void frame(float t, float T) {
        final float L = 16f;
        cxs = C * 0.6f; cys = R * 0.4f;
        U = Math.min(R * 0.085f, C * 0.19f / asp);

        for (float[] m : milky){
            float along = m[0] * 1.5f - 0.25f, x = along * C, y = R * (0.95f - along * 0.95f) + m[1] * R * 2.2f * (1 + 0.6f * sin(m[0] * 9));
            boolean dust = fbm2(m[0] * 14, m[1] * 40) > 0.58f;
            float a = (dust ? 0.45f : 0.45f + 0.4f * m[2]) * (0.7f + 0.3f * sin(TAU * Math.round(1 + 3 * m[3]) * t / L + m[2] * 9));
            put(x, y, m[3] < 0.08f ? '+' : (m[3] < 0.4f ? ':' : '.'), dust ? 0x8a6a50 : mix(0x9aa0b0, 0xe0d8cc, m[2]), a, 1);
        }
        for (float[] s : st){
            float tw = 0.5f + 0.5f * Math.max(0, sin(TAU * Math.round(2 + 4 * s[3]) * t / L + s[2] * 9));
            put(s[0] * C, s[1] * R, s[3] > 0.95f ? '*' : (s[3] > 0.8f ? '+' : '.'), (int) s[4], 0.35f + 0.6f * tw * s[3], 1);
        }
        for (float[] g : big){
            float tw = 0.6f + 0.4f * sin(TAU * Math.round(1 + 3 * g[2]) * t / L + g[2] * 20);
            float x = g[0] * C, y = g[1] * R; int col = (int) g[3];
            put(x, y, '*', col, tw, 2);
            addc(x - 1, y, '-', col, 0.5f * tw, 2); addc(x + 1, y, '-', col, 0.5f * tw, 2);
            addc(x, y - 1, '\'', col, 0.35f * tw, 2); addc(x, y + 1, '.', col, 0.35f * tw, 2);
        }
        float bx = C * 0.16f, by = R * 0.86f, sp = 0.8f + 0.2f * sin(TAU * 2 * t / L);
        put(bx, by, '*', 0xffffff, 1, 3);
        for (int k = 1; k <= 9; k++){
            float a = (1 - k / 10f) * sp;
            addc(bx - k, by, '-', 0xdce8ff, a, 3); addc(bx + k, by, '-', 0xdce8ff, a, 3);
            if (k <= 5){ addc(bx, by - k * 0.6f, '|', 0xdce8ff, a, 3); addc(bx, by + k * 0.6f, '|', 0xdce8ff, a, 3); }
        }

        // só as células perto do buraco/disco precisam do cálculo pesado
        float reachR = R_OUT * U * 1.05f;
        int rMin = Math.max(0, (int) (cys - reachR)), rMax = Math.min(R - 1, (int) (cys + reachR));
        for (int r = rMin; r <= rMax; r++){
            for (int c = 0; c < C; c++){
                float dx = (c - cxs) / asp, dy = r - cys;
                float X = (dx * CA + dy * SA) / U, Y = (-dx * SA + dy * CA) / U;
                float d = (float) Math.hypot(X, Y);
                float yr = Y / CI;
                if (Math.abs(yr) > R_OUT * 1.05f && d > RS * 2.4f) continue;
                float b = 0, tx = 1, ty = 0;
                boolean front = false;
                float rd = (float) Math.hypot(X, yr), phi = (float) Math.atan2(yr, X);
                float e = emit(rd, phi, t, 0);
                if (e > 0 && (Y > 0 || d > RS)){
                    b = Math.max(e, emit(rd, phi, t, exp(-(rd - R_IN) / 1.2f)) * 0.9f);
                    front = Y > 0; tx = -sin(phi); ty = cos(phi) * CI;
                }
                if (d > RS * 1.02f && !front && d < RS * 2.4f){
                    float psi = (float) Math.atan2(Y, X);
                    if (Y < 0){
                        float rl = R_IN + (d - RS * 1.18f) / 0.42f;
                        float w = 0.25f + 0.75f * pow(Math.abs(sin(psi)), 0.6f);
                        float near = exp(-Math.max(0, d - RS) / 0.75f);
                        float lb = emit(Math.max(rl, R_IN + 0.01f), psi, t, near) * w * 1.05f * (1 + 0.8f * near) * sstep(RS * 2.35f, RS * 1.75f, d);
                        if (lb > b){ b = lb; tx = -sin(psi); ty = cos(psi); }
                    } else {
                        float rl = R_IN + (d - RS * 1.12f) / 0.16f;
                        float w = 0.25f + 0.75f * Math.abs(sin(psi));
                        float lb = emit(rl, -psi, t, 0) * w * 0.75f * sstep(RS * 1.45f, RS * 1.2f, d);
                        if (lb > b){ b = lb; tx = -sin(psi); ty = cos(psi); }
                    }
                }
                float ring = d > RS ? exp(-(d - RS) / 0.13f) * 1.6f : 0;
                if (!front && ring > b){ b = ring; float ps = (float) Math.atan2(Y, X); tx = -sin(ps); ty = cos(ps); }
                if (d < RS && !front){ put(c, r, ' ', 0, 1, 50); continue; }
                if (b < 0.1f) continue;
                float sx = tx * CA - ty * SA, sy = tx * SA + ty * CA;
                float bb = clamp(b * 1.15f, 0, 1.05f);
                char k = bb > 1.0f ? '#' : slopeChar(sx, sy, bb > 0.7f ? '=' : '-');
                put(c, r, k, ink(bb), clamp(0.45f + bb * 0.7f, 0, 1), 10);
            }
        }
        pulse = 0.85f + 0.15f * sin(TAU * 2 * t / L);
        bg(new float[]{0, 0.35f, 0.7f, 1}, new int[]{0x0a0e0e, 0x1a2222, 0x101414, 0x060808});
        dim = 1; glow = 0.55f;
    }

    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF oval = new RectF();

    static int argb(float a, int rgb) { return ((int) (clamp(a, 0, 1) * 255) << 24) | (rgb & 0xffffff); }

    @Override protected void paint(Canvas cv, float dm) {
        float px = (cxs + 0.5f) * cw, py = (cys + 0.5f) * ch, R0 = RS * U * ch;
        p.setStyle(Paint.Style.FILL);
        // halo em volta
        p.setShader(new RadialGradient(px, py, R0 * 1.9f, new int[]{argb(0.55f * pulse * dm, 0xffd6fa), argb(0.55f * pulse * dm, 0xffd6fa), argb(0.25f * pulse * dm, 0xc86ed2), 0x00501a5a},
                new float[]{0, 0.5f, 0.625f, 1}, Shader.TileMode.CLAMP));
        cv.drawCircle(px, py, R0 * 1.9f, p);
        // o arco liso por cima: meia-lua entre R0 e 2.15 R0
        cv.save();
        cv.translate(px, py); cv.rotate((float) Math.toDegrees(ROLL));
        float h0 = R0, h1 = R0 * 2.15f, mid = (h0 + h1) / 2;
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(h1 - h0);
        p.setStrokeCap(Paint.Cap.BUTT);
        p.setShader(new RadialGradient(0, 0, h1, new int[]{argb(0.95f * dm, 0xfffaff), argb(0.95f * dm, 0xfffaff), argb(0.8f * dm, 0xfad7fa), argb(0.45f * dm, 0xc878d2), 0x00782890},
                new float[]{0, 0.465f, 0.6f, 0.786f, 1}, Shader.TileMode.CLAMP));
        oval.set(-mid, -mid, mid, mid);
        cv.drawArc(oval, 180, 180, false, p);
        // mais escuro à esquerda (o lado que se afasta)
        p.setShader(new LinearGradient(-h1, 0, h1, 0, 0x73000000, 0x00000000, Shader.TileMode.CLAMP));
        cv.drawArc(oval, 180, 180, false, p);
        cv.restore();
        // o horizonte: uma borda de luz única
        float b0 = R0 * 0.99f, b1 = R0 * 1.32f, bm = (b0 + b1) / 2;
        p.setStrokeWidth(b1 - b0);
        p.setShader(new RadialGradient(px, py, b1, new int[]{argb(pulse * dm, 0xfff8ff), argb(pulse * dm, 0xfff8ff), argb(0.9f * pulse * dm, 0xffe2fa), argb(0.45f * pulse * dm, 0xe696eb), 0x00963caa},
                new float[]{0, 0.75f, 0.78f, 0.8625f, 1}, Shader.TileMode.CLAMP));
        cv.drawCircle(px, py, bm, p);
        // a sombra
        p.setShader(null);
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xff000000);
        cv.drawCircle(px, py, b0, p);
    }
}
