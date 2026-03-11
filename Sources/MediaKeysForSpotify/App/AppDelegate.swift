import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionManager: PermissionManaging
    private let loginItemManager: LoginItemManaging
    private let spotifyController: SpotifyControlling

    private var appState: AppState!
    private var interceptor: MediaKeyInterceptor!
    private var menuBarManager: MenuBarManager!
    private var onboardingWindowController: OnboardingWindowController?
    private var cancellables = Set<AnyCancellable>()

    init(
        permissionManager: PermissionManaging = PermissionsManager(),
        loginItemManager: LoginItemManaging = LoginItemManager(),
        spotifyController: SpotifyControlling = SpotifyController()
    ) {
        self.permissionManager = permissionManager
        self.loginItemManager = loginItemManager
        self.spotifyController = spotifyController
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        appState = AppState(
            permissionManager: permissionManager,
            loginItemManager: loginItemManager
        )

        interceptor = MediaKeyInterceptor(
            isEnabledProvider: { [weak self] in
                self?.appState.isEnabled == true
            },
            onCommand: { [weak self] command in
                _ = self?.spotifyController.handle(command)
            }
        )

        menuBarManager = MenuBarManager()
        menuBarManager.onToggleRequested = { [weak self] in
            self?.appState.toggleEnabled()
        }
        menuBarManager.onOpenOnboardingRequested = { [weak self] in
            self?.showOnboarding()
        }
        menuBarManager.onLaunchAtLoginChanged = { [weak self] enabled in
            self?.appState.launchAtLogin = enabled
        }
        menuBarManager.onQuitRequested = {
            NSApp.terminate(nil)
        }

        bindState()
        appState.refreshPermissions()
        appState.startPermissionPolling()
        updateInterceptorState()

        if appState.shouldShowOnboarding {
            showOnboarding()
            appState.requestMissingPermissionPrompts()
        }
    }

    func applicationWillTerminate(_: Notification) {
        interceptor.stop()
        appState.stopPermissionPolling()
    }

    private func bindState() {
        Publishers.CombineLatest(appState.$isEnabled, appState.$launchAtLogin)
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled, launchAtLogin in
                self?.menuBarManager.update(isEnabled: isEnabled, launchAtLogin: launchAtLogin)
                self?.updateInterceptorState()
            }
            .store(in: &cancellables)

        appState.$permissions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateInterceptorState()
            }
            .store(in: &cancellables)
    }

    private func updateInterceptorState() {
        guard appState.isEnabled else {
            interceptor.stop()
            return
        }
        guard appState.permissions.inputMonitoring, appState.permissions.accessibility else {
            interceptor.stop()
            return
        }
        _ = interceptor.start()
    }

    private func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                appState: appState,
                permissionManager: permissionManager
            )
        }

        onboardingWindowController?.update(
            appState: appState,
            permissionManager: permissionManager,
            onFinish: { [weak self] in
                self?.appState.refreshPermissions()
                self?.onboardingWindowController?.close()
            }
        )
        onboardingWindowController?.show()
    }
}
