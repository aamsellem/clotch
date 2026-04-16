import Foundation

/// Installs the Clotch hook script into Claude Code's hooks directory
/// and registers it in ~/.claude/settings.json.
final class HookInstaller {
    private let claudeDir: String
    private let hooksDir: String
    private let settingsPath: String
    private let hookScriptName = "clotch-hook.sh"

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        claudeDir = "\(home)/.claude"
        hooksDir = "\(claudeDir)/hooks"
        settingsPath = "\(claudeDir)/settings.json"
    }

    /// Install or update hooks — always refreshes the script to latest version
    func installIfNeeded() {
        do {
            try installHookScript()
            try registerInSettings()
            print("[Clotch] Hooks installed/updated successfully")
        } catch {
            print("[Clotch] Hook installation failed: \(error)")
        }
    }

    /// Check if hooks are currently installed
    var isInstalled: Bool {
        let scriptPath = "\(hooksDir)/\(hookScriptName)"
        guard FileManager.default.fileExists(atPath: scriptPath) else { return false }

        // Check settings.json has our hooks
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        return hooks["UserPromptSubmit"] != nil
    }

    /// Uninstall hooks
    func uninstall() {
        let scriptPath = "\(hooksDir)/\(hookScriptName)"
        try? FileManager.default.removeItem(atPath: scriptPath)
        removeFromSettings()
        print("[Clotch] Hooks uninstalled")
    }

    private func installHookScript() throws {
        try FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        let scriptPath = "\(hooksDir)/\(hookScriptName)"

        // Try to copy from bundle first, fallback to embedded script
        if let bundledPath = Bundle.main.path(forResource: "clotch-hook", ofType: "sh") {
            try? FileManager.default.removeItem(atPath: scriptPath)
            try FileManager.default.copyItem(atPath: bundledPath, toPath: scriptPath)
        } else {
            try Self.hookScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        }

        // Make executable
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: scriptPath)
    }

    private func registerInSettings() throws {
        var settings: [String: Any] = [:]

        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let hookPath = "\(hooksDir)/\(hookScriptName)"

        // Claude Code expects the NESTED format: { "hooks": [{ "command": ..., "type": ... }] }
        let clotchNestedEntry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": hookPath,
                "timeout": 5000
            ]]
        ]

        let eventTypes = [
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "Stop",
            "SubagentStop",
            "Notification",
            "StopFailure",
            "PreCompact",
            "PostCompact",
            "TaskCreated",
            "TaskCompleted"
        ]

        for eventType in eventTypes {
            var eventEntries = hooks[eventType] as? [[String: Any]] ?? []
            // Remove existing Clotch hooks (both flat and nested format)
            eventEntries.removeAll { entry in
                // Flat format
                if let cmd = entry["command"] as? String, cmd.contains("clotch") { return true }
                // Nested format
                if let nestedHooks = entry["hooks"] as? [[String: Any]] {
                    return nestedHooks.contains { ($0["command"] as? String)?.contains("clotch") == true }
                }
                return false
            }
            eventEntries.append(clotchNestedEntry)
            hooks[eventType] = eventEntries
        }

        settings["hooks"] = hooks

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))
    }

    private func removeFromSettings() {
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else {
            return
        }

        for (eventType, value) in hooks {
            guard var eventHooks = value as? [[String: Any]] else { continue }
            eventHooks.removeAll { ($0["command"] as? String)?.contains("clotch") == true }
            hooks[eventType] = eventHooks.isEmpty ? nil : eventHooks
        }

        settings["hooks"] = hooks.isEmpty ? nil : hooks
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    /// The hook shell script that Claude Code will execute.
    /// Reads the event JSON from stdin and sends it to the Clotch Unix socket.
    /// Uses a single python3 call for reliability (no nc dependency).
    static let hookScript = """
    #!/bin/bash
    # Clotch hook for Claude Code
    SOCKET="/tmp/clotch.sock"
    [ ! -S "$SOCKET" ] && exit 0
    INPUT=$(cat)
    export CLOTCH_RAW_INPUT="$INPUT"
    export CLOTCH_SESSION="${CLAUDE_SESSION_ID:-unknown}"
    python3 -c "
    import json, os, socket, time
    raw = os.environ.get('CLOTCH_RAW_INPUT', '')
    session_id = os.environ.get('CLOTCH_SESSION', 'unknown')
    try:
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}
    event_type = data.get('hook_event_name') or data.get('event') or os.environ.get('CLAUDE_HOOK_EVENT_NAME') or 'unknown'
    payload = {
        'session_id': data.get('session_id', session_id),
        'event': event_type,
        'tool': data.get('tool_name', data.get('tool', None)),
        'tool_input': None,
        'user_prompt': data.get('user_prompt', data.get('prompt', None)),
        'cwd': data.get('cwd', None),
        'timestamp': int(time.time())
    }
    ti = data.get('tool_input')
    if ti:
        try:
            payload['tool_input'] = json.dumps(ti) if not isinstance(ti, str) else ti
        except Exception:
            pass
    msg = json.dumps(payload)
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect('/tmp/clotch.sock')
        s.sendall(msg.encode())
        s.shutdown(socket.SHUT_WR)
        s.close()
    except Exception:
        pass
    " &
    exit 0
    """
}
