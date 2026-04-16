import Foundation

/// Manages all active Claude Code sessions.
@Observable
final class SessionStore {
    /// All currently tracked sessions, keyed by session_id
    private(set) var sessions: [String: SessionData] = [:]

    /// The currently selected session (for the expanded panel)
    var selectedSessionId: String?

    /// Ordered list of sessions, newest first
    var orderedSessions: [SessionData] {
        sessions.values.sorted { $0.startTime > $1.startTime }
    }

    /// The selected session, or the most recent one
    var activeSession: SessionData? {
        if let id = selectedSessionId, let s = sessions[id] { return s }
        return orderedSessions.first
    }

    /// Number of active (non-idle) sessions
    var activeCount: Int {
        sessions.values.filter { $0.task != .idle && $0.task != .sleeping }.count
    }

    /// Get or create a session
    func getOrCreate(id: String) -> SessionData {
        if let existing = sessions[id] { return existing }
        let session = SessionData(id: id)
        // Assign sprite X position to avoid overlaps
        session.spriteX = nextSpriteX()
        sessions[id] = session
        if selectedSessionId == nil {
            selectedSessionId = id
        }
        return session
    }

    /// Remove a session
    func remove(id: String) {
        sessions.removeValue(forKey: id)
        if selectedSessionId == id {
            selectedSessionId = orderedSessions.first?.id
        }
    }

    /// Remove sessions older than a threshold
    func pruneStale(olderThan interval: TimeInterval = 3600) {
        let cutoff = Date().addingTimeInterval(-interval)
        let stale = sessions.filter { $0.value.startTime < cutoff && $0.value.task == .sleeping }
        for (id, _) in stale {
            remove(id: id)
        }
    }

    /// Calculate next sprite X position to avoid overlaps
    private func nextSpriteX() -> Double {
        let count = sessions.count
        if count == 0 { return 0.5 }
        // Distribute evenly across 0.15..0.85 range
        let positions = stride(from: 0.15, through: 0.85, by: 0.7 / Double(max(count, 1)))
        let used = Set(sessions.values.map { $0.spriteX })
        for pos in positions {
            let rounded = (pos * 100).rounded() / 100
            if !used.contains(rounded) { return rounded }
        }
        return Double.random(in: 0.15...0.85)
    }
}
