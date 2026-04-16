import SwiftUI

@main
struct ClotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scene — the app runs as an accessory (no dock icon)
        // All UI is managed via the NotchPanel in AppDelegate
        Settings {
            EmptyView()
        }
    }
}
