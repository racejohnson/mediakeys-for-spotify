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
        // Two developer modes that draw and quit, without touching the real system.
        // `--icon-note <file>` writes the app icon's note layer from the menu bar glyph's path.
        if let file = path(after: "--icon-note") {
            exit(IconNote.write(to: file) ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        // `--readme <folder>` redraws the README's pictures.
        if let folder = path(after: "--readme") {
            app.setActivationPolicy(.prohibited)
            ReadmePictures.write(to: folder)
            app.run()
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    /// The path given after a developer flag, or nil when the flag is absent. A flag with no
    /// path exits: it must never fall through to a real launch, which would start the tap
    /// and add the login item.
    private static func path(after flag: String) -> URL? {
        guard let index = CommandLine.arguments.firstIndex(of: flag) else { return nil }
        guard CommandLine.arguments.indices.contains(index + 1) else {
            Logger.app.error("\(flag, privacy: .public) needs a path")
            exit(64)
        }
        return URL(fileURLWithPath: CommandLine.arguments[index + 1])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Two copies would each draw a note and each catch the media keys. A copy that is
        // already quitting (an install replacing it) does not count.
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0 != .current && !$0.isTerminated }) {
            NSApp.terminate(nil)
            return
        }

        let spotify = SpotifyRemote()
        let tap = MediaKeyTap { spotify.handle($0) }
        model = AppModel(tap: tap, spotify: spotify)
        spotify.onDenied = { [model] in model?.automationWasDenied() }
        statusItem = StatusItemController(model: model, panel: PanelController(model: model))
        observeSystemChanges()

        Task {
            await model.refresh()
            // Something to allow: open the panel, which says what.
            if model.needsPermission { statusItem.showPanel(takingFocus: false) }
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
        statusItem?.showPanel(takingFocus: true)
        return false
    }
}
