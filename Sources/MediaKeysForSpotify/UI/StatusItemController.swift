import AppKit
import Observation
import os

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

    /// Opens the panel without a click: at first launch (`takingFocus: false`, so it does not
    /// take the keyboard from another app) and when the app is opened again.
    /// Just after launch macOS has not yet put the item in the menu bar, and a panel
    /// opened then would hang from the wrong place, so this waits (up to two seconds) until it has.
    /// If the item never gets a place (no room beside the notch, or hidden in System Settings),
    /// the panel opens at the top right of the main screen instead of not at all.
    func showPanel(takingFocus: Bool) {
        Task {
            for _ in 0..<20 where !isInMenuBar {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !panel.isVisible else { return }
            if isInMenuBar, let button = statusItem.button {
                panel.show(below: button, takingFocus: takingFocus)
            } else if let screen = NSScreen.main ?? NSScreen.screens.first {
                Logger.app.notice("The status item is not in the menu bar; showing the panel at the top right")
                let visible = screen.visibleFrame
                panel.show(anchoredAt: NSRect(x: visible.maxX, y: visible.maxY, width: 0, height: 0), on: screen, takingFocus: takingFocus)
            }
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
            // In the panel's own words, so the tooltip and the panel never disagree.
            let state = switch status {
            case .active: "Media keys go to Spotify"
            case .paused: "Media keys go to the app that played last"
            case .needsSetup where !model.isSpotifyInstalled: "Spotify isn’t installed"
            case .needsSetup where model.needsPermission: "Finish setup"
            case .needsSetup: "Can’t catch the media keys"
            }
            if let button = statusItem.button {
                // Giving the keys back is a choice, so it dims; needing setup is a problem, so it gets a badge.
                button.image = status == .needsSetup ? MenuBarGlyph.badgedImage : MenuBarGlyph.image
                button.appearsDisabled = status == .paused
                button.toolTip = "MediaKeys for Spotify: \(state)"
                button.setAccessibilityLabel("MediaKeys for Spotify. \(state)")
            }
        } onChange: { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        panel.toggle(below: sender)
    }
}
