package com.jovone.aguaviva;

import android.content.Context;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** As animações do app. A escolha fica num arquivo,
 *  lido pelo app e pelo papel de parede (que roda em outro processo). */
public final class Cenas {
    public static final String[] IDS = {"agua-viva", "ipe", "vale", "aurora", "natal"};
    public static final String[] NOMES = {"Água-viva", "Ipê · quatro estações", "Vale ao entardecer", "Aurora boreal", "Árvore de Natal"};

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
