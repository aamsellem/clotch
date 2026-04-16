import SwiftUI

/// The grass island area showing session sprites.
/// Clean rounded island with gradient — no individual grass blade rendering.
struct GrassIslandView: View {
    @Bindable var sessionStore: SessionStore

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Island
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.50, blue: 0.18),
                                Color(red: 0.15, green: 0.38, blue: 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 24)
                    .padding(.horizontal, 30)

                // Session sprites
                ForEach(sessionStore.orderedSessions) { session in
                    let isSelected = sessionStore.selectedSessionId == session.id

                    SessionSpriteView(session: session)
                        .frame(width: 32, height: 32)
                        .offset(
                            x: spriteOffset(session.spriteX, width: geo.size.width),
                            y: -16
                        )
                        .shadow(
                            color: isSelected ? TerminalColors.green.opacity(0.6) : .clear,
                            radius: 6
                        )
                        .onTapGesture {
                            sessionStore.selectedSessionId = session.id
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func spriteOffset(_ normalizedX: Double, width: CGFloat) -> CGFloat {
        let usableWidth = width - 80
        return CGFloat(normalizedX - 0.5) * usableWidth
    }
}
