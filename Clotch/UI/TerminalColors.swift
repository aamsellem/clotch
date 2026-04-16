import SwiftUI

/// Color palette inspired by terminal aesthetics
enum TerminalColors {
    static let background = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let surfaceHover = Color(red: 0.16, green: 0.16, blue: 0.2)
    static let border = Color.white.opacity(0.08)
    static let text = Color.white.opacity(0.9)
    static let textSecondary = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.3)

    static let green = Color(red: 0.3, green: 0.85, blue: 0.4)
    static let blue = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let red = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.3)
    static let purple = Color(red: 0.7, green: 0.5, blue: 1.0)
}
