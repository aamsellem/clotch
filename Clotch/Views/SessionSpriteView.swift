import SwiftUI

/// Displays an animated sprite for a session.
/// Uses notchi sprite sheets: {task}_{emotion} with 6 frames of 64x64.
struct SessionSpriteView: View {
    let session: SessionData

    var body: some View {
        let spriteAsset = session.task.spriteAsset(for: session.emotion.current)
        let fps = session.task.spriteFPS

        SpriteSheetView(
            assetName: spriteAsset,
            frameCount: ClotchTask.spriteFrameCount,
            fps: fps
        )
        .bobAnimation(
            isActive: session.task != .sleeping,
            amplitude: session.task == .working ? 2 : 3,
            isTrembling: session.emotion.current == .sob
        )
    }
}
