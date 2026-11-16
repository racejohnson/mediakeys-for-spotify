import AppKit
import os

extension Logger {
    nonisolated static let app = Logger(subsystem: "com.racejohnson.mediakeys-for-spotify", category: "app")
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: StatusItemController!

    static func main() {
        let app = NSApplication.shared
        // `--readme <folder>` redraws the README's pictures and quits, without touching the real system.
        if let flag = CommandLine.arguments.firstIndex(of: "--readme"), CommandLine.arguments.count > flag + 1 {
            app.setActivationPolicy(.prohibited)
            ReadmePictures.write(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
            app.run()
            return
        }
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
        statusItem = StatusItemController(model: model, panel: PanelController(model: model))
        observeSystemChanges()

        Task {
            await model.refresh()
            // Something to allow: open the panel, which says what.
            if model.needsPermission { statusItem.showPanel() }
        }
    }

    /// Catches changes made while nothing is polling: Accessibility switched off in System Settings,
    /// and Spotify starting (the only time macOS can report its Automation answer) or quitting.
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
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [model] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == SpotifyRemote.bundleID else { return }
                Task { @MainActor in await model?.refresh() }
            }
        }
    }

    /// Opening the app again (Finder, Spotlight) opens the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusItem.showPanel()
        return false
    }
}
