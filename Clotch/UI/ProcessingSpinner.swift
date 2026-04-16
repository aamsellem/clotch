import SwiftUI

/// Animated spinner shown during working state.
/// Displays rotating symbols with a verb describing the current action.
struct ProcessingSpinner: View {
    let verb: String
    @State private var symbolIndex = 0

    private let symbols = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    var body: some View {
        HStack(spacing: 6) {
            Text(symbols[symbolIndex])
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(TerminalColors.green)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                        symbolIndex = (symbolIndex + 1) % symbols.count
                    }
                }

            Text(verb)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(TerminalColors.text)
                .lineLimit(1)
        }
    }
}
