import Foundation
import Observation
import os

/// The app's state: what the person wants, what macOS allows, and whether the tap runs.
@Observable
final class AppModel {
    enum Status {
        /// Media keys go to Spotify.
        case active
        /// The person turned MediaKeys off.
        case paused
        /// On, but a permission is missing, Spotify isn't installed, or the tap could not start.
        case needsSetup
    }

    /// Whether the person wants media keys sent to Spotify.
    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            reconcile()
        }
    }

    private(set) var isAccessibilityGranted: Bool
    private(set) var isSpotifyInstalled: Bool
    private(set) var automation: AutomationStatus {
        didSet { defaults.set(automation.rawValue, forKey: Keys.automation) }
    }
    private(set) var opensAtLogin: Bool
    private(set) var isTapRunning = false
    /// macOS shows its Accessibility prompt once; after that only System Settings helps.
    private(set) var hasRequestedAccessibility = false
    private(set) var isRequestingAutomation = false

    var isSetupWindowVisible = false {
        didSet { updatePolling() }
    }

    var isSetupComplete: Bool { isAccessibilityGranted && automation == .granted }

    /// A permission is missing that the setup window can ask for. Installing Spotify is up to the person.
    var needsPermission: Bool {
        !isAccessibilityGranted || (isSpotifyInstalled && automation != .granted)
    }

    var status: Status {
        if !isEnabled { return .paused }
        return isTapRunning && automation == .granted ? .active : .needsSetup
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        /// Last answer macOS gave, kept because it cannot answer while Spotify is closed.
        static let automation = "spotifyAutomation"
        static let didOfferLoginItem = "didOfferLoginItem"
        /// Written by version 1; false means the person had turned launch at login off.
        static let legacyLaunchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults
    private let tap: MediaKeyTapping
    private let spotify: SpotifyControlling
    private let accessibility: AccessibilityChecking
    private let loginItem: LoginItemManaging
    private let openSettings: (SettingsPane) -> Void
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        tap: MediaKeyTapping,
        spotify: SpotifyControlling,
        accessibility: AccessibilityChecking = SystemAccessibility(),
        loginItem: LoginItemManaging = MainAppLoginItem(),
        openSettings: @escaping (SettingsPane) -> Void = SettingsPane.open
    ) {
        self.defaults = defaults
        self.tap = tap
        self.spotify = spotify
        self.accessibility = accessibility
        self.loginItem = loginItem
        self.openSettings = openSettings

        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        automation = defaults.string(forKey: Keys.automation).flatMap(AutomationStatus.init) ?? .notDetermined
        isAccessibilityGranted = accessibility.isTrusted
        isSpotifyInstalled = spotify.isInstalled

        // Open at login by default, once. Never again, so turning it off sticks.
        if !defaults.bool(forKey: Keys.didOfferLoginItem) {
            defaults.set(true, forKey: Keys.didOfferLoginItem)
            if defaults.object(forKey: Keys.legacyLaunchAtLogin) as? Bool != false {
                loginItem.setEnabled(true)
            }
        }
        opensAtLogin = loginItem.isEnabled

        reconcile()
    }

    // MARK: - Actions

    /// Re-reads what macOS knows. Cheap: never prompts.
    func refresh() async {
        isAccessibilityGranted = accessibility.isTrusted
        isSpotifyInstalled = spotify.isInstalled
        opensAtLogin = loginItem.isEnabled
        if let answer = await spotify.automationStatus(askingIfNeeded: false) {
            automation = answer
        }
        reconcile()
    }

    func requestAccessibility() {
        if hasRequestedAccessibility {
            openSettings(.accessibility)
        } else {
            hasRequestedAccessibility = true
            accessibility.prompt()
        }
        updatePolling()
    }

    /// macOS only asks while Spotify is running, so open it quietly first.
    func requestAutomation() async {
        guard !isRequestingAutomation else { return }
        isRequestingAutomation = true
        defer { isRequestingAutomation = false }

        guard await spotify.launchInBackground() else { return }
        if let answer = await spotify.automationStatus(askingIfNeeded: true) {
            automation = answer
        }
        reconcile()
    }

    /// A send failed because Automation was turned off in System Settings.
    func automationWasDenied() {
        automation = .denied
        reconcile()
    }

    func openAutomationSettings() {
        openSettings(.automation)
    }

    func setOpensAtLogin(_ enabled: Bool) {
        loginItem.setEnabled(enabled)
        opensAtLogin = loginItem.isEnabled
        if enabled, !opensAtLogin, loginItem.needsApproval {
            loginItem.openSystemSettings()
        }
    }

    // MARK: - Reconciling

    /// The tap runs exactly when the person wants it, macOS allows it, and Spotify can take the keys.
    /// Otherwise the keys pass through, so they never vanish into a Spotify that cannot answer.
    /// `.notDetermined` still runs: the first press is what brings up the consent prompt.
    private func reconcile() {
        let shouldRun = isEnabled && isAccessibilityGranted && isSpotifyInstalled && automation != .denied
        if shouldRun, !tap.isRunning, !tap.start() {
            Logger.app.error("Media key tap did not start; will retry on the next refresh")
        } else if !shouldRun {
            tap.stop()
        }
        isTapRunning = tap.isRunning
        updatePolling()
    }

    /// Permissions have no reliable change notifications, so poll, but only while it matters.
    private func updatePolling() {
        let shouldPoll = isSetupWindowVisible || needsPermission || (status == .needsSetup && isSpotifyInstalled)
        if shouldPoll, pollTask == nil {
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self else { return }
                    await refresh()
                }
            }
        } else if !shouldPoll, let pollTask {
            pollTask.cancel()
            self.pollTask = nil
        }
    }
}
