import Foundation

/// Reads Claude API usage from the local OAuth credentials stored by Claude Code.
/// No additional API tokens consumed — reads existing credentials from Keychain
/// and polls the usage endpoint that Claude Code itself uses.
@Observable
final class UsageService {
    let quota = UsageQuota()
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 60

    /// Start periodic usage polling
    func startPolling() {
        fetchUsage()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    /// Stop polling
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Attempt to read usage from Claude Code's stored OAuth token
    private func fetchUsage() {
        // Try to read the OAuth token from Claude Code's keychain entry
        guard let token = readOAuthToken() else {
            // Fallback: try reading from Claude Code's config
            readFromConfig()
            return
        }

        var request = URLRequest(url: URL(string: "https://api.claude.ai/api/oauth/usage")!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }

            DispatchQueue.main.async {
                self.parseUsageResponse(data)

                // Also check rate-limit headers from the response
                if let httpResponse = response as? HTTPURLResponse {
                    let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
                    self.quota.updateFromHeaders(headers)
                }
            }
        }.resume()
    }

    private func parseUsageResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Parse the usage response format
        if let periods = json["quota_periods"] as? [[String: Any]] {
            for period in periods {
                guard let name = period["name"] as? String,
                      let used = period["used"] as? Double,
                      let limit = period["limit"] as? Double,
                      limit > 0 else { continue }

                let usage = used / limit
                let resetStr = period["reset_at"] as? String
                let resetDate = resetStr.flatMap { ISO8601DateFormatter().date(from: $0) }

                if name.contains("5h") || name.contains("5_hour") {
                    quota.fiveHourUsage = usage
                    quota.fiveHourReset = resetDate
                } else if name.contains("7d") || name.contains("7_day") {
                    quota.sevenDayUsage = usage
                    quota.sevenDayReset = resetDate
                }
            }
            quota.isAvailable = true
            quota.lastUpdated = Date()
        }
    }

    /// Try to read OAuth token from Keychain (Claude Code stores it there)
    private func readOAuthToken() -> String? {
        // Use /usr/bin/security CLI to avoid Keychain ACL authorization dialogs
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let credStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !credStr.isEmpty else { return nil }

            // Parse the stored credentials JSON
            if let credData = credStr.data(using: .utf8),
               let creds = try? JSONSerialization.jsonObject(with: credData) as? [String: Any],
               let accessToken = creds["access_token"] as? String {
                return accessToken
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Fallback: read from Claude Code's config file
    private func readFromConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.claude/settings.json"

        guard let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String else {
            return
        }

        // If there's an API key in settings, we could use it for usage checking
        // But for now, we just note it's available
        _ = apiKey
    }
}
