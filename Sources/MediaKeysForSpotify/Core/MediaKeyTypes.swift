import Foundation

enum MediaKeyCommand: String, CaseIterable {
    case playPause
    case nextTrack
    case previousTrack
}

struct PermissionSnapshot: Equatable {
    var inputMonitoring: Bool
    var accessibility: Bool
    var automation: Bool

    var allGranted: Bool {
        inputMonitoring && accessibility && automation
    }
}

protocol SpotifyControlling {
    @discardableResult
    func handle(_ command: MediaKeyCommand) -> Bool
}

@MainActor
protocol PermissionManaging {
    func currentSnapshot() -> PermissionSnapshot
    func requestSystemPromptsIfNeeded()
    func openInputMonitoringSettings()
    func openAccessibilitySettings()
    func openAutomationSettings()
}

@MainActor
protocol LoginItemManaging {
    func setLaunchAtLogin(enabled: Bool)
}
