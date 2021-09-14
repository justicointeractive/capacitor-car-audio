import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CarAudioPlugin)
public class CarAudioPlugin: CAPPlugin {
    @objc func setRoot(_ call: CAPPluginCall) {
        let url = call.getString("url") ?? ""
        UserDefaults.standard.setCarAudioPluginUrl(url)
        call.resolve()
    }
}

extension UserDefaults {
    @objc dynamic var carAudioPluginUrl: String? {
        return string(forKey: "carAudioPluginUrl")
    }
    func setCarAudioPluginUrl(_ url: String) {
        setValue(url, forKey: "carAudioPluginUrl")
        synchronize()
    }
}
