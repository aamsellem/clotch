import SwiftUI

/// Displays the user's prompt as a chat bubble in the activity feed.
struct UserPromptBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TerminalColors.blue.opacity(0.3))
                )
                .lineLimit(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
