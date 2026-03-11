import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PermissionsManager: PermissionManaging {
    func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            inputMonitoring: inputMonitoringGranted(),
            accessibility: accessibilityGranted(prompt: false),
            automation: automationGranted()
        )
    }

    func requestSystemPromptsIfNeeded() {
        if !inputMonitoringGranted() {
            _ = CGRequestListenEventAccess()
        }
        if !accessibilityGranted(prompt: false) {
            _ = accessibilityGranted(prompt: true)
        }
        if !automationGranted() {
            _ = SpotifyController.automationProbe()
        }
    }

    func openInputMonitoringSettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openAccessibilitySettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openAutomationSettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private func inputMonitoringGranted() -> Bool {
        CGPreflightListenEventAccess()
    }

    private func accessibilityGranted(prompt: Bool) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private func automationGranted() -> Bool {
        SpotifyController.automationProbe()
    }

    private func openSettings(urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
