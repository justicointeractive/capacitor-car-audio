package com.justicointeractive.plugins.capacitor.caraudio;

import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.os.IBinder;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaDescriptionCompat;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media.MediaBrowserServiceCompat;
import androidx.media.utils.MediaConstants;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.JsonObjectRequest;
import com.android.volley.toolbox.Volley;
import com.getcapacitor.CapConfig;
import com.justicointeractive.plugins.capacitor.audio.AudioPluginService;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

public class CarAudioMediaBrowserService extends MediaBrowserServiceCompat {
    AudioPluginService service;
    RequestQueue requestQueue;
    
    private boolean rootHasBeenRequestedByAndroidAuto = false;

    @Override
    public void onCreate() {
        super.onCreate();

        requestQueue = Volley.newRequestQueue(this.getApplicationContext());

        Intent serviceIntent = new Intent(this.getApplicationContext(), AudioPluginService.class);
        this.getApplicationContext()
                .bindService(
                        serviceIntent,
                        new ServiceConnection() {
                            @Override
                            public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
                                AudioPluginService.AudioPluginServiceBinder binder = (AudioPluginService.AudioPluginServiceBinder) iBinder;
                                service = binder.getService();
                                CarAudioMediaBrowserService.this.setSessionToken(service.mediaSession.getSessionToken());
                                if (rootHasBeenRequestedByAndroidAuto) {
                                    androidAutoLaunched();
                                }
                            }

                            @Override
                            public void onServiceDisconnected(ComponentName componentName) {
                                service = null;
                            }
                        },
                        Context.BIND_AUTO_CREATE
                );
    }

    @Nullable
    @Override
    public BrowserRoot onGetRoot(@NonNull String clientPackageName, int clientUid, @Nullable Bundle rootHints) {
        if (clientPackageName.equals("com.google.android.projection.gearhead") && !rootHasBeenRequestedByAndroidAuto) {
            rootHasBeenRequestedByAndroidAuto = true;
            if (service != null) {
                androidAutoLaunched();
            }
        }
        return new MediaBrowserServiceCompat.BrowserRoot("0", null);
    }

    @Override
    public void onLoadChildren(@NonNull String parentId, @NonNull Result<List<MediaBrowserCompat.MediaItem>> result) {
        result.detach();

        Log.d("carAudio", "parentId: " + parentId);
        CapConfig capConfig = CapConfig.loadDefault(this.getApplicationContext());
        String defaultRootUrl = capConfig.getPluginConfiguration("capacitor-car-audio").getString("rootUrl", null);
        SharedPreferences prefs = this.getApplicationContext().getSharedPreferences("carAudio", Context.MODE_PRIVATE);
        String rootUrl = prefs.getString("rootUrl", defaultRootUrl);

        if (parentId.equals("0")) {
            JsonObjectRequest request = new JsonObjectRequest(
                    Request.Method.GET,
                    rootUrl,
                    null,
                    response -> {
                        new Thread(() -> {
                            try {
                                JSONArray tabs = response.getJSONArray("items");
                                ArrayList<MediaBrowserCompat.MediaItem> mediaItems = new ArrayList<>();
                                for (int i = 0; i < tabs.length(); i++) {
                                    JSONObject tab = tabs.getJSONObject(i);
                                    int resourceId = this.getResources().getIdentifier(tab.getString("icon"), "drawable", this.getPackageName());
                                    Uri iconContentUri = new Uri.Builder()
                                            .scheme(ContentResolver.SCHEME_ANDROID_RESOURCE)
                                            .authority(this.getPackageName())
                                            .appendPath(String.valueOf(resourceId))
                                            .build();
                                    mediaItems.add(
                                            new MediaBrowserCompat.MediaItem(
                                                    new MediaDescriptionCompat.Builder()
                                                            .setMediaId(tab.getString("url"))
                                                            .setTitle(tab.getString("title"))
                                                            .setIconUri(iconContentUri)
                                                            .build(),
                                                    MediaBrowserCompat.MediaItem.FLAG_BROWSABLE
                                            )
                                    );
                                }
                                result.sendResult(mediaItems);
                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }).start();
                    },
                    error -> {
                        error.printStackTrace();
                    }
            );
            requestQueue.add(request);
        } else {
            URL url;
            try {
                url = new URL(new URL(rootUrl), parentId);
            } catch (MalformedURLException e) {
                e.printStackTrace();
                return;
            }
            JsonObjectRequest request = new JsonObjectRequest(
                    Request.Method.GET,
                    url.toString(),
                    null,
                    response -> {
                        new Thread(() -> {
                            try {
                                JSONArray groups = response.getJSONArray("items");
                                ArrayList<MediaBrowserCompat.MediaItem> mediaItems = new ArrayList<>();
                                for (int groupIndex = 0; groupIndex < groups.length(); groupIndex++) {
                                    JSONObject group = groups.getJSONObject(groupIndex);
                                    JSONArray items = group.getJSONArray("items");
                                    for (int itemIndex = 0; itemIndex < items.length(); itemIndex++) {
                                        JSONObject item = items.getJSONObject(itemIndex);

                                        String itemUrl = item.has("url") ? item.getString("url") : null;

                                        if (itemUrl == null || itemUrl.length() == 0) {
                                            continue;
                                        }

                                        MediaDescriptionCompat.Builder builder = new MediaDescriptionCompat.Builder()
                                                .setTitle(item.getString("title"))
                                                .setMediaId(itemUrl);

                                        try {
                                            if (!item.isNull("imageUrl")) {
                                                String imageUrl = item.getString("imageUrl");

                                                Uri imageFileUri = new Uri.Builder()
                                                        .scheme(ContentResolver.SCHEME_CONTENT)
                                                        .authority(this.getPackageName() + ".caraudiofileprovider")
                                                        .appendPath("imagefetch")
                                                        .appendPath(imageUrl)
                                                        .build();

                                                builder.setIconUri(imageFileUri);
                                            }
                                        } catch (Exception e) {
                                            e.printStackTrace();
                                        }

                                        Bundle extras = new Bundle();
                                        extras.putString(MediaConstants.DESCRIPTION_EXTRAS_KEY_CONTENT_STYLE_GROUP_TITLE, group.getString("title"));
                                        builder.setExtras(extras);

                                        switch (item.getString("type")) {
                                            case "upcoming":
                                                continue;
                                            case "playable":
                                                extras.putString("src", item.getString("url"));
                                                extras.putString("title", item.getString("title"));
                                                extras.putString("artist", item.getString("description"));
                                                extras.putString("artwork", item.getString("artworkUrl"));
                                                extras.putString("itemId", item.getString("itemId"));
                                                extras.putString("contentType", item.getString("contentType"));
                                                extras.putString("car_app_type", "Android Auto");
                                                mediaItems.add(
                                                        new MediaBrowserCompat.MediaItem(builder.build(), MediaBrowserCompat.MediaItem.FLAG_PLAYABLE)
                                                );
                                                break;
                                            case "browsable":
                                                mediaItems.add(
                                                        new MediaBrowserCompat.MediaItem(builder.build(), MediaBrowserCompat.MediaItem.FLAG_BROWSABLE)
                                                );
                                                break;
                                        }
                                    }
                                }
                                result.sendResult(mediaItems);
                            } catch (Exception e) {
                                e.printStackTrace();
                            }


                        }).start();
                    },
                    error -> {
                        error.printStackTrace();
                    }
            );
            requestQueue.add(request);
        }
    }

    private void androidAutoLaunched() {
        Bundle carAppLaunchEventParameters = new Bundle();
        carAppLaunchEventParameters.putString("car_app_type", "Android Auto");
        service.logEventIfFirebaseAnalyticsIsAvailable("car_app_launch", carAppLaunchEventParameters);
    }
}
