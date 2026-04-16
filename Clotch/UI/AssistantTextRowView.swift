import SwiftUI

/// Expandable assistant text message in the activity feed.
struct AssistantTextRowView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(TerminalColors.purple)

                Text("Assistant")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(TerminalColors.purple)

                Spacer()

                if text.count > 100 {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(TerminalColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(isExpanded ? text : String(text.prefix(100)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(TerminalColors.text.opacity(0.8))
                .lineLimit(isExpanded ? nil : 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TerminalColors.surface)
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}
