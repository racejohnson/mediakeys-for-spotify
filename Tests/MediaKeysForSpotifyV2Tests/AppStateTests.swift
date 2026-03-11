import XCTest
@testable import MediaKeysForSpotifyV2

@MainActor
final class AppStateTests: XCTestCase {
    func testInitialDefaultsAndPersistence() {
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let permissionManager = MockPermissionManager(
            snapshot: PermissionSnapshot(inputMonitoring: false, accessibility: true, automation: true)
        )
        let loginManager = MockLoginItemManager()

        let state = AppState(
            defaults: defaults,
            permissionManager: permissionManager,
            loginItemManager: loginManager
        )

        XCTAssertTrue(state.isEnabled)
        XCTAssertTrue(state.launchAtLogin)
        XCTAssertTrue(loginManager.lastSetValue ?? false)
        XCTAssertTrue(state.shouldShowOnboarding)

        state.toggleEnabled()
        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "isEnabled"))
    }

    func testLaunchAtLoginUpdatesPersistedValue() {
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let permissionManager = MockPermissionManager(
            snapshot: PermissionSnapshot(inputMonitoring: true, accessibility: true, automation: true)
        )
        let loginManager = MockLoginItemManager()

        let state = AppState(
            defaults: defaults,
            permissionManager: permissionManager,
            loginItemManager: loginManager
        )

        state.launchAtLogin = false

        XCTAssertFalse(state.launchAtLogin)
        XCTAssertEqual(loginManager.callCount, 2) // Initial sync + user update
        XCTAssertEqual(loginManager.lastSetValue, false)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
    }

    func testRefreshPermissionsUpdatesOnboardingState() {
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let permissionManager = MockPermissionManager(
            snapshot: PermissionSnapshot(inputMonitoring: false, accessibility: false, automation: false)
        )
        let loginManager = MockLoginItemManager()

        let state = AppState(
            defaults: defaults,
            permissionManager: permissionManager,
            loginItemManager: loginManager
        )

        XCTAssertTrue(state.shouldShowOnboarding)

        permissionManager.snapshot = PermissionSnapshot(inputMonitoring: true, accessibility: true, automation: true)
        state.refreshPermissions()

        XCTAssertFalse(state.shouldShowOnboarding)
    }
}

@MainActor
private final class MockPermissionManager: PermissionManaging {
    var snapshot: PermissionSnapshot

    init(snapshot: PermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> PermissionSnapshot {
        snapshot
    }

    func requestSystemPromptsIfNeeded() {}

    func openInputMonitoringSettings() {}

    func openAccessibilitySettings() {}

    func openAutomationSettings() {}
}

@MainActor
private final class MockLoginItemManager: LoginItemManaging {
    private(set) var callCount = 0
    private(set) var lastSetValue: Bool?

    func setLaunchAtLogin(enabled: Bool) {
        callCount += 1
        lastSetValue = enabled
    }
}
