import AppKit
import SwiftUI

/// NSView that selectively passes through mouse events.
/// Converts points to screen coordinates and checks against the active rect
/// provided by the panel manager (notch rect when collapsed, panel rect when expanded).
final class NotchHitTestView: NSView {
    weak var panelManager: NotchPanelManager?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window = window, let manager = panelManager else { return nil }

        // Convert local point -> screen coordinates
        let windowPoint = convert(point, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        // Determine the active interactive area
        let activeRect = manager.isExpanded ? manager.panelRect : manager.notchRect

        guard activeRect.contains(screenPoint) else {
            return nil  // Click passes through to apps below
        }

        return super.hitTest(point)
    }
}
