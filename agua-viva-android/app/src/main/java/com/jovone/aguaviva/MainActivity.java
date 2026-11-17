package com.jovone.aguaviva;

import android.app.Activity;
import android.app.WallpaperManager;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

/** Tela do app: prévia da cena, setas para escolher e botão para definir como papel de parede. */
public class MainActivity extends Activity {

    /** Prévia: desenha a mesma Cena que vai para o fundo. */
    static class Previa extends View {
        Cena cena;
        final long t0 = SystemClock.uptimeMillis();
        Previa(Context c) { super(c); }
        void usar(Cena c) { cena = c; if (getWidth() > 0) cena.setSize(getWidth(), getHeight()); invalidate(); }
        @Override protected void onSizeChanged(int w, int h, int ow, int oh) { if (cena != null) cena.setSize(w, h); }
        @Override protected void onDraw(Canvas c) {
            long now = SystemClock.uptimeMillis();
            if (cena != null) cena.draw(c, (now - t0) / 1000f);
            postInvalidateDelayed(Math.max(1, 33 - (SystemClock.uptimeMillis() - now)));
        }
    }

    private Previa previa;
    private VideoView video;
    private TextView nome;
    private int cena;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        previa = new Previa(this);
        root.addView(previa);

        video = new VideoView(this);                       // prévia das cenas que vêm em vídeo
        video.setVisibility(View.GONE);
        video.setOnPreparedListener(mp -> { mp.setLooping(true); mp.setVolume(0f, 0f); });
        root.addView(video, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.CENTER));

        LinearLayout painel = new LinearLayout(this);
        painel.setOrientation(LinearLayout.VERTICAL);
        painel.setGravity(Gravity.CENTER_HORIZONTAL);
        painel.setPadding(dp(16), dp(12), dp(16), dp(36));
        GradientDrawable fundo = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, new int[]{0xEE05070D, 0x0005070D});
        painel.setBackground(fundo);

        LinearLayout seletor = new LinearLayout(this);
        seletor.setGravity(Gravity.CENTER_VERTICAL);
        Button ant = seta("◀"), prox = seta("▶");
        nome = new TextView(this);
        nome.setTextColor(Color.WHITE);
        nome.setTextSize(17);
        nome.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        nome.setGravity(Gravity.CENTER);
        seletor.addView(ant, new LinearLayout.LayoutParams(dp(52), dp(52)));
        seletor.addView(nome, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        seletor.addView(prox, new LinearLayout.LayoutParams(dp(52), dp(52)));
        painel.addView(seletor, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        Button definir = new Button(this);
        definir.setText("Definir como papel de parede");
        definir.setAllCaps(false);
        definir.setTextColor(Color.WHITE);
        definir.setTextSize(16);
        definir.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xCC0F1622);
        bg.setStroke(dp(1), 0xFF58A6FF);
        bg.setCornerRadius(dp(26));
        definir.setBackground(bg);
        definir.setPadding(dp(26), dp(14), dp(26), dp(14));
        LinearLayout.LayoutParams lpb = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpb.topMargin = dp(14);
        painel.addView(definir, lpb);

        TextView dica = new TextView(this);
        dica.setText("Se já estiver como fundo, é só escolher aqui e voltar para a tela inicial.");
        dica.setTextColor(0xFF8B95A5);
        dica.setTextSize(12);
        dica.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lpd = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpd.topMargin = dp(10);
        painel.addView(dica, lpd);

        root.addView(painel, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM));
        setContentView(root);

        ant.setOnClickListener(v -> mostrar((cena + Cenas.IDS.length - 1) % Cenas.IDS.length));
        prox.setOnClickListener(v -> mostrar((cena + 1) % Cenas.IDS.length));
        definir.setOnClickListener(v -> definir());
        mostrar(Cenas.atual(this));
    }

    private Button seta(String s) {
        Button b = new Button(this);
        b.setText(s);
        b.setTextColor(0xFF58A6FF);
        b.setTextSize(20);
        GradientDrawable g = new GradientDrawable();
        g.setColor(0x660F1622);
        g.setCornerRadius(dp(26));
        b.setBackground(g);
        return b;
    }

    private void mostrar(int i) {
        cena = i;
        nome.setText(Cenas.NOMES[i]);
        Cenas.escolher(this, i);
        int v = Cenas.video(i);
        if (v != 0){
            previa.setVisibility(View.GONE);
            video.setVisibility(View.VISIBLE);
            video.setVideoURI(Uri.parse("android.resource://" + getPackageName() + "/" + v));
            video.start();
        } else {
            video.stopPlayback();
            video.setVisibility(View.GONE);
            previa.setVisibility(View.VISIBLE);
            previa.usar(Cena.criar(i));
        }
    }

    private void definir() {
        Cenas.escolher(this, cena);
        try {
            Intent i = new Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER);
            i.putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, new ComponentName(this, JellyWallpaper.class));
            startActivity(i);
        } catch (ActivityNotFoundException e) {
            try {
                startActivity(new Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER));
                Toast.makeText(this, "Escolha \"Água-Viva ASCII\" na lista", Toast.LENGTH_LONG).show();
            } catch (ActivityNotFoundException e2) {
                Toast.makeText(this, "Este celular não abriu o seletor de papel de parede animado", Toast.LENGTH_LONG).show();
            }
        }
    }


    @Override
    protected void onResume() {
        super.onResume();
        if (video != null && video.getVisibility() == View.VISIBLE) video.start();
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }
}
