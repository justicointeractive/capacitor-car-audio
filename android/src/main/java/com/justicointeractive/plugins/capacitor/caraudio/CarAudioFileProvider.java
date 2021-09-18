package com.justicointeractive.plugins.capacitor.caraudio;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bumptech.glide.Glide;
import com.getcapacitor.Logger;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;

public class CarAudioFileProvider extends ContentProvider {
    @Override
    public boolean onCreate() {
        return false;
    }

    @Nullable
    @Override
    public Cursor query(@NonNull Uri uri, @Nullable String[] strings, @Nullable String s, @Nullable String[] strings1, @Nullable String s1) {
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(@NonNull Uri uri, @Nullable ContentValues contentValues) {
        return null;
    }

    @Override
    public int delete(@NonNull Uri uri, @Nullable String s, @Nullable String[] strings) {
        return 0;
    }

    @Override
    public int update(@NonNull Uri uri, @Nullable ContentValues contentValues, @Nullable String s, @Nullable String[] strings) {
        return 0;
    }

    @Nullable
    @Override
    public ParcelFileDescriptor openFile(@NonNull Uri uri, @NonNull String mode)
            throws FileNotFoundException {
        Context context = this.getContext();

        List<String> segments = uri.getPathSegments();

        File file = null;

        if (segments.get(0).equals("imagefetch")) {
            String imageUrl = segments.get(1);
            try {
                file = Glide.with(context)
                        .downloadOnly()
                        .load(imageUrl)
                        .submit()
                        .get();
            } catch (Exception e) {
                e.printStackTrace();
                throw new FileNotFoundException();
            }
        }

        if (segments.get(0).equals("assets")) {
            String imageUrl = segments.get(1);
            try {
                File cacheDir = context.getExternalCacheDir();
                if (cacheDir == null) {
                    cacheDir = context.getCacheDir();
                }
                File cacheFile = new File(cacheDir, hash(imageUrl));
                if (!cacheFile.exists()) {
                    InputStream in = context.getAssets().open(imageUrl);
                    FileOutputStream out = new FileOutputStream(cacheFile);
                    copyFile(in, out);
                }
                file = cacheFile;

            } catch (Exception e) {
                e.printStackTrace();
                throw new FileNotFoundException();
            }
        }

        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    private String hash(String value) throws NoSuchAlgorithmException, UnsupportedEncodingException {
        final MessageDigest digest = MessageDigest.getInstance("SHA-1");
        byte[] result = digest.digest(value.getBytes("UTF-8"));

        StringBuilder sb = new StringBuilder();

        for (byte b : result)
        {
            sb.append(String.format("%02x", b));
        }

        String messageDigest = sb.toString();

        return messageDigest;
    }

    private void copyFile(InputStream in, FileOutputStream out) {
        byte[] buffer = new byte[1024];
        int read;

        try {
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
            out.close();
        } catch (Exception e) {
            Logger.error("Error copying", e);
        }
    }
}
