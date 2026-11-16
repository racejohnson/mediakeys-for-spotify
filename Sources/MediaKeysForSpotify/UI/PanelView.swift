import AppKit
import SwiftUI

/// The panel: where the media keys go, the permissions while one is missing,
/// open at login and a quiet footer.
struct PanelView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.needsPermission {
                SetupSection(model: model)
                Rule()
            }
            RouteSection(model: model)
            Rule()
            SwitchRow(title: "Open at Login", isOn: Binding(get: { model.opensAtLogin }, set: model.setOpensAtLogin))
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
    }
}

// MARK: Colours

extension Color {
    /// Spotify green (#1DB954), deepened in light mode so white text reads on it.
    static let spotifyGreen = dynamic(light: 0x17964A, dark: 0x1DB954)
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
            SectionHeader(title: "Finish setup", hint: "\(missing) to allow")
            PanelRow(glyph: .symbol("keyboard"), title: "Accessibility", detail: "To catch the media keys") {
                if model.isAccessibilityGranted {
                    Allowed(name: "Accessibility")
                } else {
                    Button(model.hasRequestedAccessibility ? "Open Settings" : "Allow…", action: model.requestAccessibility)
                        .buttonStyle(PillButtonStyle())
                }
            }
            if model.isSpotifyInstalled {
                PanelRow(glyph: .spotify, title: "Spotify", detail: "To play, pause and skip") {
                    if model.automation == .granted {
                        Allowed(name: "Spotify")
                    } else if model.isRequestingAutomation {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Asking Spotify")
                    } else if model.automation == .denied {
                        Button("Open Settings", action: model.openAutomationSettings)
                            .buttonStyle(PillButtonStyle())
                    } else {
                        Button("Allow…") { Task { await model.requestAutomation() } }
                            .buttonStyle(PillButtonStyle())
                    }
                }
            }
            if model.hasRequestedAccessibility, !model.isAccessibilityGranted {
                Note(text: "Turn on MediaKeys for Spotify in System Settings. If it’s already on, select it, click −, then add it again.")
                    .padding(.top, 5)
            }
        }
    }
}

/// Where the keys go. Choosing a row is the app's on and off.
private struct RouteSection: View {
    let model: AppModel

    var body: some View {
        let toSpotify = model.status == .active
        VStack(alignment: .leading, spacing: 1) {
            SectionHeader(title: "Media keys go to", hint: "play · next · previous")
            PanelRow(
                glyph: .spotify, title: "Spotify", detail: spotifyDetail,
                isCurrent: toSpotify, isDimmed: !model.canChooseSpotify,
                help: model.canChooseSpotify ? "Send play, next and previous to Spotify" : spotifyDetail,
                action: model.canChooseSpotify ? { model.isEnabled = true } : nil
            ) {
                if !model.isSpotifyInstalled {
                    Button("Get Spotify") { NSWorkspace.shared.open(URL(string: "https://www.spotify.com/download")!) }
                        .buttonStyle(PillButtonStyle())
                }
            }
            PanelRow(
                glyph: .symbol("macwindow"), title: "The app that played last", detail: "The macOS default",
                isCurrent: !toSpotify, fill: .graphite,
                help: "Leave the keys to macOS",
                action: { model.isEnabled = false }
            ) { EmptyView() }
        }
    }

    private var spotifyDetail: String {
        if !model.isSpotifyInstalled { return "Not installed" }
        if model.needsPermission { return "Finish setup to use" }
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
                // No system focus ring: a focused row takes the hover fill instead.
                .focusEffectDisabled()
                .onKeyPress(keys: [.return, .space]) { _ in
                    action()
                    return .handled
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isCurrent ? "\(title), in use" : "\(title), \(detail)")
                .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
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
        .padding(.bottom, 4)
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
                .fill(configuration.isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary.opacity(0.16)))
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
