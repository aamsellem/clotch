import SwiftUI

/// Horizontal session picker shown when multiple Claude Code sessions are active.
struct SessionListView: View {
    @Bindable var sessionStore: SessionStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sessionStore.orderedSessions) { session in
                    sessionPill(session)
                        .onTapGesture {
                            sessionStore.selectedSessionId = session.id
                        }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func sessionPill(_ session: SessionData) -> some View {
        let isSelected = sessionStore.selectedSessionId == session.id
        return HStack(spacing: 4) {
            Circle()
                .fill(isSelected ? TerminalColors.green : TerminalColors.textTertiary)
                .frame(width: 5, height: 5)

            Text(session.projectName ?? String(session.id.prefix(6)))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? TerminalColors.text : TerminalColors.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isSelected ? TerminalColors.surface : TerminalColors.background)
                .overlay(
                    Capsule()
                        .stroke(TerminalColors.border, lineWidth: 1)
                )
        )
    }
}
