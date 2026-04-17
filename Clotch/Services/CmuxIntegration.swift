import AppKit

/// Integration with cmux terminal — opens or focuses the workspace for a session.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    /// Whether cmux CLI is available
    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// Focus the cmux workspace matching a project name or path.
    /// Uses `find-window --select` to find and select the matching workspace,
    /// then brings cmux to the foreground.
    static func focusSession(projectName: String?, cwd: String?) {
        guard isAvailable else { return }

        // Try project name first (matches workspace title), then last path component of cwd
        let query = projectName ?? (cwd as? NSString)?.lastPathComponent ?? ""
        guard !query.isEmpty else { return }

        // find-window --select finds and selects the first matching workspace
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmuxPath)
        process.arguments = ["find-window", "--select", query]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[Clotch] cmux find-window failed: \(error)")
        }

        // Bring cmux to front
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/cmux.app"))
    }
}
