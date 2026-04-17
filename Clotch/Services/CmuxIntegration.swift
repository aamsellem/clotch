import Foundation

/// Integration with cmux terminal — opens or focuses the workspace for a session's cwd.
enum CmuxIntegration {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    /// Whether cmux CLI is available
    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: cmuxPath)
    }

    /// Open or focus the cmux workspace for a given path.
    /// `cmux <path>` opens the directory in a new workspace or focuses it if already open.
    static func open(path: String) {
        guard isAvailable, !path.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmuxPath)
        process.arguments = [path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("[Clotch] cmux open failed: \(error)")
        }
    }
}
