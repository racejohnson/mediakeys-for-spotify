import Foundation
import Testing
@testable import MediaKeysForSpotify

private final class FakeTap: MediaKeyTapping {
    var canStart = true
    private(set) var isRunning = false

    func start() -> Bool {
        isRunning = canStart
        return canStart
    }

    func stop() { isRunning = false }
}

private final class FakeSpotify: SpotifyControlling {
    var isInstalled = true
    var status: AutomationStatus?
    var statusWhenAsked: AutomationStatus?
    private(set) var launches = 0

    func automationStatus(askingIfNeeded: Bool) async -> AutomationStatus? {
        askingIfNeeded ? statusWhenAsked : status
    }

    func launchInBackground() async -> Bool {
        launches += 1
        return true
    }
}

private final class FakeAccessibility: AccessibilityChecking {
    var isTrusted = false
    private(set) var prompts = 0
    func prompt() { prompts += 1 }
}

private final class FakeLoginItem: LoginItemManaging {
    var isEnabled = false
    var needsApproval = false
    private(set) var calls: [Bool] = []
    private(set) var settingsOpened = 0

    func setEnabled(_ enabled: Bool) {
        calls.append(enabled)
        isEnabled = enabled && !needsApproval
    }

    func openSystemSettings() { settingsOpened += 1 }
}

/// One model wired to fakes, with its own throwaway UserDefaults.
private final class Harness {
    let defaults: UserDefaults
    let tap = FakeTap()
    let spotify = FakeSpotify()
    let accessibility = FakeAccessibility()
    let loginItem = FakeLoginItem()
    private(set) var openedPanes: [SettingsPane] = []

    init() {
        let suite = "AppModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    func makeModel() -> AppModel {
        AppModel(
            defaults: defaults,
            tap: tap,
            spotify: spotify,
            accessibility: accessibility,
            loginItem: loginItem,
            openSettings: { self.openedPanes.append($0) }
        )
    }

    /// Everything allowed.
    func grantAll() {
        accessibility.isTrusted = true
        spotify.status = .granted
    }
}

struct AppModelTests {
    @Test func enabledByDefaultAndPersisted() {
        let harness = Harness()
        let model = harness.makeModel()
        #expect(model.isEnabled)

        model.isEnabled = false
        #expect(harness.defaults.bool(forKey: "isEnabled") == false)
        #expect(harness.makeModel().isEnabled == false)
    }

    @Test func tapRunsOnlyWhenEnabledAndAccessibilityGranted() async {
        let harness = Harness()
        let model = harness.makeModel()
        #expect(!harness.tap.isRunning)

        harness.accessibility.isTrusted = true
        await model.refresh()
        #expect(harness.tap.isRunning)

        model.isEnabled = false
        #expect(!harness.tap.isRunning)

        model.isEnabled = true
        #expect(harness.tap.isRunning)

        harness.accessibility.isTrusted = false
        await model.refresh()
        #expect(!harness.tap.isRunning)
    }

    @Test func tapStopsWhenAutomationIsDenied() async {
        let harness = Harness()
        harness.accessibility.isTrusted = true
        let model = harness.makeModel()
        #expect(harness.tap.isRunning) // not determined yet: the first press asks

        harness.spotify.status = .denied
        await model.refresh()
        #expect(!harness.tap.isRunning)
        #expect(model.status == .needsSetup)

        harness.spotify.status = .granted
        await model.refresh()
        #expect(harness.tap.isRunning)
    }

    @Test func tapStopsWhenSpotifyIsNotInstalled() async {
        let harness = Harness()
        harness.grantAll()
        harness.spotify.isInstalled = false
        let model = harness.makeModel()
        await model.refresh()
        #expect(!harness.tap.isRunning)
        #expect(model.status == .needsSetup)
        #expect(!model.needsPermission) // nothing the setup window can ask for

        harness.spotify.isInstalled = true
        await model.refresh()
        #expect(harness.tap.isRunning)
        #expect(model.status == .active)
    }

    @Test func deniedSendStopsTap() async {
        let harness = Harness()
        harness.grantAll()
        let model = harness.makeModel()
        await model.refresh()
        #expect(harness.tap.isRunning)

        model.automationWasDenied()
        #expect(model.automation == .denied)
        #expect(!harness.tap.isRunning)
    }

    @Test func statusFollowsPermissionsAndChoice() async {
        let harness = Harness()
        let model = harness.makeModel()
        #expect(model.status == .needsSetup)

        harness.accessibility.isTrusted = true
        await model.refresh()
        #expect(model.status == .needsSetup) // Spotify not allowed yet

        harness.spotify.status = .granted
        await model.refresh()
        #expect(model.status == .active)
        #expect(model.isSetupComplete)

        model.isEnabled = false
        #expect(model.status == .paused)
    }

    @Test func tapStartFailureNeedsSetup() async {
        let harness = Harness()
        harness.grantAll()
        harness.tap.canStart = false
        let model = harness.makeModel()
        await model.refresh()
        #expect(model.status == .needsSetup)
        #expect(!model.isTapRunning)
    }

    @Test func unknownAutomationKeepsLastAnswer() async {
        let harness = Harness()
        harness.grantAll()
        let model = harness.makeModel()
        await model.refresh()
        #expect(model.automation == .granted)

        harness.spotify.status = nil // Spotify quit
        await model.refresh()
        #expect(model.automation == .granted)
        #expect(harness.makeModel().automation == .granted) // and across launches
    }

    @Test func requestingAutomationOpensSpotifyThenAsks() async {
        let harness = Harness()
        harness.spotify.statusWhenAsked = .granted
        let model = harness.makeModel()
        await model.requestAutomation()
        #expect(harness.spotify.launches == 1)
        #expect(model.automation == .granted)
    }

    @Test func secondAccessibilityRequestOpensSettings() {
        let harness = Harness()
        let model = harness.makeModel()
        model.requestAccessibility()
        model.requestAccessibility()
        #expect(harness.accessibility.prompts == 1)
        #expect(harness.openedPanes == [.accessibility])
    }

    @Test func registersLoginItemOnlyOnFirstLaunch() {
        let harness = Harness()
        let model = harness.makeModel()
        #expect(model.opensAtLogin)

        model.setOpensAtLogin(false)
        #expect(!model.opensAtLogin)

        let relaunched = harness.makeModel()
        #expect(!relaunched.opensAtLogin)
        #expect(harness.loginItem.calls == [true, false])
    }

    @Test func refreshPicksUpLoginItemChangedElsewhere() async {
        let harness = Harness()
        let model = harness.makeModel()
        #expect(model.opensAtLogin)

        harness.loginItem.isEnabled = false // turned off in System Settings
        await model.refresh()
        #expect(!model.opensAtLogin)
    }

    @Test func blockedLoginItemOpensSystemSettings() {
        let harness = Harness()
        let model = harness.makeModel()
        model.setOpensAtLogin(false)
        harness.loginItem.needsApproval = true
        model.setOpensAtLogin(true)
        #expect(!model.opensAtLogin)
        #expect(harness.loginItem.settingsOpened == 1)
    }

    @Test func respectsVersionOneLoginOptOut() {
        let harness = Harness()
        harness.defaults.set(false, forKey: "launchAtLogin")
        #expect(!harness.makeModel().opensAtLogin)
        #expect(harness.loginItem.calls.isEmpty)
    }
}
