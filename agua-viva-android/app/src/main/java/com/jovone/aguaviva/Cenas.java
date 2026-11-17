package com.jovone.aguaviva;

import android.content.Context;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** As animações do app. A escolha fica num arquivo,
 *  lido pelo app e pelo papel de parede (que roda em outro processo). */
public final class Cenas {
    public static final String[] IDS = {"agua-viva", "ipe", "vale", "aurora", "natal", "buraco-negro",
        "ipe-16bit-noite", "ipe-16bit-dia", "ipe-pontilhismo", "agua-viva-16bit-noite", "agua-viva-16bit-dia", "agua-viva-pontilhismo"};
    public static final String[] NOMES = {"Água-viva", "Ipê · quatro estações", "Vale ao entardecer", "Aurora boreal", "Árvore de Natal", "Buraco negro",
        "Ipê · 16 bits noite", "Ipê · 16 bits dia", "Ipê · pontilhismo", "Água-viva · 16 bits noite", "Água-viva · 16 bits fundo do mar", "Água-viva · pontilhismo"};

    /** Cenas que vêm prontas em vídeo (res/raw) em vez de desenhadas ao vivo; 0 = desenhada. */
    public static int video(int i) {
        switch (i) {
            case 6: return R.raw.ipe_16bit_noite;
            case 7: return R.raw.ipe_16bit_dia;
            case 8: return R.raw.ipe_pontilhismo;
            case 9: return R.raw.aguaviva_16bit_noite;
            case 10: return R.raw.aguaviva_16bit_dia;
            case 11: return R.raw.aguaviva_pontilhismo;
            default: return 0;
        }
    }

    private static File arquivo(Context c) { return new File(c.getFilesDir(), "cena.txt"); }

    public static int atual(Context c) {
        try (FileInputStream in = new FileInputStream(arquivo(c))) {
            byte[] buf = new byte[64];
            int n = in.read(buf);
            String id = n > 0 ? new String(buf, 0, n, StandardCharsets.UTF_8).trim() : "";
            for (int i = 0; i < IDS.length; i++) if (IDS[i].equals(id)) return i;
        } catch (Exception ignored) { }
        return 0;
    }

    public static void escolher(Context c, int i) {
        try (FileOutputStream out = new FileOutputStream(arquivo(c))) {
            out.write(IDS[i].getBytes(StandardCharsets.UTF_8));
        } catch (Exception ignored) { }
    }
}
