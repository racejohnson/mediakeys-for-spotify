import ServiceManagement
import os

protocol LoginItemManaging {
    var isEnabled: Bool { get }
    /// Turned off in System Settings › General › Login Items; only the person can turn it back on there.
    var needsApproval: Bool { get }
    func setEnabled(_ enabled: Bool)
    func openSystemSettings()
}

/// The app itself as a login item. macOS owns the truth; nothing is cached.
struct MainAppLoginItem: LoginItemManaging {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Could not \(enabled ? "add" : "remove", privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
