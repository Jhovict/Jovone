package com.jovone.aguaviva;

import android.graphics.Canvas;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

/** Papel de parede animado: desenha a cena escolhida ao vivo, direto na tela, a até 30 quadros/s. */
public class JellyWallpaper extends WallpaperService {

    @Override
    public Engine onCreateEngine() { return new CenaEngine(); }

    class CenaEngine extends Engine {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final long t0 = SystemClock.uptimeMillis();
        private Cena cena;
        private int qual = -1, w, h;
        private boolean visible;
        private final Runnable tick = this::drawFrame;

        private void conferirCena() {
            int c = Cenas.atual(JellyWallpaper.this);       // relido sempre que o fundo aparece
            if (c != qual || cena == null){
                qual = c;
                cena = Cena.criar(c);
                if (w > 0) cena.setSize(w, h);
            }
        }

        @Override
        public void onVisibilityChanged(boolean v) {
            visible = v;
            handler.removeCallbacks(tick);
            if (v){ conferirCena(); drawFrame(); }       // fora da tela não desenha nada
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            super.onSurfaceChanged(holder, format, width, height);
            w = width; h = height;
            conferirCena();
            cena.setSize(width, height);
            drawFrame();
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            super.onSurfaceDestroyed(holder);
            visible = false;
            handler.removeCallbacks(tick);
        }

        @Override
        public void onDestroy() {
            super.onDestroy();
            handler.removeCallbacks(tick);
        }

        private void drawFrame() {
            long start = SystemClock.uptimeMillis();
            SurfaceHolder holder = getSurfaceHolder();
            Canvas c = null;
            try {
                c = Build.VERSION.SDK_INT >= 26 ? holder.getSurface().lockHardwareCanvas() : holder.lockCanvas();
                if (c != null && cena != null) cena.draw(c, (start - t0) / 1000f);
            } catch (Exception ignored) {
            } finally {
                if (c != null) {
                    try {
                        if (Build.VERSION.SDK_INT >= 26) holder.getSurface().unlockCanvasAndPost(c);
                        else holder.unlockCanvasAndPost(c);
                    } catch (Exception ignored) { }
                }
            }
            handler.removeCallbacks(tick);
            if (visible) handler.postDelayed(tick, Math.max(1, 33 - (SystemClock.uptimeMillis() - start)));
        }
    }
}
