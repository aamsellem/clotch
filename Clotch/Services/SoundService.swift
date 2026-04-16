import AppKit

/// Plays notification sounds for session events.
/// Respects terminal focus — mutes when the terminal is focused.
final class SoundService {
    private var settings: AppSettings?
    private var terminalFocusDetector: TerminalFocusDetector?

    func configure(settings: AppSettings, terminalFocusDetector: TerminalFocusDetector) {
        self.settings = settings
        self.terminalFocusDetector = terminalFocusDetector
    }

    /// Play a notification sound for a session event
    func playNotification(for event: HookEvent.EventType) {
        guard settings?.soundEnabled ?? true else { return }

        // Don't play sounds when terminal is focused (user is already watching)
        if terminalFocusDetector?.isTerminalFocused ?? false { return }

        let soundName: String?
        switch event {
        case .stop:
            soundName = currentSound.systemSoundName
        case .userPromptSubmit:
            soundName = "Tink"
        default:
            soundName = nil
        }

        guard let name = soundName else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    /// Play a distinct sound when Claude needs user attention (peek)
    func playPeekSound() {
        guard settings?.soundEnabled ?? true else { return }
        if terminalFocusDetector?.isTerminalFocused ?? false { return }
        NSSound(named: NSSound.Name("Blow"))?.play()
    }

    private var currentSound: NotificationSound {
        guard let name = settings?.soundName,
              let sound = NotificationSound(rawValue: name) else {
            return .default
        }
        return sound
    }
}
