import Foundation

/// Parses Claude Code JSONL conversation transcripts incrementally.
/// Watches the transcript file for changes and extracts new assistant messages.
final class ConversationParser {
    private var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]
    private let queue = DispatchQueue(label: "com.clotch.parser", qos: .utility)

    /// Start watching a transcript file for a session
    func watch(path: String, session: SessionData, onChange: @escaping (SessionData, [ParsedMessage]) -> Void) {
        // Stop existing watcher if any
        stopWatching(path: path)

        guard FileManager.default.fileExists(atPath: path) else { return }

        let fd = open(path, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let messages = self.parseIncremental(path: path, session: session)
            if !messages.isEmpty {
                DispatchQueue.main.async {
                    onChange(session, messages)
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        fileWatchers[path] = source
        source.resume()

        // Initial parse
        queue.async { [weak self] in
            guard let self = self else { return }
            let messages = self.parseIncremental(path: path, session: session)
            if !messages.isEmpty {
                DispatchQueue.main.async {
                    onChange(session, messages)
                }
            }
        }
    }

    /// Stop watching a specific file
    func stopWatching(path: String) {
        fileWatchers[path]?.cancel()
        fileWatchers.removeValue(forKey: path)
    }

    /// Stop all file watchers
    func stopAll() {
        for (_, source) in fileWatchers {
            source.cancel()
        }
        fileWatchers.removeAll()
    }

    /// Parse new lines from the transcript file since last read
    private func parseIncremental(path: String, session: SessionData) -> [ParsedMessage] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { handle.closeFile() }

        // Seek to last known offset
        handle.seek(toFileOffset: session.transcriptOffset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return [] }

        // Update offset
        session.transcriptOffset = handle.offsetInFile

        // Parse JSONL lines
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var messages: [ParsedMessage] = []

        for line in text.components(separatedBy: .newlines) where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let role = json["role"] as? String {
                let content = json["content"] as? String
                    ?? (json["content"] as? [[String: Any]])?.compactMap({ $0["text"] as? String }).joined(separator: "\n")
                    ?? ""

                messages.append(ParsedMessage(role: role, content: content))
            }
        }

        return messages
    }
}

struct ParsedMessage {
    let role: String   // "user", "assistant", "tool_use", "tool_result"
    let content: String
}
