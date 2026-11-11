package com.jovone.figurinheiro;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.MimeTypeMap;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class MainActivity extends Activity {
    private static final int REQ_FILE = 100, REQ_WA = 200;
    private static final String HOST = "app.local";
    private WebView web;
    private boolean pageReady = false;
    private Intent pending;
    private ValueCallback<Uri[]> fileCb;
    private String lastClip = "";

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        web = new WebView(this);
        setContentView(web);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        web.addJavascriptInterface(new Bridge(), "Android");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if (!HOST.equals(u.getHost())) return null;
                return serve(u.getPath());
            }
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if (HOST.equals(u.getHost())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                return true;
            }
            @Override
            public void onPageFinished(WebView v, String url) {
                pageReady = true;
                if (pending != null) { Intent i = pending; pending = null; handle(i); }
                checkClipboard();
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
                if (fileCb != null) fileCb.onReceiveValue(null);
                fileCb = cb;
                Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType("*/*");
                i.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"image/*", "video/*"});
                try { startActivityForResult(Intent.createChooser(i, "Escolha foto, GIF ou vídeo"), REQ_FILE); }
                catch (ActivityNotFoundException e) { fileCb = null; return false; }
                return true;
            }
        });
        pending = getIntent();
        web.loadUrl("https://" + HOST + "/index.html");
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        setIntent(i);
        if (pageReady) handle(i); else pending = i;
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && pageReady) checkClipboard();
    }

    @Override
    public void onBackPressed() {
        js("window.onBack && window.onBack()");
    }

    private void checkClipboard() {
        try {
            ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
            ClipData cd = cm.getPrimaryClip();
            if (cd == null || cd.getItemCount() == 0) return;
            CharSequence t = cd.getItemAt(0).getText();
            if (t == null) return;
            String s = t.toString();
            if (!s.equals(lastClip) && Downloader.tweetId(s) != null) {
                lastClip = s;
                js("window.onClipboard && window.onClipboard(" + JSONObject.quote(s) + ")");
            }
        } catch (Exception ignored) {}
    }

    private void handle(Intent i) {
        if (i == null || !Intent.ACTION_SEND.equals(i.getAction())) return;
        String text = i.getStringExtra(Intent.EXTRA_TEXT);
        Uri stream = i.getParcelableExtra(Intent.EXTRA_STREAM);
        i.setAction(Intent.ACTION_MAIN); // não reprocessar
        if (stream != null) { importUri(stream); return; }
        if (text != null) js("window.onSharedText && window.onSharedText(" + JSONObject.quote(text) + ")");
    }

    private void importUri(Uri uri) {
        new Thread(() -> {
            try {
                String mime = getContentResolver().getType(uri);
                if (mime == null) mime = "image/png";
                String ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime);
                File dir = new File(getCacheDir(), "media"); dir.mkdirs();
                File out = new File(dir, "i" + System.currentTimeMillis() + "." + (ext == null ? "bin" : ext));
                try (InputStream in = getContentResolver().openInputStream(uri); OutputStream o = new FileOutputStream(out)) {
                    byte[] buf = new byte[16384]; int n;
                    while ((n = in.read(buf)) > 0) o.write(buf, 0, n);
                }
                mediaReady(out, mime);
            } catch (Exception e) { jsError("Não consegui abrir o arquivo compartilhado."); }
        }).start();
    }

    private void mediaReady(File f, String mime) {
        js("window.onNativeMedia(" + JSONObject.quote("https://" + HOST + "/media/" + f.getName()) + "," +
                JSONObject.quote(mime) + "," + JSONObject.quote(f.getName()) + ")");
    }

    private void jsError(String m) { js("window.onNativeError(" + JSONObject.quote(m) + ")"); }

    private void js(String code) { runOnUiThread(() -> web.evaluateJavascript(code, null)); }

    private WebResourceResponse serve(String path) {
        try {
            if (path == null || path.equals("/")) path = "/index.html";
            if (path.contains("..")) return null;
            InputStream in; String name;
            if (path.startsWith("/media/")) {
                File f = new File(new File(getCacheDir(), "media"), path.substring(7));
                in = new FileInputStream(f); name = f.getName();
            } else if (path.startsWith("/pack/")) {
                String[] p = path.substring(6).split("/");
                File f = new File(new File(Packs.root(this), p[0]), p[1]);
                in = new FileInputStream(f); name = f.getName();
            } else {
                name = path.substring(1);
                in = getAssets().open(name);
            }
            String ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
            String mime = ext.equals("html") ? "text/html" : ext.equals("js") ? "application/javascript" : ext.equals("webp") ? "image/webp"
                    : ext.equals("mp4") ? "video/mp4" : MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
            WebResourceResponse r = new WebResourceResponse(mime == null ? "application/octet-stream" : mime, "UTF-8", in);
            java.util.Map<String, String> h = new java.util.HashMap<>();
            h.put("Cache-Control", "no-store");
            r.setResponseHeaders(h);
            return r;
        } catch (Exception e) {
            return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", null, null);
        }
    }

    private String waPackage() {
        PackageManager pm = getPackageManager();
        for (String p : new String[]{"com.whatsapp", "com.whatsapp.w4b"}) {
            try { pm.getPackageInfo(p, 0); return p; } catch (Exception ignored) {}
        }
        return null;
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req == REQ_FILE) {
            if (fileCb != null) {
                Uri[] r = null;
                if (res == RESULT_OK && data != null && data.getData() != null) r = new Uri[]{data.getData()};
                fileCb.onReceiveValue(r);
                fileCb = null;
            }
        } else if (req == REQ_WA) {
            String err = data != null ? data.getStringExtra("validation_error") : null;
            boolean ok = res == RESULT_OK;
            js("window.onWaResult(" + ok + "," + JSONObject.quote(err == null ? "" : err) + ")");
        }
    }

    /** Ponte chamada pelo JavaScript da página. */
    public class Bridge {
        @JavascriptInterface
        public void fetchX(String link) {
            new Thread(() -> {
                try {
                    Downloader.Result r = Downloader.fetch(link, new File(getCacheDir(), "media"),
                            s -> js("window.onNativeStatus(" + JSONObject.quote(s) + ")"));
                    mediaReady(r.file, r.mime);
                } catch (Exception e) {
                    jsError(e.getMessage() == null ? "Falha no download." : e.getMessage());
                }
            }).start();
        }

        @JavascriptInterface
        public String saveSticker(String webpB64, boolean animated, String trayB64) {
            try {
                byte[] w = Base64.decode(webpB64, Base64.DEFAULT);
                byte[] t = trayB64 == null || trayB64.isEmpty() ? null : Base64.decode(trayB64, Base64.DEFAULT);
                String id = Packs.add(MainActivity.this, w, animated, t);
                return new JSONObject().put("ok", true).put("pack", id).put("packs", new org.json.JSONArray(Packs.json(MainActivity.this))).toString();
            } catch (Exception e) {
                return "{\"ok\":false,\"error\":" + JSONObject.quote(String.valueOf(e.getMessage())) + "}";
            }
        }

        @JavascriptInterface
        public String packs() { return Packs.json(MainActivity.this); }

        @JavascriptInterface
        public String deleteSticker(String id, String file) {
            Packs.delete(MainActivity.this, id, file);
            return Packs.json(MainActivity.this);
        }

        /** Pergunta ao próprio WhatsApp se o pacote já está instalado nele. */
        @JavascriptInterface
        public boolean isAdded(String id) {
            for (String pkg : new String[]{"com.whatsapp", "com.whatsapp.w4b"}) {
                Uri u = Uri.parse("content://" + pkg + ".provider.sticker_whitelist_check/is_whitelisted").buildUpon()
                        .appendQueryParameter("authority", Packs.AUTHORITY).appendQueryParameter("identifier", id).build();
                try (android.database.Cursor c = getContentResolver().query(u, null, null, null, null)) {
                    if (c != null && c.moveToFirst() && c.getInt(c.getColumnIndexOrThrow("result")) == 1) return true;
                } catch (Exception ignored) {}
            }
            return false;
        }

        @JavascriptInterface
        public void openWhatsApp() {
            runOnUiThread(() -> {
                String pkg = waPackage();
                Intent i = pkg == null ? null : getPackageManager().getLaunchIntentForPackage(pkg);
                if (i != null) startActivity(i);
            });
        }

        @JavascriptInterface
        public boolean hasWhatsApp() { return waPackage() != null; }

        @JavascriptInterface
        public void addToWhatsApp(String id) {
            runOnUiThread(() -> {
                String pkg = waPackage();
                Intent i = new Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK");
                i.putExtra("sticker_pack_id", id);
                i.putExtra("sticker_pack_authority", Packs.AUTHORITY);
                i.putExtra("sticker_pack_name", Packs.name(id));
                if (pkg != null) i.setPackage(pkg);
                try { startActivityForResult(i, REQ_WA); }
                catch (ActivityNotFoundException e) { js("window.onWaResult(false,'WhatsApp não encontrado neste celular.')"); }
            });
        }

        @JavascriptInterface
        public void shareNow(String webpB64) {
            try {
                File dir = new File(getCacheDir(), "share"); dir.mkdirs();
                File[] old = dir.listFiles(); if (old != null) for (File f : old) f.delete();
                File f = new File(dir, "figurinha" + System.currentTimeMillis() + ".webp");
                Packs.write(f, Base64.decode(webpB64, Base64.DEFAULT));
                Uri u = Uri.parse("content://" + Packs.AUTHORITY + "/share/" + f.getName());
                Intent i = new Intent(Intent.ACTION_SEND);
                i.setType("image/webp");
                i.putExtra(Intent.EXTRA_STREAM, u);
                i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                String pkg = waPackage();
                runOnUiThread(() -> {
                    try {
                        if (pkg != null) { i.setPackage(pkg); startActivity(i); }
                        else startActivity(Intent.createChooser(i, "Enviar figurinha"));
                    } catch (Exception e) {
                        i.setPackage(null);
                        startActivity(Intent.createChooser(i, "Enviar figurinha"));
                    }
                });
            } catch (Exception e) { jsError("Não consegui enviar: " + e.getMessage()); }
        }

        @JavascriptInterface
        public boolean saveToGallery(String b64, String name) {
            if (Build.VERSION.SDK_INT < 29) return false;
            try {
                ContentValues v = new ContentValues();
                v.put(MediaStore.Images.Media.DISPLAY_NAME, name);
                v.put(MediaStore.Images.Media.MIME_TYPE, "image/webp");
                v.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Figurinhas");
                Uri u = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, v);
                if (u == null) return false;
                try (OutputStream o = getContentResolver().openOutputStream(u)) { o.write(Base64.decode(b64, Base64.DEFAULT)); }
                return true;
            } catch (Exception e) { return false; }
        }

        @JavascriptInterface
        public void exitApp() { runOnUiThread(MainActivity.this::finish); }
    }
}
