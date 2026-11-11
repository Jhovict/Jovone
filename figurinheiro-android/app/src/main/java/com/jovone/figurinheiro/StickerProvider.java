package com.jovone.figurinheiro;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.UriMatcher;
import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.List;

/**
 * Provedor no formato que o WhatsApp lê para pacotes de figurinhas de terceiros
 * (mesmo contrato do exemplo oficial WhatsApp/stickers). Também serve os arquivos
 * temporários de "Enviar agora" em /share/.
 */
public class StickerProvider extends ContentProvider {
    private static final String A = Packs.AUTHORITY;
    private static final int METADATA = 1, METADATA_ONE = 2, STICKERS = 3, ASSET = 4, SHARE = 5;
    private static final UriMatcher M = new UriMatcher(UriMatcher.NO_MATCH);
    static {
        M.addURI(A, "metadata", METADATA);
        M.addURI(A, "metadata/*", METADATA_ONE);
        M.addURI(A, "stickers/*", STICKERS);
        M.addURI(A, "stickers_asset/*/*", ASSET);
        M.addURI(A, "share/*", SHARE);
    }

    private static final String[] META_COLS = {
            "sticker_pack_identifier", "sticker_pack_name", "sticker_pack_publisher", "sticker_pack_icon",
            "android_play_store_link", "ios_app_download_link", "sticker_pack_publisher_email",
            "sticker_pack_publisher_website", "sticker_pack_privacy_policy_website",
            "sticker_pack_license_agreement_website", "image_data_version",
            "whatsapp_will_not_cache_stickers", "animated_sticker_pack"};

    @Override public boolean onCreate() { return true; }

    private Context ctx() { return getContext(); }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        switch (M.match(uri)) {
            case METADATA: {
                MatrixCursor c = new MatrixCursor(META_COLS);
                for (String id : Packs.ids(ctx())) addMeta(c, id);
                return c;
            }
            case METADATA_ONE: {
                MatrixCursor c = new MatrixCursor(META_COLS);
                String id = uri.getLastPathSegment();
                if (Packs.ids(ctx()).contains(id)) addMeta(c, id);
                return c;
            }
            case STICKERS: {
                MatrixCursor c = new MatrixCursor(new String[]{"sticker_file_name", "sticker_emoji", "sticker_accessibility_text"});
                for (File f : Packs.stickers(ctx(), uri.getLastPathSegment()))
                    c.addRow(new Object[]{f.getName(), "😀,😂", "Figurinha"});
                return c;
            }
            default:
                return null;
        }
    }

    private void addMeta(MatrixCursor c, String id) {
        c.addRow(new Object[]{id, Packs.name(id), "Jovone", "tray.png", "", "", "", "", "", "",
                Packs.version(ctx(), id), 0, Packs.isAnimated(id) ? 1 : 0});
    }

    @Override
    public AssetFileDescriptor openAssetFile(Uri uri, String mode) throws FileNotFoundException {
        List<String> seg = uri.getPathSegments();
        File f;
        int m = M.match(uri);
        if (m == ASSET && seg.size() == 3) {
            if (seg.get(1).contains("..") || seg.get(2).contains("..")) throw new FileNotFoundException();
            f = new File(new File(Packs.root(ctx()), seg.get(1)), seg.get(2));
        } else if (m == SHARE && seg.size() == 2) {
            if (seg.get(1).contains("..")) throw new FileNotFoundException();
            f = new File(new File(ctx().getCacheDir(), "share"), seg.get(1));
        } else throw new FileNotFoundException(uri.toString());
        if (!f.exists()) throw new FileNotFoundException(f.getName());
        ParcelFileDescriptor pfd = ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY);
        return new AssetFileDescriptor(pfd, 0, AssetFileDescriptor.UNKNOWN_LENGTH);
    }

    @Override
    public String getType(Uri uri) {
        switch (M.match(uri)) {
            case METADATA: return "vnd.android.cursor.dir/vnd." + A + ".metadata";
            case METADATA_ONE: return "vnd.android.cursor.item/vnd." + A + ".metadata";
            case STICKERS: return "vnd.android.cursor.dir/vnd." + A + ".stickers";
            case ASSET:
            case SHARE: {
                String n = uri.getLastPathSegment();
                return n != null && n.endsWith(".png") ? "image/png" : "image/webp";
            }
            default: return null;
        }
    }

    @Override public Uri insert(Uri uri, ContentValues v) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String s, String[] a) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues v, String s, String[] a) { throw new UnsupportedOperationException(); }
}
