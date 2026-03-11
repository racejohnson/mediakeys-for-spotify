import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    let permissionManager: PermissionManaging
    let onFinish: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("MediaKeys for Spotify V2")
                    .font(.title2.bold())
                Spacer()
                Text("Step \(step + 1) of 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                switch step {
                case 0:
                    introScreen
                case 1:
                    permissionsScreen
                default:
                    completionScreen
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(24)
        .frame(width: 560, height: 440)
        .onAppear {
            appState.refreshPermissions()
            appState.startPermissionPolling()
        }
        .onDisappear {
            appState.stopPermissionPolling()
        }
    }

    private var introScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Control Spotify from anywhere")
                .font(.title3.bold())
            Text("This menu bar app captures Play/Pause, Next, and Previous media keys globally and routes them to Spotify.")
            Text("To do that, macOS requires three permissions:")
            VStack(alignment: .leading, spacing: 8) {
                Label("Input Monitoring", systemImage: "keyboard")
                Label("Accessibility", systemImage: "accessibility")
                Label("Automation (Spotify)", systemImage: "link")
            }
            .font(.body)
            Spacer()
        }
    }

    private var permissionsScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grant Required Permissions")
                .font(.title3.bold())
            Text("Use the buttons to open the exact settings panes. Status refreshes automatically.")
                .foregroundStyle(.secondary)

            PermissionRow(
                title: "Input Monitoring",
                subtitle: "Required to capture media key presses",
                granted: appState.permissions.inputMonitoring,
                actionTitle: "Open Settings"
            ) {
                permissionManager.openInputMonitoringSettings()
            }

            PermissionRow(
                title: "Accessibility",
                subtitle: "Required to intercept and suppress keys globally",
                granted: appState.permissions.accessibility,
                actionTitle: "Open Settings"
            ) {
                permissionManager.openAccessibilitySettings()
            }

            PermissionRow(
                title: "Automation",
                subtitle: "Required to send playback commands to Spotify",
                granted: appState.permissions.automation,
                actionTitle: "Open Settings"
            ) {
                permissionManager.openAutomationSettings()
            }

            HStack(spacing: 10) {
                Button("Request System Prompts") {
                    appState.requestMissingPermissionPrompts()
                }
                Button("Refresh Now") {
                    appState.refreshPermissions()
                }
            }

            Spacer()
        }
    }

    private var completionScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup Complete")
                .font(.title3.bold())
            if appState.permissions.allGranted {
                Text("All permissions are granted. Media keys will now route to Spotify when interception is enabled.")
            } else {
                Text("You can finish setup now and grant remaining permissions later from the menu.")
            }
            Text("Use left-click on the menu bar icon to toggle interception. Right-click for advanced options.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    step -= 1
                }
            }

            Spacer()

            Button(primaryActionTitle) {
                handlePrimaryAction()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var primaryActionTitle: String {
        switch step {
        case 0:
            return "Continue"
        case 1:
            return appState.permissions.allGranted ? "Continue" : "Continue Anyway"
        default:
            return "Finish"
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case 0, 1:
            step += 1
        default:
            onFinish()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(granted ? "Granted" : "Missing")
                .foregroundStyle(granted ? .green : .orange)
                .font(.subheadline.bold())
            Button(actionTitle, action: action)
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}
