import AppKit

extension NSScreen {
    /// The built-in display (lid screen on MacBooks)
    static var builtIn: NSScreen? {
        screens.first { $0.isBuiltIn }
    }

    /// Convenience: built-in or main screen
    static var builtInOrMain: NSScreen {
        builtIn ?? main!
    }

    var isBuiltIn: Bool {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(screenNumber) != 0
    }

    /// The display ID for this screen
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    /// Whether this screen has a notch (camera housing)
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// The notch dimensions for this screen.
    /// Uses auxiliaryTopLeftArea/auxiliaryTopRightArea to compute the exact notch width.
    var notchSize: CGSize {
        guard hasNotch else {
            // Fallback for non-notch screens (still show a pill)
            return CGSize(width: 224, height: 38)
        }
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        let notchWidth = fullWidth - leftPadding - rightPadding + 4
        let menuBarHeight = frame.maxY - visibleFrame.maxY
        let notchHeight = max(safeAreaInsets.top, menuBarHeight)
        return CGSize(width: notchWidth, height: notchHeight)
    }

    /// Attempts to access the private bezelPath for the exact notch shape.
    var bezelPath: NSBezierPath? {
        guard let path = value(forKey: "bezelPath") as? NSBezierPath else {
            return nil
        }
        return path
    }
}
