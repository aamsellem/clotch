import SwiftUI

/// A single row in the activity feed showing a session event.
struct ActivityRowView: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status icon
            bulletIcon
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(taskPrefix + item.text)
                    .font(.system(size: 11, weight: isTask ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(textColor)
                    .lineLimit(3)
                    .strikethrough(item.kind == .taskCompleted, color: TerminalColors.green)

                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TerminalColors.textTertiary)
                        .lineLimit(2)
                }

                Text(timeAgo)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(TerminalColors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var bulletColor: Color {
        switch item.kind {
        case .prompt: TerminalColors.blue
        case .toolUse: TerminalColors.yellow
        case .toolResult: TerminalColors.green
        case .assistant: TerminalColors.purple
        case .error: TerminalColors.red
        case .info: TerminalColors.textSecondary
        case .taskCreated: TerminalColors.blue
        case .taskInProgress: TerminalColors.orange
        case .taskCompleted: TerminalColors.green
        }
    }

    private var textColor: Color {
        switch item.kind {
        case .error: TerminalColors.red
        default: TerminalColors.text
        }
    }

    private var isTask: Bool {
        [.taskCreated, .taskInProgress, .taskCompleted].contains(item.kind)
    }

    private var taskPrefix: String {
        switch item.kind {
        case .taskCreated: ""
        case .taskInProgress: ""
        case .taskCompleted: ""
        default: ""
        }
    }

    @ViewBuilder
    private var bulletIcon: some View {
        switch item.kind {
        case .taskCreated:
            Image(systemName: "square")
                .font(.system(size: 10))
                .foregroundStyle(TerminalColors.blue)
        case .taskInProgress:
            Image(systemName: "square.fill")
                .font(.system(size: 10))
                .foregroundStyle(TerminalColors.orange)
        case .taskCompleted:
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 10))
                .foregroundStyle(TerminalColors.green)
        default:
            Circle()
                .fill(bulletColor)
                .frame(width: 6, height: 6)
        }
    }

    private var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(item.timestamp))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}
