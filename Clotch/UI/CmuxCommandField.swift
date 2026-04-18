import AppKit
import SwiftUI

/// NSTextField-based input that works reliably inside a non-activating NSPanel.
///
/// SwiftUI TextField doesn't receive key events when the hosting panel is
/// `.nonactivatingPanel` because focus isn't transferred via mouse click alone.
/// This wrapper:
///   1. Activates the app + makes the panel key when the field becomes first responder
///   2. Submits on Return via NSTextFieldDelegate
///   3. Exposes a binding for the text value
struct CmuxCommandField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusStealingTextField()
        field.placeholderString = placeholder
        field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        field.textColor = NSColor.white.withAlphaComponent(0.9)
        field.backgroundColor = .clear
        field.isBordered = false
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.drawsBackground = false
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.onEnter(_:))
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: CmuxCommandField
        init(_ parent: CmuxCommandField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @objc func onEnter(_ sender: Any?) {
            parent.onSubmit()
        }
    }

    /// NSTextField subclass that activates the app + makes the window key when clicked,
    /// so typing actually reaches the text field in a non-activating panel.
    final class FocusStealingTextField: NSTextField {
        override func mouseDown(with event: NSEvent) {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
        }

        override var acceptsFirstResponder: Bool { true }
    }
}
