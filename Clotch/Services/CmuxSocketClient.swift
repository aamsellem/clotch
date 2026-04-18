import Darwin
import Foundation

/// Minimal Unix-socket JSON-RPC client for cmux.
///
/// The cmux CLI (/Applications/cmux.app/Contents/Resources/bin/cmux) rejects
/// non-cmux-spawned processes with "Access denied — only processes started
/// inside cmux can connect". But the underlying Unix socket itself accepts
/// JSON-RPC requests from anyone — which is how open-vibe-island drives cmux.
///
/// We use it to call `surface.send_text` and `surface.send_key` directly.
enum CmuxSocketClient {
    /// Resolve the path to the active cmux socket.
    static func resolveSocketPath() -> String? {
        let candidates = [
            "/tmp/cmux-last-socket-path",
            (NSHomeDirectory() as NSString)
                .appendingPathComponent("Library/Application Support/cmux/last-socket-path")
        ]
        for pointer in candidates {
            if let raw = try? String(contentsOfFile: pointer, encoding: .utf8) {
                let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        }
        // Hard fallbacks
        let fallbacks = [
            (NSHomeDirectory() as NSString)
                .appendingPathComponent("Library/Application Support/cmux/cmux.sock"),
            "/tmp/cmux.sock"
        ]
        for p in fallbacks where FileManager.default.fileExists(atPath: p) {
            return p
        }
        return nil
    }

    /// Send a JSON-RPC request and return the decoded response dict (or nil on error).
    @discardableResult
    static func call(method: String, params: [String: Any]) -> [String: Any]? {
        guard let socketPath = resolveSocketPath() else {
            NSLog("[Clotch] cmux socket not found")
            return nil
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[Clotch] cmux socket() failed")
            return nil
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            let buffer = raw.bindMemory(to: Int8.self)
            for (i, byte) in pathBytes.enumerated() where i < buffer.count {
                buffer[i] = byte
            }
        }
        let connectResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            NSLog("[Clotch] cmux connect() failed errno=%d", errno)
            return nil
        }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": Int.random(in: 1...999_999)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return nil }
        line += "\n"

        let sent = line.withCString { ptr in
            Darwin.send(fd, ptr, strlen(ptr), 0)
        }
        guard sent > 0 else {
            NSLog("[Clotch] cmux send() failed errno=%d", errno)
            return nil
        }

        // Read response (single line, up to 8 KB)
        var buf = [UInt8](repeating: 0, count: 8192)
        let n = Darwin.recv(fd, &buf, buf.count, 0)
        guard n > 0 else {
            NSLog("[Clotch] cmux recv() returned %d errno=%d", n, errno)
            return nil
        }
        let respData = Data(buf[0..<Int(n)])
        let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any]
        if obj?["ok"] as? Bool != true {
            NSLog("[Clotch] cmux %@ error: %@", method, String(data: respData, encoding: .utf8) ?? "?")
        }
        return obj
    }
}
