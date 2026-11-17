package com.jovone.aguaviva;

import android.content.res.AssetFileDescriptor;
import android.graphics.Canvas;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

/** Papel de parede animado: desenha a cena escolhida ao vivo, direto na tela, a até 30 quadros/s,
 *  ou toca em loop o vídeo da cena, quando ela vem pronta em vídeo. */
public class JellyWallpaper extends WallpaperService {

    @Override
    public Engine onCreateEngine() { return new CenaEngine(); }

    class CenaEngine extends Engine {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final long t0 = SystemClock.uptimeMillis();
        private Cena cena;
        private int qual = -1, w, h;
        private boolean visible, superficie;
        private final Runnable tick = this::drawFrame;

        // vídeo
        private MediaPlayer mp;
        private boolean pronto;
        private int videoAtual;

        private void conferirCena() {
            int c = Cenas.atual(JellyWallpaper.this);       // relido sempre que o fundo aparece
            int v = Cenas.video(c);
            if (v != 0){
                if (cena != null || c != qual || mp == null){ qual = c; cena = null; iniciarVideo(v); }
                return;
            }
            if (c != qual || cena == null){
                pararVideo();
                qual = c;
                cena = Cena.criar(c);
                if (w > 0) cena.setSize(w, h);
            }
        }

        private void iniciarVideo(int res) {
            if (mp != null && videoAtual == res) return;
            pararVideo();
            if (!superficie) return;
            try {
                mp = new MediaPlayer();
                AssetFileDescriptor fd = getResources().openRawResourceFd(res);
                mp.setDataSource(fd.getFileDescriptor(), fd.getStartOffset(), fd.getLength());
                fd.close();
                mp.setSurface(getSurfaceHolder().getSurface());
                mp.setLooping(true);
                mp.setVolume(0f, 0f);
                mp.setOnPreparedListener(p -> {
                    pronto = true;
                    p.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING);
                    if (visible) p.start();
                });
                mp.setOnErrorListener((p, a, b) -> { pararVideo(); return true; });
                videoAtual = res;
                mp.prepareAsync();
            } catch (Exception e) {
                pararVideo();
            }
        }

        private void pararVideo() {
            if (mp != null){
                try { mp.release(); } catch (Exception ignored) { }
            }
            mp = null; pronto = false; videoAtual = 0;
        }

        @Override
        public void onVisibilityChanged(boolean v) {
            visible = v;
            handler.removeCallbacks(tick);
            if (v){
                conferirCena();
                if (mp != null){ if (pronto && !mp.isPlaying()) mp.start(); }
                else drawFrame();
            } else if (mp != null && pronto && mp.isPlaying()) {
                mp.pause();                                  // fora da tela não gasta bateria
            }
        }

        @Override
        public void onSurfaceCreated(SurfaceHolder holder) {
            super.onSurfaceCreated(holder);
            superficie = true;
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            super.onSurfaceChanged(holder, format, width, height);
            superficie = true;
            w = width; h = height;
            conferirCena();
            if (cena != null){ cena.setSize(width, height); drawFrame(); }
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            super.onSurfaceDestroyed(holder);
            superficie = false;
            visible = false;
            handler.removeCallbacks(tick);
            pararVideo();
        }

        @Override
        public void onDestroy() {
            super.onDestroy();
            handler.removeCallbacks(tick);
            pararVideo();
        }

        private void drawFrame() {
            if (cena == null || mp != null) return;          // cena em vídeo: o MediaPlayer desenha
            long start = SystemClock.uptimeMillis();
            SurfaceHolder holder = getSurfaceHolder();
            Canvas c = null;
            try {
                c = Build.VERSION.SDK_INT >= 26 ? holder.getSurface().lockHardwareCanvas() : holder.lockCanvas();
                if (c != null) cena.draw(c, (start - t0) / 1000f);
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
