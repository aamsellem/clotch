import AppKit

/// Integration with cmux terminal — focuses workspaces and sends keystrokes to panes.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// A resolved cmux location for a session
    struct SurfaceLocation {
        let workspace: String
        let surface: String
    }

    /// Synchronously find the cmux workspace + focused terminal surface for a project name.
    /// Returns nil if nothing matches.
    static func findSurface(projectName: String) -> SurfaceLocation? {
        guard isAvailable, !projectName.isEmpty else { return nil }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmuxPath)
        p.arguments = ["tree", "--all", "--json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let target = projectName.lowercased()
            let windows = json["windows"] as? [[String: Any]] ?? []
            for window in windows {
                let workspaces = window["workspaces"] as? [[String: Any]] ?? []
                for ws in workspaces {
                    let title = (ws["title"] as? String ?? "").lowercased()
                    guard title.contains(target) else { continue }
                    guard let wsRef = ws["ref"] as? String else { continue }

                    // Pick focused pane, then selected terminal surface within it
                    let panes = ws["panes"] as? [[String: Any]] ?? []
                    let focusedPane = panes.first { ($0["focused"] as? Bool) == true } ?? panes.first
                    guard let pane = focusedPane else { continue }

                    let surfaces = pane["surfaces"] as? [[String: Any]] ?? []
                    // Prefer selected terminal; fallback to first terminal; else any selected
                    let terminals = surfaces.filter { ($0["type"] as? String) == "terminal" }
                    let picked = terminals.first(where: { ($0["selected"] as? Bool) == true })
                        ?? terminals.first
                        ?? surfaces.first(where: { ($0["selected"] as? Bool) == true })
                        ?? surfaces.first
                    guard let surface = picked, let sRef = surface["ref"] as? String else { continue }

                    return SurfaceLocation(workspace: wsRef, surface: sRef)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Focus the cmux workspace for a project name and bring cmux to the foreground.
    static func focusSession(projectName: String?, cwd: String?) {
        guard isAvailable else { return }
        let query = projectName ?? (cwd as? NSString)?.lastPathComponent ?? ""
        guard !query.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: cmuxPath)
            p.arguments = ["find-window", "--select", query]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()

            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/cmux.app"))
            }
        }
    }

    /// Send literal text (ending in \n for Enter) to the surface matching projectName.
    /// Uses `cmux send-panel` which supports arbitrary characters.
    static func sendText(projectName: String?, text: String) {
        guard isAvailable, let name = projectName, !name.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let loc = findSurface(projectName: name) else {
                print("[Clotch] cmux: no surface found for \(name)")
                return
            }

            let p = Process()
            p.executableURL = URL(fileURLWithPath: cmuxPath)
            p.arguments = [
                "send-panel",
                "--panel", loc.surface,
                "--workspace", loc.workspace,
                text
            ]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            try? p.run()
            p.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if p.terminationStatus != 0 {
                print("[Clotch] cmux send-panel failed: \(output)")
            }
        }
    }

    /// Send a single symbolic key (enter, return, ctrl+c, tab...) — NOT literals.
    /// Use sendText for letters/digits.
    static func sendKey(projectName: String?, key: String) {
        guard isAvailable, let name = projectName, !name.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let loc = findSurface(projectName: name) else { return }

            let p = Process()
            p.executableURL = URL(fileURLWithPath: cmuxPath)
            p.arguments = [
                "send-key",
                "--workspace", loc.workspace,
                "--surface", loc.surface,
                key
            ]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    /// Answer a yes/no permission prompt by sending the key + Enter.
    static func answerPermission(projectName: String?, allow: Bool) {
        let char = allow ? "y" : "n"
        sendText(projectName: projectName, text: char)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sendKey(projectName: projectName, key: "enter")
        }
    }

    /// Answer a numbered question (1/2/3) by sending the digit + Enter.
    static func answerQuestion(projectName: String?, option: Int) {
        sendText(projectName: projectName, text: String(option))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sendKey(projectName: projectName, key: "enter")
        }
    }
}
