import AppKit
import SwiftUI

/// Manages the NotchPanel window lifecycle, geometry, and expand/collapse state.
/// The panel spans the full screen width and is tall (500pt). The SwiftUI content
/// clips itself to the notch shape, making everything else transparent and click-through.
@Observable
final class NotchPanelManager {
    private var panel: NotchPanel?
    private let eventMonitor = EventMonitor()

    let sessionStore: SessionStore
    let stateMachine: ClotchStateMachine
    let usageService: UsageService
    let settings: AppSettings

    // MARK: - Geometry (in screen coordinates)

    /// The notch interactive rect (collapsed state)
    var notchRect: CGRect = .zero
    /// The expanded panel rect
    var panelRect: CGRect = .zero
    /// The notch size detected from the screen
    var notchSize: CGSize = .zero
    /// The screen frame
    var screenFrame: CGRect = .zero

    // MARK: - State

    var isExpanded: Bool = false {
        didSet {
            if isExpanded {
                eventMonitor.startMonitoring { [weak self] in
                    self?.isExpanded = false
                }
            } else {
                eventMonitor.stopMonitoring()
            }
        }
    }

    // MARK: - Constants

    static let windowHeight: CGFloat = 500
    static let expandedPanelSize = CGSize(width: 450, height: 450)

    init(sessionStore: SessionStore, stateMachine: ClotchStateMachine, usageService: UsageService, settings: AppSettings) {
        self.sessionStore = sessionStore
        self.stateMachine = stateMachine
        self.usageService = usageService
        self.settings = settings

        NotificationCenter.default.addObserver(
            forName: .clotchCollapsePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isExpanded = false
        }

        NotificationCenter.default.addObserver(
            forName: .clotchTogglePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isExpanded.toggle()
        }
    }

    /// Compute all geometry rects from the given screen
    func updateGeometry(for screen: NSScreen) {
        screenFrame = screen.frame
        notchSize = screen.notchSize

        let notchCenterX = screenFrame.midX
        // Add side padding around the notch for a wider clickable area
        let sideWidth = max(0, notchSize.height - 12) + 24
        let notchTotalWidth = notchSize.width + sideWidth

        notchRect = CGRect(
            x: notchCenterX - notchTotalWidth / 2,
            y: screenFrame.maxY - notchSize.height,
            width: notchTotalWidth,
            height: notchSize.height
        )

        let panelWidth = Self.expandedPanelSize.width + 38
        panelRect = CGRect(
            x: notchCenterX - panelWidth / 2,
            y: screenFrame.maxY - Self.expandedPanelSize.height,
            width: panelWidth,
            height: Self.expandedPanelSize.height
        )
    }

    func showPanel() {
        let screen = ScreenSelector.preferred(settings: settings)
        updateGeometry(for: screen)

        // Window spans the full screen width, anchored to top
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - Self.windowHeight,
            width: screenFrame.width,
            height: Self.windowHeight
        )

        let panel = NotchPanel(frame: windowFrame)
        self.panel = panel

        // Set up SwiftUI content
        let contentView = NotchContentView(
            panelManager: self,
            sessionStore: sessionStore,
            usageService: usageService,
            settings: settings
        )

        let hostingView = NSHostingView(rootView: contentView)

        // Set up hit test view — fills the entire window, passes through clicks
        // outside the notch/panel rects
        let hitTestView = NotchHitTestView()
        hitTestView.panelManager = self
        hitTestView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        hitTestView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: hitTestView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: hitTestView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: hitTestView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: hitTestView.trailingAnchor),
        ])

        panel.contentView = hitTestView
        panel.orderFrontRegardless()
    }
}
