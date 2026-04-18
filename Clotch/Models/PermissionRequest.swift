import Foundation

/// A Claude Code PermissionRequest hook payload, parsed from the socket.
struct PermissionRequestPayload: Decodable {
    let kind: String
    let requestId: String
    let sessionId: String
    let toolName: String?
    let toolInputRaw: String?
    let suggestions: [PermissionSuggestion]
    let cwd: String?
    let cmuxPanelId: String?
    let cmuxWorkspaceId: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case requestId = "request_id"
        case sessionId = "session_id"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case suggestions = "permission_suggestions"
        case cwd
        case cmuxPanelId = "cmux_panel_id"
        case cmuxWorkspaceId = "cmux_workspace_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        requestId = try c.decode(String.self, forKey: .requestId)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        if let any = try? c.decode(AnyCodable.self, forKey: .toolInput),
           let data = try? JSONSerialization.data(withJSONObject: any.value) {
            toolInputRaw = String(data: data, encoding: .utf8)
        } else {
            toolInputRaw = nil
        }
        suggestions = (try? c.decode([PermissionSuggestion].self, forKey: .suggestions)) ?? []
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        cmuxPanelId = try c.decodeIfPresent(String.self, forKey: .cmuxPanelId)
        cmuxWorkspaceId = try c.decodeIfPresent(String.self, forKey: .cmuxWorkspaceId)
    }
}

/// A permission suggestion pre-computed by Claude Code — e.g. "Allow Bash(git *)".
struct PermissionSuggestion: Codable, Hashable {
    let type: String              // "addRules"
    let destination: String?      // "session" | "localSettings" | "userSettings" | "projectSettings"
    let behavior: String          // "allow" | "deny" | "ask"
    let rules: [PermissionRule]
}

struct PermissionRule: Codable, Hashable {
    let toolName: String
    let ruleContent: String?
}

/// The user's decision that Clotch sends back to the hook script.
/// Maps to Claude Code's `hookSpecificOutput.decision` JSON.
struct PermissionDecision: Encodable {
    let behavior: String          // "allow" | "deny"
    let message: String?          // deny-only: shown back to Claude
    let updatedPermissions: [PermissionSuggestion]?

    static func allow(updatedPermissions: [PermissionSuggestion]? = nil) -> PermissionDecision {
        PermissionDecision(behavior: "allow", message: nil, updatedPermissions: updatedPermissions)
    }
    static func deny(message: String? = nil) -> PermissionDecision {
        PermissionDecision(behavior: "deny", message: message, updatedPermissions: nil)
    }
}

/// Helper to decode arbitrary JSON.
private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues { $0.value }; return }
        if let v = try? c.decode([AnyCodable].self) { value = v.map { $0.value }; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(Bool.self) { value = v; return }
        value = NSNull()
    }
}
