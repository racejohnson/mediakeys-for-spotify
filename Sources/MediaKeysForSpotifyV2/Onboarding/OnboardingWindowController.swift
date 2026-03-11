import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    init(appState: AppState, permissionManager: PermissionManaging) {
        let rootView = OnboardingView(
            appState: appState,
            permissionManager: permissionManager,
            onFinish: {}
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MediaKeys for Spotify V2 Setup"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.setContentSize(NSSize(width: 560, height: 440))
        window.isReleasedWhenClosed = false

        super.init(window: window)
        self.window?.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(appState: AppState, permissionManager: PermissionManaging, onFinish: @escaping () -> Void) {
        guard let hostingController = window?.contentViewController as? NSHostingController<OnboardingView> else {
            return
        }
        hostingController.rootView = OnboardingView(
            appState: appState,
            permissionManager: permissionManager,
            onFinish: onFinish
        )
    }

    func show() {
        guard let window else {
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_: Notification) {
        NSApp.deactivate()
    }
}
