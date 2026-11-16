# MediaKeys for Spotify

## Project Overview

MediaKeys for Spotify is a native macOS menu bar app (Swift 6.2+ language mode, macOS 26+) that catches the Play/Pause, Next and Previous media keys with an active event tap and sends them to Spotify as Apple Events. It needs two permissions: Accessibility (for the tap) and Automation for Spotify. Built with SwiftPM; there is no Xcode project.

## Commands

- **Install**: `./scripts/install.sh`: release build, quits the running copy, moves the app into `/Applications` (replacing the old one) and opens it. Moved, not copied, so Spotlight sees one app; the login item follows the bundle.
- **Dev run**: `./scripts/run-dev.sh`: debug bundle via `build-app.sh --debug`, quits any running copy, then `open`s it. Don't use `swift run`: TCC grants attach to the bundle ID.
- **Build app**: `./scripts/build-app.sh` → `build/MediaKeys for Spotify.app` (universal release). `--debug` builds native-arch debug.
- **Build DMG**: `./scripts/build-dmg.sh` → `build/MediaKeys-for-Spotify.dmg` (runs `build-app.sh` first).
- **Redraw the README's pictures**: `./scripts/readme-pictures.sh` → `docs/panel.png` and `docs/icon-on.png`, `icon-setup.png`, `icon-off.png`. A debug build draws them off screen (`--readme <folder>`) from stand-ins, so nothing real is read or changed; it exits non-zero and leaves the old pictures if anything fails. Run it after changing the panel or the menu bar glyph.
- **Run all tests**: `swift test`
- **Run one suite**: `swift test --filter AppModelTests`
- **Preview the icon**: `"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Packaging/AppIcon.icon --export-image --output-file out.png --platform macOS --rendition Default --width 1024 --height 1024 --scale 1` (`ictool --help` lists other renditions, e.g. `TintedDark` with `--tint-color`). `docs/icon.png` is the Default export, used by the README.

## Architecture

```
Sources/MediaKeysForSpotify/
├── App/
│   ├── AppDelegate.swift            # @main entry; wires model, panel, status item; system-change observers; `--readme`; Logger.app
│   ├── AppModel.swift               # @Observable state: enabled, permissions, Spotify installed and open, login item; starts/stops the tap; polls
│   └── ReadmePictures.swift         # `--readme <folder>`: draws the README's pictures off screen from stand-ins
├── Media/
│   ├── MediaKey.swift               # MediaKey enum + MediaKeyEvent: decodes NX_SYSDEFINED subtype/data1 (pure, tested)
│   └── MediaKeyTap.swift            # CGEvent tap (MediaKeyTapping): swallows every decoded phase, acts on `MediaKeyEvent.press`
├── Spotify/
│   └── SpotifyRemote.swift          # SpotifyControlling: `spfy` Apple Events (SendResult), AutomationStatus, background launch, ordered sends
├── System/
│   ├── Permissions.swift            # AccessibilityChecking (AXIsProcessTrusted + prompt); SettingsPane deep links
│   └── LoginItem.swift              # LoginItemManaging over SMAppService.mainApp; LoginItemState
└── UI/
    ├── MenuBarGlyph.swift           # Template menu bar image; beamed-note glyph drawn as a CGPath in code
    ├── PanelController.swift        # The glass panel under the status item (from DayNight); closes on outside clicks, except during setup
    ├── PanelView.swift              # SwiftUI panel: setup rows, "Media keys go to" rows, open-at-login switch, footer
    ├── SpotifyLogo.swift            # Spotify's mark as a Shape, for the panel's Spotify rows only
    └── StatusItemController.swift   # NSStatusItem; a click toggles the panel; re-renders via withObservationTracking
Tests/MediaKeysForSpotifyTests/      # AppModelTests, MediaKeyEventTests, SpotifyRemoteTests (Swift Testing)
Packaging/
├── Info.plist                       # Bundle metadata, version, LSUIElement, NSAppleEventsUsageDescription
├── MediaKeysForSpotify.entitlements # com.apple.security.automation.apple-events
└── AppIcon.icon/                    # Icon Composer document (icon.json + Assets/note.svg, glow.svg)
scripts/                             # build-app.sh, build-dmg.sh, install.sh, run-dev.sh, readme-pictures.sh
docs/                                # README pictures: icon.png (exported icon); panel.png and icon-on/setup/off.png (drawn by readme-pictures.sh)
```

## Key Conventions

- **Concurrency**: both targets use `.defaultIsolation(MainActor.self)`, so types are main-actor unless marked `nonisolated`. Pure value types (`MediaKey`, `MediaKeyEvent`, `SpotifyCommand`, `AutomationStatus`) are `nonisolated` and `Sendable`. Blocking Apple Event work is `@concurrent` static functions. The tap callback runs on the main run loop and uses `MainActor.assumeIsolated`.
- **State**: one `@Observable` `AppModel`. It persists to `UserDefaults` in `didSet`, with keys in a private `enum Keys`. `reconcile()` is the single place that starts or stops the tap. The UI reads the model directly: SwiftUI observes it, and AppKit uses `withObservationTracking`.
- **The tap only runs when Spotify can answer**: enabled, Accessibility granted, Spotify installed, and Automation not `.denied` (`.notDetermined` runs so the first press can prompt). Otherwise keys pass through to macOS. A send that fails with -1743 calls `SpotifyRemote.onDenied` → `AppModel.automationWasDenied()`. Launch retries resend only on `.notReady` (-600/-609), never after a timeout, so a skip can't land twice.
- **Panel**: there is no menu and no setup window. A click on the status item toggles one glass panel (`PanelController`, shared with DayNight and Audio Priority, so keep its sizes and behaviour in step with theirs). "Media keys go to" is the on/off: the Spotify row sets `isEnabled = true`, "The app that played last" sets it false. A row is filled only when it is both chosen and true: Spotify when `status == .active`, the other when `!isEnabled`. Chosen but not working yet (`.needsSetup`) fills neither, so a click on the row that looks chosen never switches the app off unseen. The two permissions are rows that show only while `needsPermission` (plus about a second of "All set" after the last one is allowed with the panel open); while `needsPermission`, outside clicks and other apps coming forward do not close the panel (Esc and the status item do), and a display change moves it instead of closing it. The panel opens by itself at launch when `needsPermission`, without taking keyboard focus, and when the app is opened again. If the status item has no place in the menu bar, it opens at the top right of the main screen. A second copy of the app quits at launch.
- **Permissions**: the model polls once a second, but only while the panel is open, a permission is missing (`needsPermission`), or the tap is down with Spotify installed. A missing Spotify alone is not polled. AppDelegate also refreshes on the `com.apple.accessibility.api` distributed notification (Accessibility list changed) and when Spotify launches or quits. `refresh()` re-reads Accessibility, Automation, Spotify installed and open, and the login item; the panel calls it on open. Automation status is unknowable while Spotify is closed, so the last answer is persisted, and both Allow… and (after a denial) Open Settings open Spotify quietly first. An Allow… that gets no answer sets `automationRequestFailed`, which the row shows.
- **Login item**: macOS owns the truth (`LoginItemState`); nothing is cached. `opensAtLogin` is true while the item is enabled or waiting for approval. A failed or blocked attempt leaves `loginItemIssue`, shown under the switch with an "Open Login Items" link when approval is needed, as in the sibling apps. Nothing opens System Settings by itself.
- **Dependency injection**: protocols with an -ing suffix (`MediaKeyTapping`, `SpotifyControlling`, `AccessibilityChecking`, `LoginItemManaging`) plus closures with real defaults (`SpotifyRemote(isRunning:launch:send:sleep:)`, `AppModel(openSettings:)`). Tests pass fakes; nothing touches the real system.
- **Errors**: no `throws` in app APIs. Failures return `Bool` or `nil` and are logged through `os.Logger` (`Logger.app`, subsystem = bundle ID). Never use `print`.
- **Testing**: Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. `AppModel` tests use a throwaway `UserDefaults(suiteName:)` per test.
- **Menu bar glyph**: drawn in code (`MenuBarGlyph.glyphPath()`, 1024 artboard, y down), with no image resources. It mirrors `Packaging/AppIcon.icon/Assets/note.svg`; change both together. The image fits any closed path into 18 × 18 pt. `.paused` dims the button; `.needsSetup` uses `badgedImage` (dot, bottom right).
- **App icon**: an Icon Composer document (`Packaging/AppIcon.icon`) compiled by `actool` into `Assets.car` + `AppIcon.icns` at build time. Nothing is generated into the repo. Edit it in Icon Composer and preview it with `ictool` (see Commands). After changing it, re-export `docs/icon.png`.
- **UI**: the panel uses Audio Priority's numbers (312 pt wide, 38 pt rows, 26 pt glyph circles, 10 pt padding); change them there and here together. SF Symbols and system colors, plus two of its own: `Color.spotifyGreen` (#1DB954 deepened so white text reads on it: #17964A in light mode, #1AA34A in dark) for the Spotify row and granted checks, and `Color.graphite` for the other row. Rows that can be chosen speak as a name plus a value, with the selected trait on the one in use; every pill button has a spoken label naming what it is for. Spotify's logo (`SpotifyLogo`, drawn in code, one ink) appears only in the panel's Spotify rows, to name where the keys go. Never use it in the menu bar, the app icon or anywhere else.
- **Package resources**: there are none (no `Bundle.module`). Bundle resources come only from the build script.

## Build Details

- Requires Xcode 26+ (`actool` for `.icon`, Swift 6.2+ toolchain).
- Release builds are universal (`arm64` + `x86_64`); debug builds are native-arch only.
- The linker gets `-platform_version macos <LSMinimumSystemVersion> <SDK version>` so the binary records the real SDK rather than the deployment target. Without it, macOS runs the app in compatibility mode (old-style controls).
- Signing: hardened runtime (`--options runtime`) plus the apple-events entitlement, without `--deep`. With `SIGN_IDENTITY` unset, uses the first Developer ID Application, else Apple Development, identity in the keychain, else ad-hoc (`-`). Developer ID adds `--timestamp`. Ad-hoc builds are identified by cdhash, so each rebuild loses the Accessibility grant (remove and re-add the entry).
- DMG: `diskutil image create from --format UDZO` where available, else `hdiutil` (HFS+). It contains the app and an `Applications` symlink.
- Bundle ID: `com.racejohnson.mediakeys-for-spotify`. Minimum macOS: 26.0 (`Package.swift` and `LSMinimumSystemVersion`), for the glass panel (`NSGlassEffectView`). `LSUIElement` is true (menu bar only, no Dock icon). The app also sets the `.accessory` activation policy.
- The app needs Accessibility and Automation (Spotify) only. There is no Input Monitoring, no sandbox, and no network access.
