package com.justicointeractive.plugins.capacitor.caraudio;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CarAudio")
public class CarAudioPlugin extends Plugin {

    @PluginMethod
    public void setRoot(PluginCall call) {
        call.unimplemented();
    }
}
