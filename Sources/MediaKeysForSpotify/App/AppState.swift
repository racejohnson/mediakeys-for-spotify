import Combine
import Foundation

@MainActor
final class AppState: NSObject, ObservableObject {
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            loginItemManager.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    @Published private(set) var permissions: PermissionSnapshot

    private let defaults: UserDefaults
    private let permissionManager: PermissionManaging
    private let loginItemManager: LoginItemManaging
    private var pollingTimer: Timer?

    init(
        defaults: UserDefaults = .standard,
        permissionManager: PermissionManaging,
        loginItemManager: LoginItemManaging
    ) {
        if defaults.object(forKey: Keys.isEnabled) == nil {
            defaults.set(true, forKey: Keys.isEnabled)
        }
        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            defaults.set(true, forKey: Keys.launchAtLogin)
        }

        let initialIsEnabled = defaults.bool(forKey: Keys.isEnabled)
        let initialLaunchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        let initialPermissions = permissionManager.currentSnapshot()

        self.defaults = defaults
        self.permissionManager = permissionManager
        self.loginItemManager = loginItemManager
        self.isEnabled = initialIsEnabled
        self.launchAtLogin = initialLaunchAtLogin
        self.permissions = initialPermissions

        super.init()

        loginItemManager.setLaunchAtLogin(enabled: launchAtLogin)
    }

    var shouldShowOnboarding: Bool {
        !permissions.allGranted
    }

    func toggleEnabled() {
        isEnabled.toggle()
    }

    func refreshPermissions() {
        permissions = permissionManager.currentSnapshot()
    }

    func requestMissingPermissionPrompts() {
        permissionManager.requestSystemPromptsIfNeeded()
    }

    func startPermissionPolling() {
        stopPermissionPolling()
        pollingTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handlePermissionPollTick),
            userInfo: nil,
            repeats: true
        )
        pollingTimer?.tolerance = 0.2
    }

    func stopPermissionPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    @objc
    private func handlePermissionPollTick() {
        refreshPermissions()
    }
}
