import SwiftUI

/// A choice option for the card (permission allow/deny, question options, etc.)
struct CardChoice: Identifiable {
    let id = UUID()
    let label: String
    let shortcut: String  // e.g. "⌘1", "⌘Y"
    let key: String       // key sent to cmux: "1", "2", "y", "n"
    let kind: Kind

    enum Kind {
        case allow
        case deny
        case neutral
    }

    static func allow(key: String = "1") -> CardChoice {
        CardChoice(label: "Allow", shortcut: "⌘Y", key: key, kind: .allow)
    }
    static func deny(key: String = "2") -> CardChoice {
        CardChoice(label: "Deny", shortcut: "⌘N", key: key, kind: .deny)
    }
    static func numbered(_ n: Int, label: String) -> CardChoice {
        CardChoice(label: label, shortcut: "⌘\(n)", key: String(n), kind: .neutral)
    }
}

/// Generic choice card shown when Claude is waiting for user input.
/// Sends the matching key to cmux via CmuxIntegration when an option is picked.
struct ApprovalCardView: View {
    let session: SessionData
    var title: String = "Permission required"
    var icon: String = "questionmark.circle.fill"
    var iconColor: Color = .yellow
    var choices: [CardChoice] = [.deny(), .allow()]
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                if let name = session.projectName {
                    Text(name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Context (last tool use or prompt)
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

            // Choices — laid out horizontally for 2 options, vertically for 3+
            if choices.count <= 2 {
                HStack(spacing: 8) {
                    ForEach(choices) { choice in
                        ChoiceButton(choice: choice, action: { pick(choice) })
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(choices) { choice in
                        ChoiceButton(choice: choice, action: { pick(choice) })
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KeyboardShortcuts(choices: choices, onPick: pick)
        )
    }

    private func pick(_ choice: CardChoice) {
        let pid = session.cmuxPanelId ?? "?"
        NSLog("[Clotch] ApprovalCard.pick key=\(choice.key) panel=\(pid)")
        CmuxIntegration.sendText(session: session, text: choice.key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CmuxIntegration.sendKey(session: session, key: "enter")
        }
        session.task = .working
        onDismiss()
    }
}

/// Individual choice button with hover and tap handling (works in non-activating panels)
private struct ChoiceButton: View {
    let choice: CardChoice
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(choice.label)
            Spacer(minLength: 0)
            Text(choice.shortcut)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            NSLog("[Clotch] ChoiceButton tap: \(choice.label)")
            action()
        }
    }

    private var bgColor: Color {
        let base: Color
        switch choice.kind {
        case .allow: base = Color(red: 0.15, green: 0.45, blue: 0.2)
        case .deny:  base = Color(red: 0.35, green: 0.1, blue: 0.1)
        case .neutral: base = Color(red: 0.18, green: 0.2, blue: 0.26)
        }
        return hovering ? base.opacity(1.25) : base
    }
}

/// Invisible view that handles ⌘<digit> / ⌘Y / ⌘N shortcuts via NSEvent local monitor.
private struct KeyboardShortcuts: NSViewRepresentable {
    let choices: [CardChoice]
    let onPick: (CardChoice) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ShortcutView()
        view.choices = choices
        view.onPick = onPick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? ShortcutView else { return }
        v.choices = choices
        v.onPick = onPick
    }

    final class ShortcutView: NSView {
        var choices: [CardChoice] = []
        var onPick: ((CardChoice) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self, event.modifierFlags.contains(.command) else { return event }
                    let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
                    // Map ⌘Y → allow, ⌘N → deny, ⌘<digit> → numbered
                    if let choice = self.match(key: key) {
                        self.onPick?(choice)
                        return nil
                    }
                    return event
                }
            } else if window == nil, let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        private func match(key: String) -> CardChoice? {
            if key == "y", let allow = choices.first(where: { $0.kind == .allow }) { return allow }
            if key == "n", let deny = choices.first(where: { $0.kind == .deny }) { return deny }
            if let digit = Int(key), digit >= 1, digit <= choices.count {
                return choices[digit - 1]
            }
            return nil
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
