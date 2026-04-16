import Foundation

/// The possible states of a Claude Code session as observed by Clotch.
enum ClotchTask: String, CaseIterable {
    case idle
    case working
    case sleeping
    case compacting
    case waiting

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .working: "Working"
        case .sleeping: "Sleeping"
        case .compacting: "Compacting"
        case .waiting: "Waiting for input"
        }
    }

    /// The sprite sheet asset name for this task + emotion combo.
    /// Notchi sprites: {task}_{emotion} with 6 frames of 64x64.
    func spriteAsset(for emotion: EmotionState.Emotion) -> String {
        let taskPrefix: String
        switch self {
        case .idle: taskPrefix = "idle"
        case .working: taskPrefix = "working"
        case .sleeping: taskPrefix = "sleeping"
        case .compacting: taskPrefix = "compacting"
        case .waiting: taskPrefix = "waiting"
        }

        let emotionSuffix: String
        switch emotion {
        case .happy: emotionSuffix = "happy"
        case .sad: emotionSuffix = "sad"
        case .sob: emotionSuffix = "sob"
        case .neutral: emotionSuffix = "neutral"
        }

        // Check if this combo exists, fallback to neutral
        let name = "\(taskPrefix)_\(emotionSuffix)"
        let fallback = "\(taskPrefix)_neutral"

        // These combos exist in notchi assets:
        let validCombos: Set<String> = [
            "idle_neutral", "idle_happy", "idle_sad", "idle_sob",
            "working_neutral", "working_happy", "working_sad", "working_sob",
            "sleeping_neutral", "sleeping_happy",
            "waiting_neutral", "waiting_happy", "waiting_sad", "waiting_sob",
            "compacting_neutral", "compacting_happy",
        ]

        return validCombos.contains(name) ? name : fallback
    }

    /// Frames per second for the sprite animation
    var spriteFPS: Double {
        switch self {
        case .idle: 3
        case .working: 6
        case .sleeping: 2
        case .compacting: 8
        case .waiting: 3
        }
    }

    /// Number of frames in the sprite sheet
    static let spriteFrameCount = 6
}

/// Spinner verb phrases shown during working state
enum SpinnerVerbs {
    static let thinking = [
        "Thinking", "Pondering", "Considering", "Analyzing", "Reasoning",
        "Processing", "Evaluating", "Contemplating", "Reflecting", "Computing"
    ]

    static let toolUse = [
        "Reading", "Searching", "Writing", "Editing", "Running",
        "Building", "Testing", "Deploying", "Fetching", "Scanning"
    ]

    static func random(for tool: String?) -> String {
        if let tool = tool {
            let base = toolUse.randomElement() ?? "Working"
            return "\(base) (\(tool))"
        }
        return thinking.randomElement() ?? "Thinking"
    }
}
