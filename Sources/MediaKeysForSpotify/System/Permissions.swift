import AppKit
import ApplicationServices

protocol AccessibilityChecking {
    var isTrusted: Bool { get }
    /// Shows the system's "would like to control this computer" prompt.
    func prompt()
}

struct SystemAccessibility: AccessibilityChecking {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func prompt() {
        // The kAXTrustedCheckOptionPrompt global is not concurrency-safe in Swift 6; this is its value.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}

/// Panes in System Settings › Privacy & Security.
nonisolated enum SettingsPane: String {
    case accessibility = "Privacy_Accessibility"
    case automation = "Privacy_Automation"

    static func open(_ pane: SettingsPane) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!
        NSWorkspace.shared.open(url)
    }
}
