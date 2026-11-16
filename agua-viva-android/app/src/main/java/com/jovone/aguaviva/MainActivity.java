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
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.Toast;

/** Tela do app: mostra a animação e um botão para definir como papel de parede. */
public class MainActivity extends Activity {

    static class Preview extends View {
        final Renderer r = new Renderer();
        final long t0 = SystemClock.uptimeMillis();
        long last;
        Preview(Context c) { super(c); }

        @Override protected void onSizeChanged(int w, int h, int ow, int oh) { r.setSize(w, h); }

        @Override protected void onDraw(Canvas c) {
            long now = SystemClock.uptimeMillis();
            r.draw(c, ((now - t0) / 1000f) % Renderer.LOOP);
            last = now;
            postInvalidateDelayed(Math.max(1, 33 - (SystemClock.uptimeMillis() - now)));
        }
    }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        root.addView(new Preview(this));

        Button bt = new Button(this);
        bt.setText("Definir como papel de parede");
        bt.setAllCaps(false);
        bt.setTextColor(Color.WHITE);
        bt.setTextSize(16);
        bt.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xCC0F1622);
        bg.setStroke(dp(1), 0xFF58A6FF);
        bg.setCornerRadius(dp(26));
        bt.setBackground(bg);
        bt.setPadding(dp(26), dp(14), dp(26), dp(14));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        lp.bottomMargin = dp(48);
        root.addView(bt, lp);
        bt.setOnClickListener(v -> definir());

        setContentView(root);
    }

    private void definir() {
        try {
            Intent i = new Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER);
            i.putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                    new ComponentName(this, JellyWallpaper.class));
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

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }
}
