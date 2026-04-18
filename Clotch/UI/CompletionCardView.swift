import SwiftUI

/// Temporary card shown briefly when a Claude Code task completes.
struct CompletionCardView: View {
    let session: SessionData
    var onOpenTerminal: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
                Text("Task completed")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Text(session.durationString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if let name = session.projectName {
                Text(name)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if CmuxIntegration.isAvailable {
                Button(action: onOpenTerminal) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 10))
                        Text("Open in cmux")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
