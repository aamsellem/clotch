import Foundation

/// Emotion state derived from on-device NLTagger sentiment analysis.
/// Scores accumulate over time with exponential decay.
@Observable
final class EmotionState {
    /// Cumulative positive score (0..∞, decays over time)
    private(set) var positiveScore: Double = 0
    /// Cumulative negative score (0..∞, decays over time)
    private(set) var negativeScore: Double = 0
    /// Last time decay was applied
    private var lastDecayTime: Date = Date()

    /// Decay factor applied per 60 seconds
    static let decayRate: Double = 0.92
    /// Interval for decay calculation
    static let decayInterval: TimeInterval = 60

    /// Thresholds
    static let happyThreshold: Double = 0.6
    static let sadThreshold: Double = 0.45
    static let sobThreshold: Double = 0.9

    enum Emotion: String {
        case neutral
        case happy
        case sad
        case sob
    }

    /// The current dominant emotion
    var current: Emotion {
        applyDecayIfNeeded()
        if negativeScore >= Self.sobThreshold { return .sob }
        if negativeScore >= Self.sadThreshold { return .sad }
        if positiveScore >= Self.happyThreshold { return .happy }
        return .neutral
    }

    /// The sprite asset override for the current emotion (nil = use task-based sprite)
    var spriteOverride: String? {
        switch current {
        case .neutral: nil
        case .happy: "SpriteHappy"
        case .sad, .sob: "SpriteSad"
        }
    }

    /// Record a sentiment analysis result from NLTagger
    func record(sentiment: Double) {
        applyDecayIfNeeded()
        if sentiment > 0 {
            positiveScore += sentiment
        } else if sentiment < 0 {
            negativeScore += abs(sentiment)
        }
    }

    /// Reset emotion state (e.g., on session end)
    func reset() {
        positiveScore = 0
        negativeScore = 0
        lastDecayTime = Date()
    }

    private func applyDecayIfNeeded() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastDecayTime)
        guard elapsed >= Self.decayInterval else { return }

        let periods = elapsed / Self.decayInterval
        let factor = pow(Self.decayRate, periods)
        // Use internal mutation — @Observable tracks these
        let newPositive = positiveScore * factor
        let newNegative = negativeScore * factor
        // We need to use a workaround since these are private(set)
        // Actually, we can mutate them directly since we're inside the class
        positiveScore = newPositive
        negativeScore = newNegative
        lastDecayTime = now
    }
}
