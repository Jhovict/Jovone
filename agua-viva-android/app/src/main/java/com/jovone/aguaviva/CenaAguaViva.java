package com.jovone.aguaviva;

import android.graphics.Canvas;

/** A água-viva original (Renderer), no formato de Cena. */
public class CenaAguaViva implements Cena {
    private final Renderer r = new Renderer();
    @Override public void setSize(int w, int h) { r.setSize(w, h); }
    @Override public void draw(Canvas c, float T) { r.draw(c, T % Renderer.LOOP); }
    @Override public float loop() { return Renderer.LOOP; }
}
