import Foundation

/// Available notification sounds
enum NotificationSound: String, CaseIterable, Identifiable {
    case `default` = "default"
    case subtle = "subtle"
    case bell = "bell"
    case chime = "chime"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: "Default"
        case .subtle: "Subtle"
        case .bell: "Bell"
        case .chime: "Chime"
        case .none: "None"
        }
    }

    /// System sound name to play
    var systemSoundName: String? {
        switch self {
        case .default: "Tink"
        case .subtle: "Pop"
        case .bell: "Glass"
        case .chime: "Hero"
        case .none: nil
        }
    }
}
