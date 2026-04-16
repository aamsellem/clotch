import SwiftUI

/// Cross-fade animation between the collapsed header sprite and the grass island sprite.
/// Used during expand/collapse transitions.
struct SpriteHandoffVisuals: View {
    let session: SessionData
    let isExpanded: Bool

    var body: some View {
        SessionSpriteView(session: session)
            .scaleEffect(isExpanded ? 1.2 : 0.8)
            .opacity(isExpanded ? 0 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
}
