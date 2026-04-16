import SwiftUI

/// Constants for the notch panel geometry
enum NotchConstants {
    static let expandedSize = CGSize(width: 450, height: 450)
    static let horizontalPadding: CGFloat = 19 * 2
}

/// Corner radii for collapsed and expanded states
private let cornerRadii = (
    expanded: (top: CGFloat(19), bottom: CGFloat(24)),
    collapsed: (top: CGFloat(6), bottom: CGFloat(14))
)

/// Main view rendered inside the notch panel.
/// The panel spans the full screen width but this view clips itself
/// to the notch shape, making everything else transparent.
struct NotchContentView: View {
    @Bindable var panelManager: NotchPanelManager
    @Bindable var sessionStore: SessionStore
    @Bindable var usageService: UsageService
    let settings: AppSettings

    @State private var isHovering = false

    private var notchWidth: CGFloat { panelManager.notchSize.width }
    private var notchHeight: CGFloat { panelManager.notchSize.height }

    // Dynamic size: collapsed = notch size, expanded = larger panel
    private var currentWidth: CGFloat {
        panelManager.isExpanded
            ? NotchConstants.expandedSize.width
            : notchWidth + (isHovering ? 16 : 0)
    }
    private var currentHeight: CGFloat {
        panelManager.isExpanded
            ? NotchConstants.expandedSize.height
            : notchHeight + (isHovering ? 6 : 0)
    }

    private var topRadius: CGFloat {
        panelManager.isExpanded ? cornerRadii.expanded.top : cornerRadii.collapsed.top
    }
    private var bottomRadius: CGFloat {
        panelManager.isExpanded ? cornerRadii.expanded.bottom : cornerRadii.collapsed.bottom
    }

    /// Whether the sprite should peek out (Claude needs user attention)
    private var shouldPeek: Bool {
        guard let session = sessionStore.activeSession else { return false }
        return session.task == .waiting && !panelManager.isExpanded
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main notch-shaped content area
            VStack(spacing: 0) {
                notchContent
                    .frame(width: currentWidth, height: currentHeight)
                    .clipShape(NotchShape(cornerRadius: topRadius, bottomRadius: bottomRadius))
                    .shadow(
                        color: .black.opacity(panelManager.isExpanded ? 0.5 : 0.2),
                        radius: panelManager.isExpanded ? 20 : 6,
                        y: panelManager.isExpanded ? 8 : 2
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: panelManager.isExpanded)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovering)

                Spacer()
            }

            // Peek sprite — slides out to the right of the notch when waiting
            if let session = sessionStore.activeSession, !settings.hideSprite {
                peekSprite(session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Which side the peek appears on — alternates based on session id hash
    private var peekOnRight: Bool {
        guard let session = sessionStore.activeSession else { return true }
        return session.id.hashValue % 2 == 0
    }

    /// Sprite that peeks out from the side of the notch when Claude waits for input.
    /// Same height as notch, black background, flush — looks like the notch extends.
    private func peekSprite(session: SessionData) -> some View {
        let right = peekOnRight
        let sign: CGFloat = right ? 1 : -1
        let peekX: CGFloat = shouldPeek ? sign * (currentWidth / 2 + 14) : sign * (currentWidth / 2 - 20)

        return HStack(spacing: 0) {
            if !right {
                // Left side: padding on the left, sprite on the right
                Spacer(minLength: 6)
            }
            SessionSpriteView(session: session)
                .frame(width: 30, height: 30)
            if right {
                Spacer(minLength: 6)
            }
        }
        .frame(height: notchHeight)
        .padding(.horizontal, 4)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: right ? 0 : 0,
                bottomLeadingRadius: right ? 0 : notchHeight / 2,
                bottomTrailingRadius: right ? notchHeight / 2 : 0,
                topTrailingRadius: right ? 0 : 0
            )
            .fill(.black)
        )
        .offset(x: peekX, y: 0)
        .opacity(shouldPeek ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shouldPeek)
        .onTapGesture {
            panelManager.isExpanded.toggle()
        }
    }

    @ViewBuilder
    private var notchContent: some View {
        ZStack(alignment: .top) {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.07)

            VStack(spacing: 0) {
                // Header row (always visible, matches notch height)
                headerRow
                    .frame(height: notchHeight)

                // Expanded content
                if panelManager.isExpanded {
                    ExpandedPanelView(
                        sessionStore: sessionStore,
                        usageService: usageService,
                        panelManager: panelManager,
                        settings: settings
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onHover { hovering in
            if !panelManager.isExpanded {
                isHovering = hovering
            }
        }
        .onTapGesture {
            panelManager.isExpanded.toggle()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            if let session = sessionStore.activeSession {
                // Sprite
                if !settings.hideSprite {
                    SessionSpriteView(session: session)
                        .frame(width: 24, height: 24)
                }

                // Status dot
                statusDot(for: session.task)

                // Session count
                if sessionStore.sessions.count > 1 {
                    Text("\(sessionStore.sessions.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
            } else {
                // Idle — show Clotch branding
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                Text("clotch")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
    }

    private func statusDot(for task: ClotchTask) -> some View {
        Circle()
            .fill(statusColor(for: task))
            .frame(width: 7, height: 7)
            .overlay(
                task == .working
                    ? Circle()
                        .fill(statusColor(for: task).opacity(0.4))
                        .scaleEffect(1.8)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                    : nil
            )
    }

    private func statusColor(for task: ClotchTask) -> Color {
        switch task {
        case .idle: .gray
        case .working: .green
        case .sleeping: .blue.opacity(0.6)
        case .compacting: .orange
        case .waiting: .yellow
        }
    }
}
