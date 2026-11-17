package com.jovone.aguaviva;

import android.graphics.Canvas;

/** Uma animação de papel de parede: recebe o tamanho da tela e desenha o instante T (segundos). */
public interface Cena {
    void setSize(int w, int h);
    void draw(Canvas c, float T);
    float loop();

    static Cena criar(int i) {
        switch (i) {
            case 1: return new CenaIpe();
            case 2: return new CenaVale();
            case 3: return new CenaAurora();
            case 4: return new CenaNatal();
            case 5: return new CenaBuracoNegro();
            default: return new CenaAguaViva();
        }
    }
}
