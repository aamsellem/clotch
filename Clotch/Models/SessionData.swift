import Foundation

/// Represents a single Claude Code session being tracked.
@Observable
final class SessionData: Identifiable {
    let id: String  // session_id from Claude Code
    let startTime: Date

    /// Current task state
    var task: ClotchTask = .idle
    /// Emotion state (on-device sentiment)
    let emotion = EmotionState()
    /// Working directory name (last path component of cwd)
    var projectName: String?
    /// Full working directory path
    var cwd: String?
    /// cmux panel UUID (from CMUX_PANEL_ID env var in the hook)
    var cmuxPanelId: String?
    /// cmux workspace UUID (from CMUX_WORKSPACE_ID env var)
    var cmuxWorkspaceId: String?
    /// The last user prompt text
    var lastPrompt: String?
    /// Current working tool name
    var currentTool: String?
    /// Short preview of the current tool's args (e.g. "rm file.txt", "/path/to/file.swift")
    var currentToolPreview: String?
    /// Full cwd-relative path affected by the current tool, when applicable
    var currentToolPath: String?
    /// Recent activity events for the feed
    var activities: [ActivityItem] = []
    /// Sprite X position on the grass island (0..1 normalized)
    var spriteX: Double = 0.5
    /// Timer for transitioning to sleep after inactivity
    var sleepTimer: Timer?
    /// Date until which the completion card should be shown (nil = not shown)
    var showCompletionUntil: Date?
    /// Path to the conversation JSONL transcript file
    var transcriptPath: String?
    /// Last known file offset for incremental transcript parsing
    var transcriptOffset: UInt64 = 0

    /// Time since session started
    var duration: TimeInterval { Date().timeIntervalSince(startTime) }

    /// Formatted duration string
    var durationString: String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    init(id: String) {
        self.id = id
        self.startTime = Date()
    }

    /// Cancel the sleep timer
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
    }

    /// Start a sleep timer — transition to sleeping after 5 minutes of inactivity
    func scheduleSleep(after interval: TimeInterval = 300) {
        cancelSleepTimer()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.task = .sleeping
        }
    }
}

/// A single activity item in the session feed.
struct ActivityItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let text: String
    let detail: String?

    enum Kind {
        case prompt
        case toolUse
        case toolResult
        case assistant
        case error
        case info
        case taskCreated
        case taskInProgress
        case taskCompleted
    }

    init(kind: Kind, text: String, detail: String? = nil) {
        self.timestamp = Date()
        self.kind = kind
        self.text = text
        self.detail = detail
    }
}
