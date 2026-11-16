import AppKit
import Observation

/// The menu bar note. Clicking it opens the panel, and clicking it again closes it.
final class StatusItemController: NSObject {
    private let model: AppModel
    private let panel: PanelController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(model: AppModel, panel: PanelController) {
        self.model = model
        self.panel = panel
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            // On mouse down, like the system's own menu bar items, so the toggle
            // and the panel's outside-click monitor see the same moment.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            panel.onVisibilityChange = { [weak button] isVisible in
                button?.highlight(isVisible)
            }
        }
        render()
    }

    /// Opens the panel without a click: at first launch, and when the app is opened again.
    /// Just after launch macOS has not yet put the item in the menu bar, and a panel
    /// opened then would hang from the wrong place, so this waits (up to two seconds) until it has.
    func showPanel() {
        Task {
            for _ in 0..<20 where !isInMenuBar {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !panel.isVisible, isInMenuBar, let button = statusItem.button else { return }
            panel.show(below: button)
        }
    }

    /// Whether the item's window sits in the menu bar, above the screen's usable area.
    private var isInMenuBar: Bool {
        guard let window = statusItem.button?.window, let screen = window.screen else { return false }
        return window.frame.width > 0 && window.frame.maxY >= screen.visibleFrame.maxY
    }

    /// Draws the current state, then redraws whenever anything it read changes.
    private func render() {
        withObservationTracking {
            let status = model.status
            let description = switch status {
            case .active: "MediaKeys for Spotify: on"
            case .paused: "MediaKeys for Spotify: off"
            case .needsSetup: "MediaKeys for Spotify: needs setup"
            }
            if let button = statusItem.button {
                // Off is a choice, so it dims; needing setup is a problem, so it gets a badge.
                button.image = status == .needsSetup ? MenuBarGlyph.badgedImage : MenuBarGlyph.image
                button.appearsDisabled = status == .paused
                button.toolTip = description
                button.setAccessibilityLabel(description)
            }
        } onChange: { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        panel.toggle(below: sender)
    }
}
