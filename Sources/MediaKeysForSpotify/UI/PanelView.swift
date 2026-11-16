import AppKit
import SwiftUI

/// The panel: where the media keys go, the permissions while one is missing,
/// open at login and a quiet footer.
struct PanelView: View {
    let model: AppModel
    /// True for a moment after the last permission is allowed with the panel open,
    /// so the setup rows stay long enough to show "All set" and both ticks.
    @State private var setupLingers = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.needsPermission || setupLingers {
                Group {
                    SetupSection(model: model)
                    Rule()
                }
                .transition(.opacity)
            }
            RouteSection(model: model)
            Rule()
            LoginItemRow(model: model)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
            Rule()
            Footer()
        }
        .padding(10)
        .frame(width: 312)
        // The panel takes key focus without activating the app; without this its
        // controls would draw in the inactive (grey) style.
        .environment(\.controlActiveState, .key)
        .onChange(of: model.needsPermission) { _, needsPermission in
            setupLingers = !needsPermission && model.isPanelVisible
        }
        .onChange(of: model.isPanelVisible) { _, isVisible in
            if !isVisible { setupLingers = false }
        }
        .task(id: setupLingers) {
            guard setupLingers else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.glide) { setupLingers = false }
        }
    }
}

// MARK: Motion

enum Motion {
    /// The panel's one animation, or none when the person has asked macOS to reduce motion.
    static var glide: Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .snappy(duration: 0.2)
    }
}

// MARK: Colours

extension Color {
    /// Spotify green (#1DB954), deepened so white text reads on it: a little in dark mode,
    /// more in light. The same contrast as Audio Priority's blue.
    static let spotifyGreen = dynamic(light: 0x17964A, dark: 0x1AA34A)
    /// The fill of "the app that played last" while it has the keys.
    static let graphite = dynamic(light: 0x6E6E73, dark: 0x636366)

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1
            )
        })
    }
}

// MARK: Sections

/// The two permissions as rows. They show only while one is missing.
private struct SetupSection: View {
    let model: AppModel

    var body: some View {
        let needsSpotify = model.isSpotifyInstalled && model.automation != .granted
        let missing = (model.isAccessibilityGranted ? 0 : 1) + (needsSpotify ? 1 : 0)
        VStack(alignment: .leading, spacing: 1) {
            SectionHeader(title: "Finish setup", hint: missing == 0 ? "All set" : "\(missing) to allow")
            PanelRow(glyph: .symbol("keyboard"), title: "Accessibility", detail: "To catch the media keys") {
                if model.isAccessibilityGranted {
                    Allowed(name: "Accessibility")
                } else {
                    // The pills look alike, so each says what it is for when spoken or hovered.
                    let purpose = model.hasRequestedAccessibility ? "Open Accessibility in System Settings" : "Allow Accessibility"
                    Button(model.hasRequestedAccessibility ? "Open Settings" : "Allow…", action: model.requestAccessibility)
                        .buttonStyle(PillButtonStyle())
                        .accessibilityLabel(purpose)
                        .help(purpose)
                }
            }
            if model.isSpotifyInstalled {
                PanelRow(
                    glyph: .spotify, title: "Spotify",
                    detail: model.automationRequestFailed ? "Couldn’t reach Spotify. Open it, then try again" : "To play, pause and skip"
                ) {
                    if model.automation == .granted {
                        Allowed(name: "Spotify")
                    } else if model.isRequestingAutomation {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Asking Spotify")
                    } else if model.automation == .denied {
                        Button("Open Settings") { Task { await model.openAutomationSettings() } }
                            .buttonStyle(PillButtonStyle())
                            .accessibilityLabel("Open Automation in System Settings")
                            .help("Open Automation in System Settings")
                    } else {
                        Button("Allow…") { Task { await model.requestAutomation() } }
                            .buttonStyle(PillButtonStyle())
                            .accessibilityLabel("Allow control of Spotify")
                            .help("Allow MediaKeys to control Spotify")
                    }
                }
            }
            if model.hasRequestedAccessibility, !model.isAccessibilityGranted {
                Note(text: "Turn on MediaKeys for Spotify in System Settings. If it’s already on, select it, click −, then click + and add it from Applications.")
                    .padding(.top, 5)
            }
        }
    }
}

/// Where the keys go. Choosing a row is the app's on and off.
///
/// A row is filled when it is both chosen and true: Spotify once it really has the keys,
/// the other row once the person has given them back. Chosen but not yet working (a
/// permission missing, Spotify not installed, the tap down) fills neither, so the row
/// that looks chosen is never one a click would quietly switch off.
private struct RouteSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SectionHeader(title: "Media keys go to", hint: "play · next · previous")
            PanelRow(
                glyph: .spotify, title: "Spotify", detail: spotifyDetail,
                isCurrent: model.status == .active, isDimmed: !model.canChooseSpotify,
                // An unavailable row already says why in its second line.
                help: model.canChooseSpotify ? "Send play, next and previous to Spotify" : nil,
                action: model.canChooseSpotify ? { model.isEnabled = true } : nil
            ) {
                if !model.isSpotifyInstalled {
                    Button("Get Spotify") { NSWorkspace.shared.open(URL(string: "https://www.spotify.com/download")!) }
                        .buttonStyle(PillButtonStyle())
                }
            }
            PanelRow(
                glyph: .symbol("macwindow"), title: "The app that played last", detail: "The macOS default",
                isCurrent: !model.isEnabled, fill: .graphite,
                help: "Leave the keys to macOS",
                action: { model.isEnabled = false }
            ) { EmptyView() }
        }
    }

    private var spotifyDetail: String {
        if !model.isSpotifyInstalled { return "Not installed" }
        if model.needsPermission { return "Finish setup to use" }
        // Everything is allowed but macOS would not start the tap; the model retries every second.
        if model.isEnabled, !model.isTapRunning { return "Can’t catch the keys. Trying again…" }
        return model.isSpotifyRunning ? "Open" : "Opens when you press play"
    }
}

// MARK: Rows

private enum RowGlyph {
    case spotify
    case symbol(String)
}

/// One row, in Audio Priority's shape: a glyph in a circle, a name and a line under it.
/// The row in use is filled; a row with an action can be clicked or chosen with Return.
private struct PanelRow<Trailing: View>: View {
    let glyph: RowGlyph
    let title: String
    let detail: String
    var isCurrent = false
    var fill: Color = .spotifyGreen
    var isDimmed = false
    var help: String?
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let dim: Double = isDimmed ? 0.42 : 1
        let row = HStack(spacing: 8) {
            Group {
                switch glyph {
                case .spotify: SpotifyLogo().frame(width: 14, height: 14)
                case .symbol(let name): Image(systemName: name).font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: 26, height: 26)
            .background(Circle().fill(isCurrent ? AnyShapeStyle(.white.opacity(0.24)) : AnyShapeStyle(.primary.opacity(0.075))))
            .opacity(dim)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
            .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .opacity(dim)
            // Read as one thing, apart from any button beside it. A row that can be
            // chosen replaces this with its own label and value below.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isDimmed ? "\(title), unavailable, \(detail)" : "\(title), \(detail)")

            Spacer(minLength: 2)
            trailing
        }
        // The right edge lines up with the headings, rules and switch.
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrent ? AnyShapeStyle(fill) : AnyShapeStyle(.primary.opacity(action != nil && (isHovering || isFocused) ? 0.055 : 0)))
        )
        // A filled row cannot show the hover fill, so keyboard focus draws a white edge on it.
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(isCurrent && isFocused ? 0.6 : 0), lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .help(help ?? "")

        if let action {
            row
                .onHover { isHovering = $0 }
                .onTapGesture {
                    // A click focuses the row; let go, so its fill does not outstay the pointer.
                    isFocused = false
                    action()
                }
                .focusable()
                .focused($isFocused)
                // No system focus ring: a focused row takes the hover fill, or the white edge when filled.
                .focusEffectDisabled()
                .onKeyPress(keys: [.return, .space]) { _ in
                    action()
                    return .handled
                }
                // The name, then its second line as the value, so "Open" is still read once
                // the row is in use; the selected trait says which row that is.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(detail)
                .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { action() }
        } else {
            row
        }
    }
}

private struct Allowed: View {
    let name: String

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.spotifyGreen)
            .accessibilityLabel("\(name) allowed")
    }
}

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(Capsule().fill(.background.opacity(configuration.isPressed ? 0.6 : 1)).shadow(color: .black.opacity(0.14), radius: 0.75, y: 0.5))
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
    }
}

// MARK: Small pieces

private struct SectionHeader: View {
    let title: String
    let hint: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(hint)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct Rule: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

private struct Note: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.primary.opacity(0.075)))
    }
}

/// Open at Login, with the reason under it when macOS has not simply turned it on.
private struct LoginItemRow: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SwitchRow(title: "Open at Login", isOn: Binding(get: { model.opensAtLogin }, set: model.setOpensAtLogin))
            if let issue = model.loginItemIssue {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(issue.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if issue == .needsApproval {
                        Button("Open Login Items", action: model.openLoginItems)
                            .buttonStyle(.link)
                    }
                }
                .font(.system(size: 11))
            }
        }
    }
}

private struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.drawsSwitchesForPictures) private var drawsSwitch

    var body: some View {
        let toggle = Toggle(isOn: $isOn) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
        }
        if drawsSwitch {
            toggle.toggleStyle(DrawnSwitchStyle())
        } else {
            toggle.toggleStyle(.switch).controlSize(.mini)
        }
    }
}

extension EnvironmentValues {
    /// True in the README's off-screen pictures, where the system switch
    /// draws grey because its window is not the key window.
    @Entry var drawsSwitchesForPictures = false
}

/// A stand-in for the system's mini switch as it looks in the open panel.
private struct DrawnSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Capsule()
                // System blue, not the accent colour, so the picture is the same on every Mac.
                .fill(configuration.isOn ? AnyShapeStyle(Color(nsColor: .systemBlue)) : AnyShapeStyle(.primary.opacity(0.16)))
                .frame(width: 36, height: 17)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: 22, height: 13)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                        .padding(2)
                }
        }
    }
}

private struct Footer: View {
    @State private var isHoveringQuit = false

    var body: some View {
        HStack(spacing: 0) {
            Text("MediaKeys \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(isHoveringQuit ? .primary : .secondary)
                .onHover { isHoveringQuit = $0 }
                .help("Quit MediaKeys for Spotify (⌘Q)")
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
    }
}
