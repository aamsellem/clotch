import SwiftUI

/// The expanded panel view shown when the user clicks the notch.
/// Contains session info, grass island with sprites, activity feed, and usage bar.
struct ExpandedPanelView: View {
    @Bindable var sessionStore: SessionStore
    @Bindable var usageService: UsageService
    @Bindable var panelManager: NotchPanelManager
    let settings: AppSettings

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Grass island with session sprites — only when sessions exist
            if !settings.hideSprite && !sessionStore.sessions.isEmpty {
                GrassIslandView(sessionStore: sessionStore)
                    .frame(height: 80)
                    .padding(.horizontal, 12)
            }

            // Session info header
            if let session = sessionStore.activeSession {
                sessionHeader(session)
            }

            Divider()
                .background(TerminalColors.border)

            // Activity feed or empty state
            if sessionStore.activeSession != nil {
                activityFeed
                    .frame(maxHeight: 300)
            } else {
                emptyState
                    .frame(maxHeight: 300)
            }

            Divider()
                .background(TerminalColors.border)

            // Usage bar
            if usageService.quota.isAvailable {
                UsageBarView(usageService: usageService)
            }

            // Bottom toolbar
            bottomBar
        }
        // No extra background/clip — parent NotchContentView handles clipping
        .sheet(isPresented: $showSettings) {
            PanelSettingsView(settings: settings, panelManager: panelManager)
        }
    }

    private func sessionHeader(_ session: SessionData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.task.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TerminalColors.text)

                    if session.task == .working {
                        ProcessingSpinner(verb: panelManager.stateMachine.spinnerVerb)
                    }
                }

                Text("\(session.projectName ?? String(session.id.prefix(8))) • \(session.durationString)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TerminalColors.textSecondary)
            }

            Spacer()

            // Open in cmux button
            if CmuxIntegration.isAvailable, session.projectName != nil {
                Button(action: {
                    if let name = session.projectName {
                        CmuxIntegration.focusWorkspace(for: name)
                        CmuxIntegration.activateApp()
                    }
                }) {
                    Image(systemName: "terminal")
                        .font(.system(size: 12))
                        .foregroundStyle(TerminalColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Open in cmux")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var activityFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if let session = sessionStore.activeSession {
                        ForEach(session.activities.suffix(50)) { item in
                            switch item.kind {
                            case .prompt:
                                UserPromptBubbleView(text: item.text)
                            case .assistant:
                                AssistantTextRowView(text: item.text)
                            default:
                                ActivityRowView(item: item)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            // Session list (if multiple)
            if sessionStore.sessions.count > 1 {
                SessionListView(sessionStore: sessionStore)
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(TerminalColors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkle")
                .font(.system(size: 28))
                .foregroundStyle(TerminalColors.textTertiary)
            Text("Waiting for Claude Code...")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(TerminalColors.textSecondary)
            Text("Start a session to see activity here")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(TerminalColors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // Emotion is reflected directly in the sprite (task × emotion combo), no badge needed
}
