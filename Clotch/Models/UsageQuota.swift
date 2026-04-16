import Foundation

/// Tracks Claude API usage quotas read from response headers or OAuth API.
@Observable
final class UsageQuota {
    /// Usage percentage for the 5-hour window (0..1)
    var fiveHourUsage: Double = 0
    /// Usage percentage for the 7-day window (0..1)
    var sevenDayUsage: Double = 0
    /// Reset time for the 5-hour window
    var fiveHourReset: Date?
    /// Reset time for the 7-day window
    var sevenDayReset: Date?
    /// Whether we have valid data
    var isAvailable: Bool = false
    /// Last update time
    var lastUpdated: Date?

    /// The dominant (highest) usage percentage
    var dominantUsage: Double {
        max(fiveHourUsage, sevenDayUsage)
    }

    /// Human-readable usage string
    var displayString: String {
        guard isAvailable else { return "N/A" }
        return "\(Int(dominantUsage * 100))%"
    }

    /// Color tier for the usage bar
    var tier: UsageTier {
        let pct = dominantUsage
        if pct >= 0.9 { return .critical }
        if pct >= 0.7 { return .warning }
        return .normal
    }

    enum UsageTier {
        case normal, warning, critical
    }

    /// Update from rate-limit response headers
    func updateFromHeaders(_ headers: [String: String]) {
        if let fiveH = headers["anthropic-ratelimit-unified-5h-utilization"],
           let val = Double(fiveH) {
            fiveHourUsage = val
            isAvailable = true
        }
        if let sevenD = headers["anthropic-ratelimit-unified-7d-utilization"],
           let val = Double(sevenD) {
            sevenDayUsage = val
        }
        lastUpdated = Date()
    }

    /// Update from usage API response
    func update(fiveHour: Double, sevenDay: Double, fiveHourReset: Date? = nil, sevenDayReset: Date? = nil) {
        self.fiveHourUsage = fiveHour
        self.sevenDayUsage = sevenDay
        self.fiveHourReset = fiveHourReset
        self.sevenDayReset = sevenDayReset
        self.isAvailable = true
        self.lastUpdated = Date()
    }
}
