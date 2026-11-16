import ServiceManagement
import os

/// What macOS says about the app as a login item.
nonisolated enum LoginItemState: Sendable {
    case enabled
    /// Added, but switched off in System Settings › General › Login Items; only the person can allow it there.
    case needsApproval
    /// macOS cannot find the app to add: what it says for a copy outside Applications.
    case notFound
    case off
}

protocol LoginItemManaging {
    var state: LoginItemState { get }
    /// False when macOS refused; the reason is logged.
    @discardableResult func setEnabled(_ enabled: Bool) -> Bool
    func openSystemSettings()
}

/// The app itself as a login item. macOS owns the truth; nothing is cached.
struct MainAppLoginItem: LoginItemManaging {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        case .notFound: .notFound
        default: .off
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            Logger.app.error("Could not \(enabled ? "add" : "remove", privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
