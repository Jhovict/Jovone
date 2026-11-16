package com.jovone.aguaviva;

import android.annotation.SuppressLint;
import android.app.Presentation;
import android.graphics.Canvas;
import android.graphics.Color;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Papel de parede animado. Cada cena é a mesma página da versão web, rodando num
 * WebView que desenha direto na superfície do papel de parede (por uma tela virtual).
 * Se o aparelho não permitir isso, cai para a água-viva nativa (Renderer).
 */
public class JellyWallpaper extends WallpaperService {

    @Override
    public Engine onCreateEngine() { return new WebEngine(); }

    class WebEngine extends Engine {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private VirtualDisplay display;
        private Presentation presentation;
        private WebView web;
        private int cena = -1;
        private boolean visible, nativo;

        // ---------- plano B: água-viva nativa ----------
        private Renderer renderer;
        private final long t0 = SystemClock.uptimeMillis();
        private final Runnable tick = this::drawNative;

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            super.onSurfaceChanged(holder, format, width, height);
            if (nativo) { renderer.setSize(width, height); drawNative(); return; }
            try {
                int dpi = getResources().getDisplayMetrics().densityDpi;
                if (display == null) criar(holder.getSurface(), width, height, dpi);
                else { display.resize(width, height, dpi); display.setSurface(holder.getSurface()); }
            } catch (Throwable e) {
                liberar();
                nativo = true;
                renderer = new Renderer();
                renderer.setSize(width, height);
                drawNative();
            }
        }

        @SuppressLint("SetJavaScriptEnabled")
        private void criar(Surface surface, int w, int h, int dpi) {
            DisplayManager dm = (DisplayManager) getSystemService(DISPLAY_SERVICE);
            display = dm.createVirtualDisplay("agua-viva-ascii", w, h, dpi, surface, 0);
            presentation = new Presentation(JellyWallpaper.this, display.getDisplay());
            web = new WebView(presentation.getContext());
            web.setBackgroundColor(Color.BLACK);
            web.setVerticalScrollBarEnabled(false);
            web.setHorizontalScrollBarEnabled(false);
            WebSettings s = web.getSettings();
            s.setJavaScriptEnabled(true);
            s.setAllowFileAccess(true);
            web.setWebViewClient(new WebViewClient());
            presentation.setContentView(web, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            presentation.show();
            carregar();
            if (!visible) pausar();
        }

        private void carregar() {
            if (web == null) return;
            int c = Cenas.atual(JellyWallpaper.this);
            if (c != cena) { cena = c; web.loadUrl(Cenas.url(c)); }
        }

        private void pausar() { if (web != null) { web.onPause(); web.pauseTimers(); } }
        private void retomar() { if (web != null) { web.onResume(); web.resumeTimers(); } }

        @Override
        public void onVisibilityChanged(boolean v) {
            visible = v;
            if (nativo) { handler.removeCallbacks(tick); if (v) drawNative(); return; }
            if (v) { carregar(); retomar(); } else pausar();   // fora da tela não gasta bateria
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            super.onSurfaceDestroyed(holder);
            visible = false;
            handler.removeCallbacks(tick);
            liberar();
            cena = -1;
        }

        @Override
        public void onDestroy() {
            super.onDestroy();
            handler.removeCallbacks(tick);
            liberar();
        }

        private void liberar() {
            try { if (presentation != null) presentation.dismiss(); } catch (Throwable ignored) { }
            try { if (web != null) web.destroy(); } catch (Throwable ignored) { }
            try { if (display != null) display.release(); } catch (Throwable ignored) { }
            presentation = null; web = null; display = null;
        }

        private void drawNative() {
            long start = SystemClock.uptimeMillis();
            SurfaceHolder holder = getSurfaceHolder();
            Canvas c = null;
            try {
                c = Build.VERSION.SDK_INT >= 26 ? holder.getSurface().lockHardwareCanvas() : holder.lockCanvas();
                if (c != null) renderer.draw(c, ((start - t0) / 1000f) % Renderer.LOOP);
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
