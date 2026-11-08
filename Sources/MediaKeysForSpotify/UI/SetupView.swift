import SwiftUI

/// The single setup screen: two permissions, open at login, done.
struct SetupView: View {
    let model: AppModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            header

            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    accessibilityRow
                    Divider().padding(.leading, 52)
                    spotifyRow
                }
                .groupBox()

                Toggle(isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }
                )) {
                    Text("Open at login")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .tint(.spotifyGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .groupBox()
            }

            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 440)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("MediaKeys for Spotify")
                .font(.title2.weight(.semibold))
            Text("Your keyboard’s play, pause and skip keys always control Spotify.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityRow: some View {
        PermissionRow(
            symbol: "keyboard",
            title: "Accessibility",
            detail: "Lets MediaKeys catch media keys before other apps do.",
            hint: model.hasRequestedAccessibility && !model.isAccessibilityGranted
                ? "Turn on MediaKeys for Spotify in System Settings. If it’s already on, select it, click −, then add it again."
                : nil,
            isGranted: model.isAccessibilityGranted,
            buttonTitle: model.hasRequestedAccessibility ? "Open Settings" : "Allow…",
            action: model.requestAccessibility
        )
    }

    @ViewBuilder private var spotifyRow: some View {
        if !model.isSpotifyInstalled, model.automation != .granted {
            PermissionRow(
                symbol: "music.note",
                title: "Spotify",
                detail: "Spotify isn’t installed. MediaKeys works with the Spotify desktop app.",
                hint: nil,
                isGranted: false,
                buttonTitle: "Get Spotify",
                action: { NSWorkspace.shared.open(URL(string: "https://www.spotify.com/download")!) }
            )
        } else {
            PermissionRow(
                symbol: "music.note",
                title: "Spotify",
                detail: "Lets MediaKeys tell Spotify to play, pause and skip.",
                hint: nil,
                isGranted: model.automation == .granted,
                isBusy: model.isRequestingAutomation,
                buttonTitle: model.automation == .denied ? "Open Settings" : "Allow…",
                action: {
                    if model.automation == .denied {
                        model.openAutomationSettings()
                    } else {
                        Task { await model.requestAutomation() }
                    }
                }
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text(model.isSetupComplete
                 ? "You’re all set. MediaKeys lives in your menu bar."
                 : "MediaKeys starts working as soon as both are allowed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let hint: String?
    let isGranted: Bool
    var isBusy = false
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            trailing.frame(minHeight: 26)
        }
        .padding(14)
    }

    @ViewBuilder private var trailing: some View {
        if isGranted {
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .labelStyle(GrantedLabelStyle())
                .accessibilityLabel("\(title) allowed")
        } else if isBusy {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Asking Spotify")
        } else {
            Button(buttonTitle, action: action)
        }
    }
}

private struct GrantedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(Color.spotifyGreen)
            configuration.title.foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

private extension View {
    func groupBox() -> some View {
        background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
    }
}

extension Color {
    static let spotifyGreen = Color(red: 0x1D / 255, green: 0xB9 / 255, blue: 0x54 / 255)
}
