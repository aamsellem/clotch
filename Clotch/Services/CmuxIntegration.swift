import AppKit

/// Integration with cmux terminal — focuses workspaces and injects keystrokes.
///
/// When Claude Code runs inside cmux, cmux injects `CMUX_PANEL_ID` and
/// `CMUX_WORKSPACE_ID` into the environment. Our hook script captures these
/// and sends them in the payload, so we have the exact target surface.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// Resolve the target panel + workspace for a session.
    /// Prefers the cmux UUIDs captured from env vars; falls back to parsing tree by projectName.
    static func resolveTarget(session: SessionData) -> (panel: String, workspace: String)? {
        if let pid = session.cmuxPanelId, let wid = session.cmuxWorkspaceId {
            return (panel: pid, workspace: wid)
        }
        if let name = session.projectName, let tree = findByTreeLookup(projectName: name) {
            return (panel: tree.surface, workspace: tree.workspace)
        }
        return nil
    }

    /// Send literal text to the session's cmux surface via JSON-RPC.
    static func sendText(session: SessionData, text: String) {
        NSLog("[Clotch] sendText text=%@ panel=%@ project=%@",
              text, session.cmuxPanelId ?? "nil", session.projectName ?? "nil")
        guard let surfaceId = resolveSurfaceId(session: session) else {
            NSLog("[Clotch] cmux: no surface for session %@", session.id)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            CmuxSocketClient.call(method: "surface.send_text",
                                  params: ["surface_id": surfaceId, "text": text])
        }
    }

    /// Send a symbolic key (enter, tab, ctrl+c…) via JSON-RPC.
    static func sendKey(session: SessionData, key: String) {
        guard let surfaceId = resolveSurfaceId(session: session) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            CmuxSocketClient.call(method: "surface.send_key",
                                  params: ["surface_id": surfaceId, "key": key])
        }
    }

    /// Resolve the surface UUID for a session — prefers cmuxPanelId from env vars.
    private static func resolveSurfaceId(session: SessionData) -> String? {
        if let pid = session.cmuxPanelId, !pid.isEmpty { return pid }
        // Fallback: tree lookup would require CLI access which we don't have from a GUI app,
        // so we can only send if the hook captured CMUX_PANEL_ID.
        return nil
    }

    /// Answer a permission prompt: types the char then presses Enter.
    static func answerPermission(session: SessionData, allow: Bool) {
        sendText(session: session, text: allow ? "y" : "n")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendKey(session: session, key: "enter")
        }
    }

    /// Answer a numbered question (1/2/3).
    static func answerQuestion(session: SessionData, option: Int) {
        sendText(session: session, text: String(option))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendKey(session: session, key: "enter")
        }
    }

    /// Focus the session's cmux workspace and bring the app forward.
    static func focusSession(session: SessionData) {
        guard isAvailable else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let wid = session.cmuxWorkspaceId {
                runCmuxSync(["select-workspace", "--workspace", wid])
            } else if let name = session.projectName, !name.isEmpty {
                runCmuxSync(["find-window", "--select", name])
            }
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/cmux.app"))
            }
        }
    }

    // MARK: - Legacy entry points (projectName-only)

    static func focusSession(projectName: String?, cwd: String?) {
        guard isAvailable else { return }
        let query = projectName ?? (cwd as? NSString)?.lastPathComponent ?? ""
        guard !query.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            runCmuxSync(["find-window", "--select", query])
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/cmux.app"))
            }
        }
    }

    static func sendKey(projectName: String?, key: String) {
        guard let name = projectName, let t = findByTreeLookup(projectName: name) else { return }
        runCmux(["send-key", "--workspace", t.workspace, "--surface", t.surface, key])
    }

    static func sendText(projectName: String?, text: String) {
        guard let name = projectName, let t = findByTreeLookup(projectName: name) else { return }
        runCmux(["send-panel", "--panel", t.surface, "--workspace", t.workspace, text])
    }

    // MARK: - Process helpers

    private static func runCmux(_ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            runCmuxSync(args)
        }
    }

    @discardableResult
    private static func runCmuxSync(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmuxPath)
        p.arguments = args
        // Inject CMUX_SOCKET_PATH if we can find it — the cmux CLI's auto-discovery
        // sometimes fails when launched from a GUI process.
        var env = ProcessInfo.processInfo.environment
        if env["CMUX_SOCKET_PATH"] == nil {
            for candidate in [
                "/tmp/cmux-last-socket-path",
                (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/cmux/last-socket-path")
            ] {
                if let path = try? String(contentsOfFile: candidate, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty,
                   FileManager.default.fileExists(atPath: path) {
                    env["CMUX_SOCKET_PATH"] = path
                    break
                }
            }
        }
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            NSLog("[Clotch] cmux %@ exit=%d out=%@",
                  args.joined(separator: " "),
                  Int(p.terminationStatus),
                  out.trimmingCharacters(in: .whitespacesAndNewlines))
            return out
        } catch {
            NSLog("[Clotch] cmux launch error: %@", error.localizedDescription)
            return ""
        }
    }

    // MARK: - Tree parsing (fallback when env vars are missing)

    private static func findByTreeLookup(projectName: String) -> (surface: String, workspace: String)? {
        let json = runCmuxSync(["tree", "--all", "--json"])
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let target = projectName.lowercased()
        let windows = root["windows"] as? [[String: Any]] ?? []
        for window in windows {
            let workspaces = window["workspaces"] as? [[String: Any]] ?? []
            for ws in workspaces {
                let title = (ws["title"] as? String ?? "").lowercased()
                guard title.contains(target), let wsRef = ws["ref"] as? String else { continue }
                let panes = ws["panes"] as? [[String: Any]] ?? []
                let focused = panes.first { ($0["focused"] as? Bool) == true } ?? panes.first
                guard let pane = focused else { continue }
                let surfaces = pane["surfaces"] as? [[String: Any]] ?? []
                let terminals = surfaces.filter { ($0["type"] as? String) == "terminal" }
                let picked = terminals.first(where: { ($0["selected"] as? Bool) == true })
                    ?? terminals.first
                    ?? surfaces.first
                if let s = picked, let sRef = s["ref"] as? String {
                    return (surface: sRef, workspace: wsRef)
                }
            }
        }
        return nil
    }
}
