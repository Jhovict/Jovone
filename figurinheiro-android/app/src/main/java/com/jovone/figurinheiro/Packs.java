package com.jovone.figurinheiro;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/** Pacotes de figurinhas guardados em files/packs/<id>/ (até 30 por pacote, estáticas e animadas separadas). */
public final class Packs {
    public static final int MAX = 30;
    public static final String AUTHORITY = "com.jovone.figurinheiro.stickercontentprovider";

    private Packs() {}

    public static File root(Context c) {
        File r = new File(c.getFilesDir(), "packs");
        if (!r.exists()) r.mkdirs();
        return r;
    }

    public static boolean isAnimated(String id) { return id.startsWith("animadas-"); }

    public static String name(String id) {
        String n = id.substring(id.indexOf('-') + 1);
        return (isAnimated(id) ? "Figurinheiro Animadas " : "Figurinheiro ") + n;
    }

    public static List<String> ids(Context c) {
        String[] l = root(c).list();
        List<String> out = new ArrayList<>();
        if (l == null) return out;
        Arrays.sort(l, (a, b) -> {
            int k = a.substring(0, a.indexOf('-')).compareTo(b.substring(0, b.indexOf('-')));
            if (k != 0) return k;
            return Integer.compare(num(a), num(b));
        });
        for (String s : l) if (s.startsWith("estaticas-") || s.startsWith("animadas-")) out.add(s);
        return out;
    }

    private static int num(String id) {
        try { return Integer.parseInt(id.substring(id.indexOf('-') + 1)); } catch (Exception e) { return 0; }
    }

    public static List<File> stickers(Context c, String id) {
        File[] f = new File(root(c), id).listFiles((d, n) -> n.endsWith(".webp"));
        List<File> out = new ArrayList<>();
        if (f == null) return out;
        Arrays.sort(f, (a, b) -> a.getName().compareTo(b.getName()));
        out.addAll(Arrays.asList(f));
        return out;
    }

    public static String version(Context c, String id) {
        return String.valueOf(prefs(c).getInt("v_" + id, 1));
    }

    private static void bump(Context c, String id) {
        SharedPreferences p = prefs(c);
        p.edit().putInt("v_" + id, p.getInt("v_" + id, 1) + 1).apply();
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences("packs", Context.MODE_PRIVATE);
    }

    /** Salva a figurinha no último pacote com espaço (ou cria um novo). Retorna o id do pacote. */
    public static synchronized String add(Context c, byte[] webp, boolean animated, byte[] trayPng) throws Exception {
        String prefix = animated ? "animadas-" : "estaticas-";
        String target = null;
        int last = 0;
        for (String id : ids(c)) {
            if (!id.startsWith(prefix)) continue;
            last = Math.max(last, num(id));
            if (stickers(c, id).size() < MAX) target = id;
        }
        if (target == null) target = prefix + (last + 1);
        File dir = new File(root(c), target);
        if (!dir.exists()) dir.mkdirs();
        String name = "s" + System.currentTimeMillis() + ".webp";
        write(new File(dir, name), webp);
        File tray = new File(dir, "tray.png");
        if ((!tray.exists() || stickers(c, target).size() == 1) && trayPng != null && trayPng.length > 0) write(tray, trayPng);
        bump(c, target);
        return target;
    }

    public static synchronized void delete(Context c, String id, String file) {
        if (file.contains("/") || id.contains("/")) return;
        File f = new File(new File(root(c), id), file);
        if (f.delete()) bump(c, id);
        if (stickers(c, id).isEmpty()) {
            new File(new File(root(c), id), "tray.png").delete();
            new File(root(c), id).delete();
        }
    }

    static void write(File f, byte[] data) throws Exception {
        try (FileOutputStream o = new FileOutputStream(f)) { o.write(data); }
    }

    public static String json(Context c) {
        JSONArray arr = new JSONArray();
        try {
            for (String id : ids(c)) {
                JSONObject o = new JSONObject();
                o.put("id", id);
                o.put("name", name(id));
                o.put("animated", isAnimated(id));
                JSONArray s = new JSONArray();
                for (File f : stickers(c, id)) s.put(f.getName());
                o.put("stickers", s);
                arr.put(o);
            }
        } catch (Exception ignored) {}
        return arr.toString();
    }
}
