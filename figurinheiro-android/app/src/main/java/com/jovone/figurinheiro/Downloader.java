package com.jovone.figurinheiro;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Baixa a mídia (GIF/vídeo/foto) de um post do X sem login, por APIs públicas de incorporação. */
public final class Downloader {
    public static final Pattern X = Pattern.compile(
            "https?://(?:www\\.|mobile\\.)?(?:x|twitter|fxtwitter|vxtwitter|fixupx|fixvx)\\.com/([A-Za-z0-9_]+)/status(?:es)?/(\\d+)",
            Pattern.CASE_INSENSITIVE);
    private static final String UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Mobile Safari/537.36";

    public interface Progress { void status(String s); }

    public static final class Result {
        public final File file; public final String mime;
        Result(File f, String m) { file = f; mime = m; }
    }

    private Downloader() {}

    public static String tweetId(String text) {
        if (text == null) return null;
        Matcher m = X.matcher(text);
        return m.find() ? m.group(2) : null;
    }

    public static Result fetch(String link, File dir, Progress p) throws Exception {
        String id = tweetId(link);
        if (id == null) throw new Exception("Não reconheci um link de post do X.");
        String url = null; boolean video = true;
        Exception err = null;
        try {
            p.status("Procurando o GIF no post…");
            JSONObject t = new JSONObject(new String(get("https://api.fxtwitter.com/status/" + id), "UTF-8")).optJSONObject("tweet");
            JSONObject media = t == null ? null : t.optJSONObject("media");
            if (media != null) {
                JSONArray all = media.optJSONArray("all");
                if (all != null) for (int i = 0; i < all.length() && url == null; i++) {
                    JSONObject o = all.getJSONObject(i);
                    String ty = o.optString("type");
                    if (ty.equals("gif") || ty.equals("video")) url = o.optString("url");
                }
                if (url == null) {
                    JSONArray v = media.optJSONArray("videos");
                    if (v != null && v.length() > 0) url = v.getJSONObject(0).optString("url");
                }
                if (url == null) {
                    JSONArray ph = media.optJSONArray("photos");
                    if (ph != null && ph.length() > 0) { url = ph.getJSONObject(0).optString("url"); video = false; }
                }
            }
        } catch (Exception e) { err = e; }
        if (url == null || url.isEmpty()) {
            try {
                p.status("Tentando outro caminho…");
                JSONObject o = new JSONObject(new String(get("https://api.vxtwitter.com/Twitter/status/" + id), "UTF-8"));
                JSONArray me = o.optJSONArray("media_extended");
                if (me != null) for (int i = 0; i < me.length() && url == null; i++) {
                    JSONObject m = me.getJSONObject(i);
                    String ty = m.optString("type");
                    if (ty.equals("gif") || ty.equals("video")) { url = m.optString("url"); video = true; }
                }
                if (url == null && me != null && me.length() > 0) { url = me.getJSONObject(0).optString("url"); video = false; }
            } catch (Exception e) { err = e; }
        }
        if (url == null || url.isEmpty())
            throw new Exception("Não achei GIF, vídeo ou foto nesse post." + (err != null ? " (" + err.getClass().getSimpleName() + ")" : ""));
        p.status(video ? "Baixando o GIF…" : "Baixando a imagem…");
        if (!dir.exists()) dir.mkdirs();
        File out = new File(dir, "m" + System.currentTimeMillis() + (video ? ".mp4" : ".jpg"));
        try (FileOutputStream o = new FileOutputStream(out)) { o.write(get(url)); }
        return new Result(out, video ? "video/mp4" : "image/jpeg");
    }

    static byte[] get(String u) throws Exception {
        for (int hop = 0; hop < 5; hop++) {
            HttpURLConnection c = (HttpURLConnection) new URL(u).openConnection();
            c.setRequestProperty("User-Agent", UA);
            c.setConnectTimeout(15000);
            c.setReadTimeout(30000);
            c.setInstanceFollowRedirects(true);
            int code = c.getResponseCode();
            if (code >= 300 && code < 400 && c.getHeaderField("Location") != null) { u = c.getHeaderField("Location"); c.disconnect(); continue; }
            if (code != 200) { c.disconnect(); throw new Exception("HTTP " + code); }
            try (InputStream in = c.getInputStream(); ByteArrayOutputStream b = new ByteArrayOutputStream()) {
                byte[] buf = new byte[16384]; int n;
                while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
                return b.toByteArray();
            } finally { c.disconnect(); }
        }
        throw new Exception("Redirecionamentos demais");
    }
}
