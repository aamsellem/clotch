import Foundation

/// Integration with cmux terminal — focuses the workspace matching a session's project.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    /// Whether cmux CLI is available
    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// Focus the cmux workspace matching this project name.
    /// Uses `cmux find-window --select <name>` to switch to the right workspace.
    static func focusWorkspace(for projectName: String) {
        guard isAvailable, !projectName.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmuxPath)
        process.arguments = ["find-window", "--select", projectName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("[Clotch] cmux focus failed: \(error)")
        }
    }

    /// Bring cmux app to front
    static func activateApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "cmux"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
