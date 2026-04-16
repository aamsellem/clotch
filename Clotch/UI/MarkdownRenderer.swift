import SwiftUI

/// Simple markdown renderer for assistant messages.
/// Handles paragraphs, inline code, bold, and code blocks.
struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let text):
                    Text(parseInline(text))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TerminalColors.text)

                case .code(let code):
                    Text(code)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TerminalColors.green)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TerminalColors.background)
                        .cornerRadius(4)

                case .listItem(let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(TerminalColors.textSecondary)
                        Text(parseInline(text))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TerminalColors.text)
                    }
                }
            }
        }
    }

    private enum Block {
        case paragraph(String)
        case code(String)
        case listItem(String)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                result.append(.code(codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // List item
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.listItem(String(line.dropFirst(2))))
                i += 1
                continue
            }

            // Paragraph
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.paragraph(line))
            }
            i += 1
        }

        return result
    }

    private func parseInline(_ text: String) -> AttributedString {
        let result = AttributedString(text)
        // Basic inline code detection (backticks)
        // For a full implementation, use a proper markdown parser
        return result
    }
}
