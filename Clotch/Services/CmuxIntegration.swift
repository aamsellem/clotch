import AppKit

/// Integration with cmux terminal — focuses the workspace for a session.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// Focus the cmux workspace matching a project name, then bring cmux to front.
    static func focusSession(projectName: String?, cwd: String?) {
        guard isAvailable else { return }
        let query = projectName ?? (cwd as? NSString)?.lastPathComponent ?? ""
        guard !query.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            // find-window --select finds and selects the matching workspace
            let p = Process()
            p.executableURL = URL(fileURLWithPath: cmuxPath)
            p.arguments = ["find-window", "--select", query]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()

            // Bring cmux to front on main thread
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/cmux.app"))
            }
        }
    }
}
