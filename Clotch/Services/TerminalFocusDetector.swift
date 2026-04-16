import AppKit

/// Detects whether a terminal application is currently focused.
/// Used to mute sounds when the user is already looking at Claude Code output.
final class TerminalFocusDetector {
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "io.alacritty",
        "com.mitchellh.ghostty",
        "co.zeit.hyper",
        "com.cmux.app",
        "dev.warp.Warp-Stable",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.microsoft.VSCode",
    ]

    var isTerminalFocused: Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        guard let bundleID = frontApp.bundleIdentifier else { return false }
        return Self.terminalBundleIDs.contains(bundleID)
    }
}
