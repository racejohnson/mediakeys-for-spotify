import AppKit
import os

extension Logger {
    nonisolated static let app = Logger(subsystem: "com.racejohnson.mediakeys-for-spotify", category: "app")
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: StatusItemController!
    private var setupWindow: SetupWindowController!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let spotify = SpotifyRemote()
        let tap = MediaKeyTap { spotify.handle($0) }
        model = AppModel(tap: tap, spotify: spotify)
        spotify.onDenied = { [model] in model?.automationWasDenied() }
        setupWindow = SetupWindowController(model: model)
        statusItem = StatusItemController(model: model) { [setupWindow] in setupWindow?.show() }
        observeSystemChanges()

        Task {
            await model.refresh()
            if model.needsPermission { setupWindow.show() }
        }
    }

    /// Catches changes made while nothing is polling: Accessibility switched off in System Settings,
    /// and Spotify starting (the only time macOS can report its Automation answer).
    private func observeSystemChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [model] _ in
            // AXIsProcessTrusted lags the notification slightly.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                await model?.refresh()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [model] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == SpotifyRemote.bundleID else { return }
            Task { @MainActor in await model?.refresh() }
        }
    }

    /// Opening the app again (Finder, Spotlight) brings back the setup window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        setupWindow.show()
        return false
    }
}
