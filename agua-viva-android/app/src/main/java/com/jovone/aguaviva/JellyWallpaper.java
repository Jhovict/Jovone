package com.jovone.aguaviva;

import android.graphics.Canvas;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

/** Papel de parede animado: desenha a água-viva ao vivo, a 30 quadros por segundo. */
public class JellyWallpaper extends WallpaperService {

    @Override
    public Engine onCreateEngine() { return new JellyEngine(); }

    class JellyEngine extends Engine {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Renderer renderer = new Renderer();
        private final long t0 = SystemClock.uptimeMillis();
        private boolean visible;
        private static final long FRAME_MS = 1000 / 30;

        private final Runnable tick = new Runnable() {
            @Override public void run() { drawFrame(); }
        };

        @Override
        public void onVisibilityChanged(boolean v) {
            visible = v;
            handler.removeCallbacks(tick);
            if (v) drawFrame();          // fora da tela, para de desenhar e não gasta bateria
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            super.onSurfaceChanged(holder, format, width, height);
            renderer.setSize(width, height);
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
                if (c != null) {
                    float t = ((start - t0) / 1000f) % Renderer.LOOP;
                    renderer.draw(c, t);
                }
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
            if (visible) {
                long spent = SystemClock.uptimeMillis() - start;
                handler.postDelayed(tick, Math.max(1, FRAME_MS - spent));
            }
        }
    }
}
