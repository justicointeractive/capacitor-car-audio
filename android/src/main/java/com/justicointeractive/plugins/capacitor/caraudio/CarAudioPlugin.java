package com.justicointeractive.plugins.capacitor.caraudio;

import android.content.Context;
import android.content.SharedPreferences;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CarAudio")
public class CarAudioPlugin extends Plugin {

    @PluginMethod
    public void setRoot(PluginCall call) {
        String url = call.getString("url");

        SharedPreferences sharedPreferences = this.getContext().getSharedPreferences("carAudio", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putString("rootUrl", url);
        editor.apply();
        call.resolve();
    }
}
