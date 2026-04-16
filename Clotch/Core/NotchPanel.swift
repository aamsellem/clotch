import AppKit

/// NSPanel subclass that floats above the menu bar in the notch area.
/// Spans full screen width, 500pt tall. Content is transparent everywhere
/// except the clipped notch area. Click-through except in the notch hit zone.
final class NotchPanel: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true

        level = .mainMenu + 3
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            NotificationCenter.default.post(name: .clotchCollapsePanel, object: nil)
        }
    }
}

extension Notification.Name {
    static let clotchCollapsePanel = Notification.Name("clotchCollapsePanel")
    static let clotchTogglePanel = Notification.Name("clotchTogglePanel")
}
