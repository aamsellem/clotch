import Foundation

/// Unix domain socket server that receives hook events from Claude Code.
/// Listens on /tmp/clotch.sock for JSON payloads.
final class SocketServer {
    let socketPath: String
    private var listenSocket: Int32 = -1
    private var isRunning = false
    private let listenQueue = DispatchQueue(label: "com.clotch.socket.listen", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "com.clotch.socket.client", qos: .userInitiated, attributes: .concurrent)
    private let handler: (HookEvent) -> Void

    init(socketPath: String = "/tmp/clotch.sock", handler: @escaping (HookEvent) -> Void) {
        self.socketPath = socketPath
        self.handler = handler
    }

    func start() {
        listenQueue.async { [weak self] in
            self?.listen()
        }
    }

    func stop() {
        isRunning = false
        if listenSocket >= 0 {
            close(listenSocket)
            listenSocket = -1
        }
        unlink(socketPath)
    }

    private func listen() {
        // Clean up stale socket
        unlink(socketPath)

        // Create socket
        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket >= 0 else {
            print("[Clotch] Failed to create socket: \(errno)")
            return
        }

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
                let rawPtr = UnsafeMutableRawPointer(sunPath)
                rawPtr.copyMemory(from: ptr, byteCount: min(socketPath.utf8.count + 1, 104))
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(listenSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            print("[Clotch] Failed to bind socket: \(errno)")
            close(listenSocket)
            return
        }

        // Set permissions — only current user can write
        chmod(socketPath, 0o600)

        // Listen
        guard Darwin.listen(listenSocket, 5) == 0 else {
            print("[Clotch] Failed to listen: \(errno)")
            close(listenSocket)
            return
        }

        isRunning = true
        print("[Clotch] Socket server listening on \(socketPath)")

        while isRunning {
            let clientSocket = accept(listenSocket, nil, nil)
            guard clientSocket >= 0 else {
                if isRunning { print("[Clotch] Accept failed: \(errno)") }
                continue
            }

            clientQueue.async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = read(clientSocket, buffer, bufferSize)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }

        guard !data.isEmpty else { return }

        do {
            let event = try JSONDecoder().decode(HookEvent.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.handler(event)
            }
        } catch {
            print("[Clotch] Failed to decode event: \(error)")
            if let str = String(data: data, encoding: .utf8) {
                print("[Clotch] Raw data: \(str.prefix(500))")
            }
        }
    }
}
