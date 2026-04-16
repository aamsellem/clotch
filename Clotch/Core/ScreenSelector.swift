import AppKit

/// Helps pick the display to show the notch panel on.
/// Prefers the built-in display; falls back to the user's selected screen or the main screen.
enum ScreenSelector {
    static func preferred(settings: AppSettings) -> NSScreen {
        // If user picked a specific screen
        if settings.selectedScreenID != 0 {
            if let screen = NSScreen.screens.first(where: { $0.displayID == settings.selectedScreenID }) {
                return screen
            }
        }
        // Default: built-in display (has the notch)
        return NSScreen.builtIn ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
