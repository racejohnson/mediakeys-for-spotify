import AppKit
import Foundation

@MainActor
final class MenuBarManager: NSObject {
    var onToggleRequested: (() -> Void)?
    var onOpenOnboardingRequested: (() -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?
    var onQuitRequested: (() -> Void)?

    private let statusItem: NSStatusItem
    private let contextMenu = NSMenu()
    private var enabledImage: NSImage?
    private var disabledImage: NSImage?

    private let toggleMenuItem = NSMenuItem(title: "Disable Interception", action: nil, keyEquivalent: "")
    private let onboardingMenuItem = NSMenuItem(title: "Re-open Onboarding", action: nil, keyEquivalent: "")
    private let launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "Quit MediaKeys for Spotify", action: nil, keyEquivalent: "q")

    private var isEnabled = true
    private var launchAtLogin = true

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupStatusButton()
        setupMenu()
        loadImages()
        update(isEnabled: true, launchAtLogin: true)
    }

    func update(isEnabled: Bool, launchAtLogin: Bool) {
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin

        toggleMenuItem.title = isEnabled ? "Disable Interception" : "Enable Interception"
        launchAtLoginMenuItem.state = launchAtLogin ? .on : .off

        guard let button = statusItem.button else {
            return
        }
        button.image = isEnabled ? enabledImage : disabledImage
        button.image?.isTemplate = !isEnabled
        button.toolTip = isEnabled ? "Media keys routed to Spotify" : "Media keys passthrough mode"
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupMenu() {
        toggleMenuItem.target = self
        toggleMenuItem.action = #selector(handleToggleFromMenu(_:))

        onboardingMenuItem.target = self
        onboardingMenuItem.action = #selector(handleOnboardingFromMenu(_:))

        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.action = #selector(handleLaunchAtLoginFromMenu(_:))

        quitMenuItem.target = self
        quitMenuItem.action = #selector(handleQuitFromMenu(_:))

        contextMenu.items = [
            toggleMenuItem,
            onboardingMenuItem,
            .separator(),
            launchAtLoginMenuItem,
            .separator(),
            quitMenuItem
        ]
    }

    private func loadImages() {
        enabledImage = MenuIconRenderer.makeEnabledIcon()
            ?? loadMenuImage(named: "menu-enabled")
            ?? fallbackImage(systemName: "music.note")
        disabledImage = MenuIconRenderer.makeDisabledIcon()
            ?? loadMenuImage(named: "menu-disabled")
            ?? fallbackImage(systemName: "music.note")
    }

    private func loadMenuImage(named baseName: String) -> NSImage? {
        let searchPaths: [Bundle] = [.main]
        for bundle in searchPaths {
            if let image = bundle.image(forResource: baseName) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = false
                return image
            }
            if let url = bundle.url(forResource: baseName, withExtension: "png", subdirectory: "icons"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = false
                return image
            }
            if let url = bundle.url(forResource: baseName, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = false
                return image
            }
        }
        return nil
    }

    private func fallbackImage(systemName: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: "Media keys status"
        )
        image?.size = NSSize(width: 16, height: 16)
        image?.isTemplate = true
        return image
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onToggleRequested?()
            return
        }

        if event.type == .rightMouseUp || event.type == .rightMouseDown {
            statusItem.menu = contextMenu
            sender.performClick(nil)
            statusItem.menu = nil
            return
        }

        onToggleRequested?()
    }

    @objc
    private func handleToggleFromMenu(_: NSMenuItem) {
        onToggleRequested?()
    }

    @objc
    private func handleOnboardingFromMenu(_: NSMenuItem) {
        onOpenOnboardingRequested?()
    }

    @objc
    private func handleLaunchAtLoginFromMenu(_: NSMenuItem) {
        onLaunchAtLoginChanged?(!launchAtLogin)
    }

    @objc
    private func handleQuitFromMenu(_: NSMenuItem) {
        onQuitRequested?()
    }
}
