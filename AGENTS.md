# MediaKeys for Spotify

## Project Overview

MediaKeys for Spotify is a native macOS menu bar app (Swift 6.2+ language mode, macOS 14+) that catches the Play/Pause, Next and Previous media keys with an active event tap and sends them to Spotify as Apple Events. It needs two permissions: Accessibility (for the tap) and Automation for Spotify. Built with SwiftPM; there is no Xcode project.

## Commands

- **Install**: `./scripts/install.sh`: release build, quits the running copy, moves the app into `/Applications` (replacing the old one) and opens it. Moved, not copied, so Spotlight sees one app; the login item follows the bundle.
- **Dev run**: `./scripts/run-dev.sh`: debug bundle via `build-app.sh --debug`, quits any running copy, then `open`s it. Don't use `swift run`: TCC grants attach to the bundle ID.
- **Build app**: `./scripts/build-app.sh` → `build/MediaKeys for Spotify.app` (universal release). `--debug` builds native-arch debug.
- **Build DMG**: `./scripts/build-dmg.sh` → `build/MediaKeys-for-Spotify.dmg` (runs `build-app.sh` first).
- **Run all tests**: `swift test`
- **Run one suite**: `swift test --filter AppModelTests`
- **Preview the icon**: `"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Packaging/AppIcon.icon --export-image --output-file out.png --platform macOS --rendition Default --width 1024 --height 1024 --scale 1` (`ictool --help` lists other renditions, e.g. `TintedDark` with `--tint-color`). `docs/icon.png` is the Default export, used by the README.

## Architecture

```
Sources/MediaKeysForSpotify/
├── App/
│   ├── AppDelegate.swift            # @main entry; wires model, status item, setup window; system-change observers; Logger.app
│   └── AppModel.swift               # @Observable state: enabled, permissions, Spotify installed, login item; starts/stops the tap; polls
├── Media/
│   ├── MediaKey.swift               # MediaKey enum + MediaKeyEvent: decodes NX_SYSDEFINED subtype/data1 (pure, tested)
│   └── MediaKeyTap.swift            # CGEvent tap (MediaKeyTapping): swallows every decoded phase, acts on `MediaKeyEvent.press`
├── Spotify/
│   └── SpotifyRemote.swift          # SpotifyControlling: `spfy` Apple Events (SendResult), AutomationStatus, background launch, ordered sends
├── System/
│   ├── Permissions.swift            # AccessibilityChecking (AXIsProcessTrusted + prompt); SettingsPane deep links
│   └── LoginItem.swift              # LoginItemManaging over SMAppService.mainApp
└── UI/
    ├── MenuBarGlyph.swift           # Template menu bar image; beamed-note glyph drawn as a CGPath in code
    ├── SetupView.swift              # SwiftUI setup screen: two permission rows, open-at-login toggle, Done
    ├── SetupWindowController.swift  # Owns the single setup NSWindow; reports visibility to the model
    └── StatusItemController.swift   # NSStatusItem + menu; re-renders via withObservationTracking
Tests/MediaKeysForSpotifyTests/      # AppModelTests, MediaKeyEventTests, SpotifyRemoteTests (Swift Testing)
Packaging/
├── Info.plist                       # Bundle metadata, version, LSUIElement, NSAppleEventsUsageDescription
├── MediaKeysForSpotify.entitlements # com.apple.security.automation.apple-events
└── AppIcon.icon/                    # Icon Composer document (icon.json + Assets/note.svg, glow.svg)
scripts/                             # build-app.sh, build-dmg.sh, install.sh, run-dev.sh
docs/icon.png                        # Exported icon for the README
```

## Key Conventions

- **Concurrency**: both targets use `.defaultIsolation(MainActor.self)`, so types are main-actor unless marked `nonisolated`. Pure value types (`MediaKey`, `MediaKeyEvent`, `SpotifyCommand`, `AutomationStatus`) are `nonisolated` and `Sendable`. Blocking Apple Event work is `@concurrent` static functions. The tap callback runs on the main run loop and uses `MainActor.assumeIsolated`.
- **State**: one `@Observable` `AppModel`. It persists to `UserDefaults` in `didSet`, with keys in a private `enum Keys`. `reconcile()` is the single place that starts or stops the tap. The UI reads the model directly: SwiftUI observes it, and AppKit uses `withObservationTracking`.
- **The tap only runs when Spotify can answer**: enabled, Accessibility granted, Spotify installed, and Automation not `.denied` (`.notDetermined` runs so the first press can prompt). Otherwise keys pass through to macOS. A send that fails with -1743 calls `SpotifyRemote.onDenied` → `AppModel.automationWasDenied()`. Launch retries resend only on `.notReady` (-600/-609), never after a timeout, so a skip can't land twice.
- **Permissions**: the model polls once a second, but only while the setup window is open, a permission is missing (`needsPermission`), or the tap is down with Spotify installed. A missing Spotify alone is not polled. AppDelegate also refreshes on the `com.apple.accessibility.api` distributed notification (Accessibility list changed) and when Spotify launches. `refresh()` re-reads Accessibility, Automation, Spotify installed and the login item; the menu calls it on open. Automation status is unknowable while Spotify is closed, so the last answer is persisted. The setup window opens at launch only when `needsPermission`.
- **Dependency injection**: protocols with an -ing suffix (`MediaKeyTapping`, `SpotifyControlling`, `AccessibilityChecking`, `LoginItemManaging`) plus closures with real defaults (`SpotifyRemote(isRunning:launch:send:sleep:)`, `AppModel(openSettings:)`). Tests pass fakes; nothing touches the real system.
- **Errors**: no `throws` in app APIs. Failures return `Bool` or `nil` and are logged through `os.Logger` (`Logger.app`, subsystem = bundle ID). Never use `print`.
- **Testing**: Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. `AppModel` tests use a throwaway `UserDefaults(suiteName:)` per test.
- **Menu bar glyph**: drawn in code (`MenuBarGlyph.glyphPath()`, 1024 artboard, y down), with no image resources. It mirrors `Packaging/AppIcon.icon/Assets/note.svg`; change both together. The image fits any closed path into 18 × 18 pt. `.paused` dims the button; `.needsSetup` uses `badgedImage` (dot, bottom right).
- **App icon**: an Icon Composer document (`Packaging/AppIcon.icon`) compiled by `actool` into `Assets.car` + `AppIcon.icns` at build time. Nothing is generated into the repo. Edit it in Icon Composer and preview it with `ictool` (see Commands). After changing it, re-export `docs/icon.png`.
- **UI**: native controls and SF Symbols, with system colors plus Spotify green (`Color.spotifyGreen`, #1DB954) for granted states and the toggle. Never use Spotify's logo anywhere.
- **Package resources**: there are none (no `Bundle.module`). Bundle resources come only from the build script.

## Build Details

- Requires Xcode 26+ (`actool` for `.icon`, Swift 6.2+ toolchain).
- Release builds are universal (`arm64` + `x86_64`); debug builds are native-arch only.
- The linker gets `-platform_version macos <LSMinimumSystemVersion> <SDK version>` so the binary records the real SDK rather than 14.0. Without it, macOS 26+ runs the app in compatibility mode.
- Signing: hardened runtime (`--options runtime`) plus the apple-events entitlement, without `--deep`. With `SIGN_IDENTITY` unset, uses the first Developer ID Application, else Apple Development, identity in the keychain, else ad-hoc (`-`). Developer ID adds `--timestamp`. Ad-hoc builds are identified by cdhash, so each rebuild loses the Accessibility grant (remove and re-add the entry).
- DMG: `diskutil image create from --format UDZO` where available, else `hdiutil` (HFS+). It contains the app and an `Applications` symlink.
- Bundle ID: `com.racejohnson.mediakeys-for-spotify`. Minimum macOS: 14.0 (`Package.swift` and `LSMinimumSystemVersion`). `LSUIElement` is true (menu bar only, no Dock icon). The app also sets the `.accessory` activation policy.
- The app needs Accessibility and Automation (Spotify) only. There is no Input Monitoring, no sandbox, and no network access.
