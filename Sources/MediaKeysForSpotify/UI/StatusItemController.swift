import AppKit
import Observation

/// The menu bar icon and its menu. Any click opens the menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let showSetup: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let enabledItem = NSMenuItem(title: "Send Media Keys to Spotify", action: #selector(toggleEnabled), keyEquivalent: "")
    private let setupItem = NSMenuItem(title: "Setup…", action: #selector(openSetup), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpensAtLogin), keyEquivalent: "")

    init(model: AppModel, showSetup: @escaping () -> Void) {
        self.model = model
        self.showSetup = showSetup
        super.init()

        let menu = NSMenu()
        menu.items = [
            enabledItem,
            setupItem,
            .separator(),
            loginItem,
            .separator(),
            NSMenuItem(title: "About MediaKeys for Spotify", action: #selector(showAbout), keyEquivalent: ""),
            NSMenuItem(title: "Quit MediaKeys for Spotify", action: #selector(NSApplication.terminate), keyEquivalent: "q"),
        ]
        for item in menu.items where item.action != #selector(NSApplication.terminate) {
            item.target = self
        }
        menu.delegate = self
        statusItem.menu = menu
        render()
    }

    /// Draws the current state, then redraws whenever anything it read changes.
    private func render() {
        withObservationTracking {
            let status = model.status
            let description = switch status {
            case .active: "MediaKeys for Spotify: on"
            case .paused: "MediaKeys for Spotify: paused"
            case .needsSetup: "MediaKeys for Spotify: needs setup"
            }
            if let button = statusItem.button {
                // Paused is a choice, so it dims; needing setup is a problem, so it gets a badge.
                button.image = status == .needsSetup ? MenuBarGlyph.badgedImage : MenuBarGlyph.image
                button.appearsDisabled = status == .paused
                button.toolTip = description
                button.setAccessibilityLabel(description)
            }
            enabledItem.state = model.isEnabled ? .on : .off
            let needsSetup = status == .needsSetup
            setupItem.title = needsSetup ? "Finish Setup…" : "Setup…"
            setupItem.image = needsSetup
                ? NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Needs attention")
                : nil
            loginItem.state = model.opensAtLogin ? .on : .off
        } onChange: { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        Task { await model.refresh() }
    }

    @objc private func toggleEnabled() {
        model.isEnabled.toggle()
    }

    @objc private func toggleOpensAtLogin() {
        model.setOpensAtLogin(!model.opensAtLogin)
    }

    @objc private func openSetup() {
        showSetup()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
