import SwiftUI

/// Gentle bobbing animation for sprites.
/// Piecewise cubic easeInOut with optional tremble for distressed state.
struct BobAnimation: ViewModifier {
    let isActive: Bool
    let amplitude: CGFloat
    let isTrembling: Bool

    @State private var phase: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? bobOffset : 0)
            .offset(x: isTrembling ? trembleOffset : 0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        phase = 1
                    }
                }
            }
    }

    private var bobOffset: CGFloat {
        amplitude * CGFloat(sin(phase * .pi))
    }

    private var trembleOffset: CGFloat {
        guard isTrembling else { return 0 }
        return CGFloat.random(in: -1.5...1.5)
    }
}

extension View {
    func bobAnimation(isActive: Bool = true, amplitude: CGFloat = 3, isTrembling: Bool = false) -> some View {
        modifier(BobAnimation(isActive: isActive, amplitude: amplitude, isTrembling: isTrembling))
    }
}
