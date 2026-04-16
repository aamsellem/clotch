import SwiftUI

/// Renders animated sprite sheet frames.
/// Takes an image asset containing a horizontal strip of frames.
struct SpriteSheetView: View {
    let assetName: String
    let frameCount: Int
    let fps: Double

    @State private var currentFrame: Int = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / fps)) { timeline in
            spriteFrame
                .onChange(of: timeline.date) { _, _ in
                    currentFrame = (currentFrame + 1) % frameCount
                }
        }
    }

    private var spriteFrame: some View {
        GeometryReader { geo in
            if let image = NSImage(named: assetName) {
                let frameWidth = image.size.width / CGFloat(frameCount)
                let sourceRect = CGRect(
                    x: CGFloat(currentFrame) * frameWidth,
                    y: 0,
                    width: frameWidth,
                    height: image.size.height
                )

                Image(nsImage: cropImage(image, to: sourceRect))
                    .resizable()
                    .interpolation(.none)  // Pixel-perfect scaling
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                // Placeholder when sprite sheet is missing
                placeholderSprite
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage {
        let result = NSImage(size: rect.size)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: rect.size),
            from: rect,
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }

    /// Cute pixel-art placeholder when no sprite sheet is loaded
    private var placeholderSprite: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.4, green: 0.7, blue: 1.0))

            VStack(spacing: 1) {
                // Eyes
                HStack(spacing: 4) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                    Circle().fill(.white).frame(width: 4, height: 4)
                }
                // Mouth
                Capsule().fill(.white).frame(width: 6, height: 2)
                    .offset(y: 2)
            }
        }
    }
}
