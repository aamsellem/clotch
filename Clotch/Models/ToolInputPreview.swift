import Foundation

/// Extracts a short human-readable preview of a tool's arguments from its JSON input.
///
/// Approach inspired by open-vibe-island: priority order of keys, with special
/// handling per tool (Bash command, Edit/Read file_path, Grep pattern…). The goal
/// is to display something like "$ rm -rf /tmp/cache" or "/path/to/file.swift"
/// in the approval card so the user knows WHAT Claude is asking to do.
enum ToolInputPreview {
    /// Priority order when extracting a preview from unknown tools.
    private static let priorityKeys = [
        "command", "file_path", "path", "pattern", "query", "prompt",
        "description", "skill", "url", "target_file", "notebook_path"
    ]

    /// Keys that represent an affected filesystem path (for the secondary label).
    private static let pathKeys = [
        "file_path", "path", "target_file", "notebook_path", "working_directory"
    ]

    /// Extracts `(preview, path)` from the raw tool_input JSON string.
    /// Returns nil values if the tool or JSON is missing.
    static func extract(tool: String?, rawJSON: String?) -> (preview: String?, path: String?) {
        guard let rawJSON, let data = rawJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (nil, nil) }

        let preview = buildPreview(tool: tool, input: root)
        let path = pathKeys.lazy.compactMap { root[$0] as? String }.first
            .flatMap { $0.isEmpty ? nil : $0 }

        return (preview, path)
    }

    private static func buildPreview(tool: String?, input: [String: Any]) -> String? {
        switch tool {
        case "Bash":
            if let cmd = input["command"] as? String, !cmd.isEmpty {
                return clip("$ \(cmd)", max: 120)
            }
        case "Edit", "Write", "MultiEdit":
            if let path = input["file_path"] as? String { return clip(path, max: 120) }
        case "Read":
            if let path = input["file_path"] as? String { return clip(path, max: 120) }
        case "Grep":
            if let pattern = input["pattern"] as? String { return clip("grep \(pattern)", max: 120) }
        case "Glob":
            if let pattern = input["pattern"] as? String { return clip(pattern, max: 120) }
        default:
            break
        }
        // Fallback: first matching priority key
        for key in priorityKeys {
            if let str = input[key] as? String, !str.isEmpty {
                return clip(str, max: 120)
            }
        }
        return nil
    }

    private static func clip(_ s: String, max: Int) -> String {
        let cleaned = s.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count <= max { return cleaned }
        return String(cleaned.prefix(max - 1)) + "…"
    }
}
