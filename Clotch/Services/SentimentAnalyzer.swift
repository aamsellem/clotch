import Foundation
import NaturalLanguage

/// On-device sentiment analysis using Apple's NLTagger.
/// Zero network calls, zero tokens consumed. Runs entirely on the device.
final class SentimentAnalyzer {
    private let tagger = NLTagger(tagSchemes: [.sentimentScore])

    /// Analyze the sentiment of a text string.
    /// Returns a score from -1.0 (very negative) to +1.0 (very positive).
    /// 0.0 means neutral.
    func analyze(_ text: String) -> Double {
        tagger.string = text

        let (tag, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )

        guard let tag = tag, let score = Double(tag.rawValue) else {
            return 0.0
        }

        return score
    }

    /// Analyze and return an emotion classification
    func classify(_ text: String) -> EmotionClassification {
        let score = analyze(text)
        let emotion: EmotionClassification.Emotion
        let intensity = abs(score)

        switch score {
        case 0.3...: emotion = .happy
        case 0.1..<0.3: emotion = .neutral
        case -0.3..<(-0.1): emotion = .neutral
        case ..<(-0.3): emotion = .sad
        default: emotion = .neutral
        }

        return EmotionClassification(emotion: emotion, intensity: intensity, rawScore: score)
    }
}

struct EmotionClassification {
    enum Emotion: String {
        case happy, sad, neutral
    }

    let emotion: Emotion
    let intensity: Double  // 0..1
    let rawScore: Double   // -1..1
}
