import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelManager: NotchPanelManager?
    private var stateMachine: ClotchStateMachine?
    private var socketServer: SocketServer?
    private var hookInstaller: HookInstaller?
    private var usageService: UsageService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory — no dock icon, no menu bar app icon
        NSApplication.shared.setActivationPolicy(.accessory)

        // Initialize services
        let settings = AppSettings()
        let sessionStore = SessionStore()
        let sentimentAnalyzer = SentimentAnalyzer()
        let soundService = SoundService()
        let conversationParser = ConversationParser()
        let terminalFocusDetector = TerminalFocusDetector()
        let usageService = UsageService()
        self.usageService = usageService

        // Initialize state machine
        let stateMachine = ClotchStateMachine(
            sessionStore: sessionStore,
            sentimentAnalyzer: sentimentAnalyzer,
            soundService: soundService,
            conversationParser: conversationParser,
            terminalFocusDetector: terminalFocusDetector,
            usageService: usageService,
            settings: settings
        )
        self.stateMachine = stateMachine

        // Initialize and show notch panel
        let panelManager = NotchPanelManager(
            sessionStore: sessionStore,
            stateMachine: stateMachine,
            usageService: usageService,
            settings: settings
        )
        self.panelManager = panelManager
        panelManager.showPanel()

        // Start socket server
        let socketServer = SocketServer(
            socketPath: "/tmp/clotch.sock",
            handler: { [weak stateMachine] event in
                stateMachine?.handleEvent(event)
            },
            permissionHandler: { [weak stateMachine] payload in
                stateMachine?.handlePermissionRequest(payload)
            }
        )
        self.socketServer = socketServer
        stateMachine.socketServer = socketServer
        socketServer.start()

        // Install hooks into Claude Code
        let hookInstaller = HookInstaller()
        self.hookInstaller = hookInstaller
        hookInstaller.installIfNeeded()

        // Start usage polling
        usageService.startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }
}
