import SwiftUI

/// Approval card shown when Claude is waiting for a permission response.
/// Renders Allow/Deny buttons and sends keystrokes to cmux via CmuxIntegration.
struct ApprovalCardView: View {
    let session: SessionData
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 14))
                Text("Permission required")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                if let name = session.projectName {
                    Text(name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Context (last tool use)
            if let tool = session.currentTool {
                Text(tool)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.05))
                    )
            }

            // Buttons
            HStack(spacing: 8) {
                Button(action: { answer(allow: false) }) {
                    HStack(spacing: 4) {
                        Text("Deny")
                        Text("⌘N")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.35, green: 0.1, blue: 0.1))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                .foregroundStyle(.white)

                Button(action: { answer(allow: true) }) {
                    HStack(spacing: 4) {
                        Text("Allow")
                        Text("⌘Y")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.15, green: 0.45, blue: 0.2))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("y", modifiers: .command)
                .foregroundStyle(.white)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answer(allow: Bool) {
        CmuxIntegration.answerPermission(projectName: session.projectName, allow: allow)
        // Optimistically mark session as working so peek goes away
        session.task = .working
        onDismiss()
    }
}
