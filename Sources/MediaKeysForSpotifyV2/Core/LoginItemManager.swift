import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: LoginItemManaging {
    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                fputs("Failed to update login item registration: \(error)\n", stderr)
            }
        }
    }
}
