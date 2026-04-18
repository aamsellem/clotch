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

    private let notchWidth: CGFloat = 220
    private var notchHeight: CGFloat { panelManager.notchSize.height }

    // Extra width when peeking (sprite extends to the right)
    private let peekExtension: CGFloat = 50

    /// Whether a card (approval/completion) is currently shown — grows the notch
    private var showCard: Bool {
        guard let session = sessionStore.activeSession, !panelManager.isExpanded else { return false }
        if session.task == .waiting { return true }
        if let until = session.showCompletionUntil, until > Date() { return true }
        return false
    }

    // Dynamic size
    private var currentWidth: CGFloat {
        if panelManager.isExpanded { return NotchConstants.expandedSize.width }
        if showCard { return 340 }
        let base = notchWidth + (isHovering ? 16 : 0)
        return shouldPeek ? base + peekExtension : base
    }
    private var currentHeight: CGFloat {
        if panelManager.isExpanded { return NotchConstants.expandedSize.height }
        if showCard {
            // Approval card is taller (context + 2 buttons); completion is shorter
            if sessionStore.activeSession?.task == .waiting { return notchHeight + 110 }
            return notchHeight + 80
        }
        return notchHeight + (isHovering ? 6 : 0)
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
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shouldPeek)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

                // Card surface (approval / completion) — shown without expanding the full panel
                if let session = sessionStore.activeSession, !panelManager.isExpanded {
                    if session.task == .waiting {
                        ApprovalCardView(session: session)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .onAppear { panelManager.activateForInteraction() }
                    } else if let until = session.showCompletionUntil, until > Date() {
                        CompletionCardView(
                            session: session,
                            onOpenTerminal: {
                                CmuxIntegration.focusSession(projectName: session.projectName, cwd: session.cwd)
                            },
                            onDismiss: { session.showCompletionUntil = nil }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onAppear { panelManager.activateForInteraction() }
                    }
                }

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
                // Sprite (in normal position)
                if !settings.hideSprite && !shouldPeek {
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

                // Peek: sprite moves to the right extension
                if shouldPeek && !settings.hideSprite {
                    Spacer()
                    SessionSpriteView(session: session)
                        .frame(width: 28, height: 28)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
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
