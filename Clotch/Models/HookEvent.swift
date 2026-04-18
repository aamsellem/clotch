import Foundation

/// Events received from Claude Code via the hook script and Unix socket.
struct HookEvent: Decodable {
    let sessionId: String
    let event: EventType
    let tool: String?
    let toolInput: String?
    let userPrompt: String?
    let cwd: String?
    let cmuxPanelId: String?
    let cmuxWorkspaceId: String?
    let timestamp: Date

    enum EventType: String, Decodable {
        case userPromptSubmit = "UserPromptSubmit"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
        case stop = "Stop"
        case sessionEnd = "SessionEnd"
        case subagentStart = "SubagentStart"
        case subagentEnd = "SubagentEnd"
        case notification = "Notification"
        case stopFailure = "StopFailure"
        case preCompact = "PreCompact"
        case postCompact = "PostCompact"
        case taskCreated = "TaskCreated"
        case taskCompleted = "TaskCompleted"
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case event
        case tool
        case toolInput = "tool_input"
        case userPrompt = "user_prompt"
        case cwd
        case cmuxPanelId = "cmux_panel_id"
        case cmuxWorkspaceId = "cmux_workspace_id"
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        event = try container.decode(EventType.self, forKey: .event)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        toolInput = try container.decodeIfPresent(String.self, forKey: .toolInput)
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        cmuxPanelId = try container.decodeIfPresent(String.self, forKey: .cmuxPanelId)
        cmuxWorkspaceId = try container.decodeIfPresent(String.self, forKey: .cmuxWorkspaceId)

        if let ts = try? container.decodeIfPresent(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decodeIfPresent(Int.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: Double(ts))
        } else {
            timestamp = Date()
        }
    }

    init(sessionId: String, event: EventType, tool: String? = nil, toolInput: String? = nil, userPrompt: String? = nil, cwd: String? = nil, cmuxPanelId: String? = nil, cmuxWorkspaceId: String? = nil) {
        self.sessionId = sessionId
        self.event = event
        self.tool = tool
        self.toolInput = toolInput
        self.userPrompt = userPrompt
        self.cwd = cwd
        self.cmuxPanelId = cmuxPanelId
        self.cmuxWorkspaceId = cmuxWorkspaceId
        self.timestamp = Date()
    }
}
