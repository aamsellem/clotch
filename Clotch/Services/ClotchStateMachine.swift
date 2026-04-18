import Foundation

/// Central state machine that processes hook events and updates sessions.
/// Routes events to the appropriate services (sentiment, conversation, sound).
@Observable
final class ClotchStateMachine {
    let sessionStore: SessionStore
    private let sentimentAnalyzer: SentimentAnalyzer
    private let soundService: SoundService
    private let conversationParser: ConversationParser
    private let terminalFocusDetector: TerminalFocusDetector
    private let usageService: UsageService
    private let settings: AppSettings

    /// Current global spinner verb
    var spinnerVerb: String = "Idle"

    init(
        sessionStore: SessionStore,
        sentimentAnalyzer: SentimentAnalyzer,
        soundService: SoundService,
        conversationParser: ConversationParser,
        terminalFocusDetector: TerminalFocusDetector,
        usageService: UsageService,
        settings: AppSettings
    ) {
        self.sessionStore = sessionStore
        self.sentimentAnalyzer = sentimentAnalyzer
        self.soundService = soundService
        self.conversationParser = conversationParser
        self.terminalFocusDetector = terminalFocusDetector
        self.usageService = usageService
        self.settings = settings

        soundService.configure(settings: settings, terminalFocusDetector: terminalFocusDetector)
    }

    /// Handle an incoming hook event
    func handleEvent(_ event: HookEvent) {
        let session = sessionStore.getOrCreate(id: event.sessionId)

        // Extract project name and cwd
        if let cwd = event.cwd {
            if session.cwd == nil { session.cwd = cwd }
            if session.projectName == nil {
                session.projectName = (cwd as NSString).lastPathComponent
            }
        }

        switch event.event {
        case .userPromptSubmit:
            handlePromptSubmit(session: session, event: event)

        case .preToolUse:
            handlePreToolUse(session: session, event: event)

        case .postToolUse:
            handlePostToolUse(session: session, event: event)

        case .stop:
            handleStop(session: session, event: event)

        case .sessionEnd:
            handleSessionEnd(session: session, event: event)

        case .subagentStart:
            session.task = .working
            session.cancelSleepTimer()
            spinnerVerb = "Spawning subagent"

        case .subagentEnd:
            session.task = .working
            spinnerVerb = SpinnerVerbs.random(for: nil)

        case .notification:
            // Claude Code sends Notification when waiting for user (permission prompt)
            session.task = .waiting
            spinnerVerb = "Waiting for permission"
            soundService.playPeekSound()
            sendMacOSNotification(
                title: session.projectName ?? "Claude Code",
                body: "Waiting for your permission"
            )

        case .stopFailure:
            session.task = .idle
            session.currentTool = nil
            spinnerVerb = "Error"
            session.activities.append(ActivityItem(kind: .error, text: "API error"))
            sendMacOSNotification(
                title: session.projectName ?? "Claude Code",
                body: "Session stopped with error"
            )

        case .preCompact:
            session.task = .compacting
            spinnerVerb = "Compacting context"

        case .postCompact:
            session.task = .working
            spinnerVerb = SpinnerVerbs.random(for: nil)

        case .taskCreated:
            if let input = event.toolInput,
               let data = input.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let subject = json["subject"] as? String {
                session.activities.append(ActivityItem(kind: .taskCreated, text: subject))
            }

        case .taskCompleted:
            if let input = event.toolInput,
               let data = input.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let subject = json["subject"] as? String {
                session.activities.append(ActivityItem(kind: .taskCompleted, text: subject))
            }
        }
    }

    // MARK: - Event handlers

    private func handlePromptSubmit(session: SessionData, event: HookEvent) {
        session.task = .working
        session.cancelSleepTimer()
        session.lastPrompt = event.userPrompt
        spinnerVerb = SpinnerVerbs.random(for: nil)

        // Add to activity feed
        if let prompt = event.userPrompt {
            session.activities.append(ActivityItem(kind: .prompt, text: prompt))
        }

        // On-device sentiment analysis (zero tokens!)
        if settings.sentimentEnabled, let prompt = event.userPrompt {
            let classification = sentimentAnalyzer.classify(prompt)
            session.emotion.record(sentiment: classification.rawScore)
        }

        // Play sound
        soundService.playNotification(for: .userPromptSubmit)

        // Try to find and watch the transcript file
        discoverTranscript(for: session)
    }

    /// Tools that immediately require user interaction
    private static let waitingTools: Set<String> = [
        "AskUserQuestion",
    ]

    private func handlePreToolUse(session: SessionData, event: HookEvent) {
        // Detect tools that immediately wait for user input
        if let tool = event.tool, Self.waitingTools.contains(tool) {
            session.task = .waiting
            session.currentTool = tool
            spinnerVerb = "Waiting for you"
            soundService.playPeekSound()
        } else {
            session.task = .working
            session.currentTool = event.tool
            spinnerVerb = SpinnerVerbs.random(for: event.tool)
        }
        session.cancelSleepTimer()

        if let tool = event.tool {
            let activityItem = parseTaskActivity(tool: tool, input: event.toolInput) ??
                ActivityItem(kind: .toolUse, text: tool, detail: event.toolInput)
            session.activities.append(activityItem)
        }
    }

    private func handlePostToolUse(session: SessionData, event: HookEvent) {
        session.task = .working
        session.currentTool = nil
        spinnerVerb = SpinnerVerbs.random(for: nil)
    }

    private func handleStop(session: SessionData, event: HookEvent) {
        session.task = .idle
        session.currentTool = nil
        spinnerVerb = "Done"

        session.activities.append(ActivityItem(kind: .info, text: "Task completed"))

        // Show completion card for 5 seconds in the notch
        session.showCompletionUntil = Date().addingTimeInterval(5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) { [weak session] in
            if let session = session,
               let until = session.showCompletionUntil,
               until <= Date() {
                session.showCompletionUntil = nil
            }
        }

        // Play completion sound + macOS notification when terminal not focused
        soundService.playNotification(for: .stop)
        if !(terminalFocusDetector.isTerminalFocused) {
            sendMacOSNotification(
                title: session.projectName ?? "Claude Code",
                body: "Task completed"
            )
        }

        // Schedule sleep after inactivity
        session.scheduleSleep()
    }

    private func handleSessionEnd(session: SessionData, event: HookEvent) {
        session.task = .idle
        session.cancelSleepTimer()
        session.emotion.reset()
        spinnerVerb = "Idle"

        // Stop watching transcript
        if let path = session.transcriptPath {
            conversationParser.stopWatching(path: path)
        }

        // Prune after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.sessionStore.pruneStale()
        }
    }

    // MARK: - Transcript discovery

    private func discoverTranscript(for session: SessionData) {
        guard session.transcriptPath == nil else { return }

        // Claude Code stores transcripts in ~/.claude/projects/*/conversations/*.jsonl
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude"

        // Look for the most recent JSONL file matching this session
        let fm = FileManager.default
        let projectsDir = "\(claudeDir)/projects"

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else { return }

        var candidates: [(path: String, date: Date)] = []
        for project in projectDirs {
            let convDir = "\(projectsDir)/\(project)/conversations"
            guard let files = try? fm.contentsOfDirectory(atPath: convDir) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let path = "\(convDir)/\(file)"
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let modified = attrs[.modificationDate] as? Date {
                    candidates.append((path: path, date: modified))
                }
            }
        }

        // Pick the most recently modified file
        guard let newest = candidates.max(by: { $0.date < $1.date }) else { return }
        session.transcriptPath = newest.path

        // Start watching for changes
        conversationParser.watch(path: newest.path, session: session) { session, messages in
            for msg in messages where msg.role == "assistant" {
                session.activities.append(ActivityItem(
                    kind: .assistant,
                    text: String(msg.content.prefix(200))
                ))
            }
        }
    }

    // MARK: - Task parsing

    /// Parse TaskCreate / TaskUpdate tool inputs into rich activity items
    private func parseTaskActivity(tool: String, input: String?) -> ActivityItem? {
        guard let input = input,
              let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        switch tool {
        case "TaskCreate":
            let subject = json["subject"] as? String ?? "New task"
            return ActivityItem(kind: .taskCreated, text: subject)

        case "TaskUpdate":
            let status = json["status"] as? String
            let subject = json["subject"] as? String
            let taskId = json["taskId"] as? String ?? "?"

            switch status {
            case "in_progress":
                let label = subject ?? "Task #\(taskId)"
                return ActivityItem(kind: .taskInProgress, text: label)
            case "completed":
                let label = subject ?? "Task #\(taskId)"
                return ActivityItem(kind: .taskCompleted, text: label)
            default:
                return nil
            }

        default:
            return nil
        }
    }

    // MARK: - macOS Notifications

    private func sendMacOSNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = nil  // Sound handled separately by SoundService
        NSUserNotificationCenter.default.deliver(notification)
    }
}
