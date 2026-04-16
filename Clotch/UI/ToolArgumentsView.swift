import SwiftUI

/// Displays tool arguments in a compact, syntax-highlighted format.
struct ToolArgumentsView: View {
    let json: String

    var body: some View {
        Text(formatted)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(TerminalColors.textSecondary)
            .lineLimit(3)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TerminalColors.background.opacity(0.5))
            .cornerRadius(4)
    }

    private var formatted: String {
        // Try to pretty-print JSON, fallback to truncated raw string
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
              let str = String(data: pretty, encoding: .utf8) else {
            return String(json.prefix(200))
        }
        return String(str.prefix(300))
    }
}
