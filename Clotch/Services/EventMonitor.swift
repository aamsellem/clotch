import AppKit

/// Monitors global keyboard and mouse events for the notch panel.
final class EventMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Start monitoring for clicks outside the panel (to dismiss it)
    func startMonitoring(onClickOutside: @escaping () -> Void) {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            onClickOutside()
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}
