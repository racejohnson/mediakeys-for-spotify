import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    let permissionManager: PermissionManaging
    let onFinish: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepIndicators
                .padding(.bottom, OnboardingTheme.sectionSpacing)

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
                .padding(.top, OnboardingTheme.sectionSpacing)
        }
        .padding(OnboardingTheme.windowPadding)
        .frame(width: OnboardingTheme.windowWidth, height: OnboardingTheme.windowHeight)
        .background(Color.white)
        .onAppear {
            appState.refreshPermissions()
            appState.startPermissionPolling()
        }
        .onDisappear {
            appState.stopPermissionPolling()
        }
    }

    // MARK: - Step Indicators

    private var stepIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: OnboardingTheme.stepIndicatorRadius)
                        .fill(index <= step ? Color.black : Color.black.opacity(0.1))
                        .frame(
                            width: OnboardingTheme.stepIndicatorSize,
                            height: OnboardingTheme.stepIndicatorSize
                        )

                    if index < step {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(index <= step ? .white : OnboardingTheme.mutedText)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Step 0: Intro

    private var introScreen: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.itemSpacing) {
            Text("Getting Started")
                .font(OnboardingTheme.uppercaseLabel)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(OnboardingTheme.labelText)

            Text("Control Spotify\nfrom anywhere")
                .font(OnboardingTheme.heroTitle)
                .tracking(-0.5)
                .foregroundStyle(.black)

            Text("This menu bar app captures Play/Pause, Next, and Previous media keys globally and routes them to Spotify.")
                .font(OnboardingTheme.body)
                .foregroundStyle(OnboardingTheme.bodyText)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                Text("To do that, macOS requires three permissions:")
                    .font(OnboardingTheme.small)
                    .foregroundStyle(OnboardingTheme.descriptionText)

                numberedItem(1, "Input Monitoring")
                numberedItem(2, "Accessibility")
                numberedItem(3, "Automation (Spotify)")
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    private func numberedItem(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: OnboardingTheme.stepIndicatorRadius)
                    .fill(Color.black)
                    .frame(
                        width: OnboardingTheme.stepIndicatorSize,
                        height: OnboardingTheme.stepIndicatorSize
                    )
                Text("\(number)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(OnboardingTheme.body)
                .foregroundStyle(OnboardingTheme.bodyText)
        }
    }

    // MARK: - Step 1: Permissions

    private var permissionsScreen: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.itemSpacing) {
            Text("Permissions")
                .font(OnboardingTheme.uppercaseLabel)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(OnboardingTheme.labelText)

            Text("Grant Required Permissions")
                .font(OnboardingTheme.sectionTitle)
                .tracking(-0.3)
                .foregroundStyle(.black)

            Text("Use the buttons to open the exact settings panes. Status refreshes automatically.")
                .font(OnboardingTheme.small)
                .foregroundStyle(OnboardingTheme.descriptionText)
                .lineSpacing(3)

            VStack(spacing: 0) {
                PermissionRow(
                    title: "Input Monitoring",
                    subtitle: "Required to capture media key presses",
                    granted: appState.permissions.inputMonitoring,
                    actionTitle: "Open Settings"
                ) {
                    permissionManager.openInputMonitoringSettings()
                }

                Divider()

                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Required to intercept and suppress keys globally",
                    granted: appState.permissions.accessibility,
                    actionTitle: "Open Settings"
                ) {
                    permissionManager.openAccessibilitySettings()
                }

                Divider()

                PermissionRow(
                    title: "Automation",
                    subtitle: "Required to send playback commands to Spotify",
                    granted: appState.permissions.automation,
                    actionTitle: "Open Settings"
                ) {
                    permissionManager.openAutomationSettings()
                }
            }

            HStack(spacing: 10) {
                Button("Request System Prompts") {
                    appState.requestMissingPermissionPrompts()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Refresh Now") {
                    appState.refreshPermissions()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(OnboardingTheme.descriptionText)
            }

            Spacer()
        }
    }

    // MARK: - Step 2: Completion

    private var completionScreen: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.itemSpacing) {
            Text(appState.permissions.allGranted ? "All Set" : "Almost There")
                .font(OnboardingTheme.uppercaseLabel)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(OnboardingTheme.labelText)

            HStack(spacing: 10) {
                Text(appState.permissions.allGranted ? "Setup Complete" : "Almost There")
                    .font(OnboardingTheme.sectionTitle)
                    .tracking(-0.3)
                    .foregroundStyle(.black)

                if appState.permissions.allGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OnboardingTheme.spotifyGreen)
                }
            }

            if appState.permissions.allGranted {
                Text("All permissions are granted. Media keys will now route to Spotify when interception is enabled.")
                    .font(OnboardingTheme.body)
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .lineSpacing(4)
            } else {
                Text("You can finish setup now and grant remaining permissions later from the menu.")
                    .font(OnboardingTheme.body)
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How to use")
                    .font(OnboardingTheme.featureTitle)
                    .foregroundStyle(.black)
                Text("Left-click the menu bar icon to toggle interception on or off. Right-click for more options.")
                    .font(OnboardingTheme.small)
                    .foregroundStyle(OnboardingTheme.descriptionText)
                    .lineSpacing(3)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        step -= 1
                    }
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Button(primaryActionTitle) {
                handlePrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(step == 2 ? OnboardingTheme.spotifyGreen : .black)
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
            withAnimation(.easeInOut(duration: 0.15)) {
                step += 1
            }
        default:
            onFinish()
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(OnboardingTheme.featureTitle)
                    .foregroundStyle(.black)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(granted ? OnboardingTheme.spotifyGreen : OnboardingTheme.mutedText)
                    Text(granted ? "Granted" : "Missing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(granted ? OnboardingTheme.spotifyGreen : OnboardingTheme.mutedText)
                }
                if !granted {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Text(subtitle)
                .font(OnboardingTheme.small)
                .foregroundStyle(OnboardingTheme.descriptionText)
                .lineSpacing(3)
        }
        .padding(.vertical, 14)
    }
}
