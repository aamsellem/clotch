import SwiftUI
import ServiceManagement

/// Settings panel accessible from the expanded panel.
struct PanelSettingsView: View {
    let settings: AppSettings
    @Bindable var panelManager: NotchPanelManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Clotch Settings")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(TerminalColors.text)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(TerminalColors.blue)
            }
            .padding(.bottom, 8)

            // Display settings
            settingsSection("Display") {
                Toggle("Show sprite", isOn: Binding(
                    get: { !settings.hideSprite },
                    set: { settings.hideSprite = !$0 }
                ))

                Toggle("Sentiment analysis (on-device)", isOn: Binding(
                    get: { settings.sentimentEnabled },
                    set: { settings.sentimentEnabled = $0 }
                ))
            }

            // Sound settings
            settingsSection("Sound") {
                Toggle("Enable sounds", isOn: Binding(
                    get: { settings.soundEnabled },
                    set: { settings.soundEnabled = $0 }
                ))

                if settings.soundEnabled {
                    Picker("Sound", selection: Binding(
                        get: { settings.soundName },
                        set: { settings.soundName = $0 }
                    )) {
                        ForEach(NotificationSound.allCases) { sound in
                            Text(sound.displayName).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Hook status
            settingsSection("Hooks") {
                let installer = HookInstaller()
                HStack {
                    Circle()
                        .fill(installer.isInstalled ? TerminalColors.green : TerminalColors.red)
                        .frame(width: 8, height: 8)
                    Text(installer.isInstalled ? "Hooks installed" : "Hooks not installed")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TerminalColors.textSecondary)
                }

                if !installer.isInstalled {
                    Button("Install Hooks") {
                        installer.installIfNeeded()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Info
            settingsSection("About") {
                Text("Clotch v1.0.0")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TerminalColors.textTertiary)
                Text("Sentiment: NLTagger (on-device, 0 tokens)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TerminalColors.textTertiary)
            }

            Spacer()

            // Quit button
            HStack {
                Spacer()
                Button("Quit Clotch") {
                    // Dismiss sheet first, then quit after a short delay
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.terminate(nil)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(20)
        .frame(width: 320, height: 500)
        .background(TerminalColors.background)
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(TerminalColors.textTertiary)

            content()
        }
    }
}
