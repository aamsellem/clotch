import SwiftUI

/// A row in the session list picker (when multiple sessions are active).
struct SessionRowView: View {
    let session: SessionData
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isSelected ? TerminalColors.green : TerminalColors.textTertiary)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(session.id.prefix(8)))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? TerminalColors.text : TerminalColors.textSecondary)

                Text(session.task.displayName)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(TerminalColors.textTertiary)
            }

            Spacer()

            Text(session.durationString)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(TerminalColors.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isSelected ? TerminalColors.surface : Color.clear
        )
        .cornerRadius(6)
    }
}
