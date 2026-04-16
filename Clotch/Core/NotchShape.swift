import SwiftUI

/// Custom shape that approximates the MacBook notch silhouette.
/// Used as a clip mask and background for the notch panel.
struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, bottomRadius) }
        set {
            cornerRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let _ = min(cornerRadius, min(w, h) / 2)
        let br = min(bottomRadius, min(w, h) / 2)

        // Top-left corner
        path.move(to: CGPoint(x: 0, y: 0))
        // Top edge
        path.addLine(to: CGPoint(x: w, y: 0))
        // Right edge
        path.addLine(to: CGPoint(x: w, y: h - br))
        // Bottom-right curve
        path.addQuadCurve(
            to: CGPoint(x: w - br, y: h),
            control: CGPoint(x: w, y: h)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: br, y: h))
        // Bottom-left curve
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - br),
            control: CGPoint(x: 0, y: h)
        )
        path.closeSubpath()

        return path
    }
}

/// Attempts to extract the system's actual notch bezel path from the built-in display.
struct SystemNotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard let screen = NSScreen.builtIn,
              let bezelPath = screen.bezelPath else {
            // Fallback to a rounded rectangle approximation
            return NotchShape(cornerRadius: 12, bottomRadius: 12).path(in: rect)
        }

        // Scale the bezel path to fit our rect
        let bounds = bezelPath.bounds
        var transform = AffineTransform.identity
        transform.translate(x: rect.origin.x - bounds.origin.x, y: rect.origin.y - bounds.origin.y)
        transform.scale(x: rect.width / bounds.width, y: rect.height / bounds.height)

        let scaled = bezelPath.copy() as! NSBezierPath
        scaled.transform(using: transform)
        return Path(scaled.cgPath)
    }
}

extension NSBezierPath {
    /// Convert NSBezierPath to CGPath
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}
