import Foundation

/// Unix domain socket server that receives hook events and permission requests.
/// - Regular hooks (HookEvent): one-shot, handler called, connection closed.
/// - Permission requests: connection kept open in `pendingPermissions` until the
///   UI resolves it, then the decision is written back and the socket closes.
final class SocketServer {
    let socketPath: String
    private var listenSocket: Int32 = -1
    private var isRunning = false
    private let listenQueue = DispatchQueue(label: "com.clotch.socket.listen", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "com.clotch.socket.client", qos: .userInitiated, attributes: .concurrent)
    private let lock = NSLock()
    private var pendingPermissions: [String: Int32] = [:]  // request_id → client fd

    let handler: (HookEvent) -> Void
    let permissionHandler: (PermissionRequestPayload) -> Void

    init(
        socketPath: String = "/tmp/clotch.sock",
        handler: @escaping (HookEvent) -> Void,
        permissionHandler: @escaping (PermissionRequestPayload) -> Void
    ) {
        self.socketPath = socketPath
        self.handler = handler
        self.permissionHandler = permissionHandler
    }

    // MARK: - Public

    func start() {
        listenQueue.async { [weak self] in self?.listen() }
    }

    func stop() {
        isRunning = false
        if listenSocket >= 0 { close(listenSocket); listenSocket = -1 }
        unlink(socketPath)
    }

    /// Resolve a pending permission by writing the decision back to the hook script.
    func resolvePermission(requestId: String, decision: PermissionDecision) {
        lock.lock()
        let fd = pendingPermissions.removeValue(forKey: requestId)
        lock.unlock()
        guard let fd else {
            print("[Clotch] resolvePermission: no pending request \(requestId)")
            return
        }
        do {
            var responseJSON = [String: Any]()
            responseJSON["decision"] = decisionDict(decision)
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            var line = String(data: data, encoding: .utf8) ?? "{}"
            line += "\n"
            line.withCString { ptr in
                _ = Darwin.send(fd, ptr, strlen(ptr), 0)
            }
        } catch {
            print("[Clotch] resolvePermission encode error: \(error)")
        }
        close(fd)
    }

    private func decisionDict(_ d: PermissionDecision) -> [String: Any] {
        var out: [String: Any] = ["behavior": d.behavior]
        if let m = d.message { out["message"] = m }
        if let perms = d.updatedPermissions {
            out["updatedPermissions"] = perms.map { sugg -> [String: Any] in
                var s: [String: Any] = [
                    "type": sugg.type,
                    "behavior": sugg.behavior,
                    "rules": sugg.rules.map { r -> [String: Any] in
                        var r2: [String: Any] = ["toolName": r.toolName]
                        if let c = r.ruleContent { r2["ruleContent"] = c }
                        return r2
                    }
                ]
                if let dest = sugg.destination { s["destination"] = dest }
                return s
            }
        }
        return out
    }

    // MARK: - Private

    private func listen() {
        unlink(socketPath)
        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket >= 0 else {
            print("[Clotch] socket() failed: \(errno)"); return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
                UnsafeMutableRawPointer(sunPath)
                    .copyMemory(from: ptr, byteCount: min(socketPath.utf8.count + 1, 104))
            }
        }
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(listenSocket, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            print("[Clotch] bind() failed: \(errno)"); close(listenSocket); return
        }
        chmod(socketPath, 0o600)
        guard Darwin.listen(listenSocket, 5) == 0 else {
            print("[Clotch] listen() failed: \(errno)"); close(listenSocket); return
        }
        isRunning = true
        print("[Clotch] Socket server listening on \(socketPath)")

        while isRunning {
            let clientSocket = accept(listenSocket, nil, nil)
            guard clientSocket >= 0 else {
                if isRunning { print("[Clotch] accept() failed: \(errno)") }
                continue
            }
            clientQueue.async { [weak self] in self?.handleClient(clientSocket) }
        }
    }

    /// Reads up to `max` bytes or until the client shuts down write (EOF).
    /// The permission hook uses shutdown-after-send-request semantics? No — actually
    /// the hook keeps the connection open to wait for the response, so we read
    /// until we get a newline (for permission) or EOF (for regular events).
    private func handleClient(_ clientSocket: Int32) {
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        // Use a socket receive timeout to avoid hanging
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Read until we have at least one complete JSON message
        while true {
            // If we already have a newline or a valid JSON, break and process
            if data.contains(0x0A /* \n */) { break }
            let bytesRead = read(clientSocket, buffer, bufferSize)
            if bytesRead <= 0 {
                break  // EOF or timeout
            }
            data.append(buffer, count: bytesRead)
            // If we've read a chunk and no newline expected (plain HookEvent from shell script),
            // stop after some data — the hook ends by shutdown which yields EOF next read.
            if data.count > 0 && data.count < 65536 {
                // Peek: if the next read yields 0 we'll break naturally
                continue
            }
        }

        guard !data.isEmpty else { close(clientSocket); return }

        // Strip trailing newline if any
        while let last = data.last, last == 0x0A || last == 0x0D { data.removeLast() }

        // Dispatch: is this a PermissionRequest envelope (has "kind":"permission_request")?
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let kind = obj["kind"] as? String, kind == "permission_request" {
            handlePermissionRequest(fd: clientSocket, data: data)
            return
        }

        // Otherwise: plain HookEvent
        do {
            let event = try JSONDecoder().decode(HookEvent.self, from: data)
            DispatchQueue.main.async { [weak self] in self?.handler(event) }
        } catch {
            print("[Clotch] Failed to decode event: \(error)")
        }
        close(clientSocket)
    }

    private func handlePermissionRequest(fd: Int32, data: Data) {
        do {
            let payload = try JSONDecoder().decode(PermissionRequestPayload.self, from: data)
            // Remember the client fd so we can write the decision back
            lock.lock()
            pendingPermissions[payload.requestId] = fd
            lock.unlock()
            DispatchQueue.main.async { [weak self] in
                self?.permissionHandler(payload)
            }
            // Set up a safety auto-close after 60s if UI doesn't resolve
            DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let stillPending = self.pendingPermissions.removeValue(forKey: payload.requestId)
                self.lock.unlock()
                if let fd = stillPending {
                    print("[Clotch] Permission request \(payload.requestId) timed out")
                    close(fd)
                }
            }
        } catch {
            print("[Clotch] PermissionRequest decode error: \(error)")
            close(fd)
        }
    }
}
