import Foundation
import Combine
import ServiceManagement

/// Persistent user settings stored in UserDefaults
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var selectedScreenID: UInt32 {
        get { UInt32(defaults.integer(forKey: "selectedScreenID")) }
        set { defaults.set(Int(newValue), forKey: "selectedScreenID") }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: "soundEnabled") }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    var soundName: String {
        get { defaults.string(forKey: "soundName") ?? "default" }
        set { defaults.set(newValue, forKey: "soundName") }
    }

    var hideSprite: Bool {
        get { defaults.bool(forKey: "hideSprite") }
        set { defaults.set(newValue, forKey: "hideSprite") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            if newValue {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    var sentimentEnabled: Bool {
        get {
            if defaults.object(forKey: "sentimentEnabled") == nil { return true }
            return defaults.bool(forKey: "sentimentEnabled")
        }
        set { defaults.set(newValue, forKey: "sentimentEnabled") }
    }

    init() {}
}
