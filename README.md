# MediaKeys for Spotify

`MediaKeys for Spotify` is a native macOS menu bar app that globally intercepts media keys and routes them exclusively to Spotify, regardless of the frontmost app.

## Features

- Global media key interception for `Play/Pause`, `Next`, and `Previous`
- Spotify auto-launch when media keys are pressed and Spotify is not running
- Menu bar controls:
  - Left-click toggles interception on/off
  - Right-click opens options (`Enable/Disable`, `Re-open Onboarding`, `Launch at Login`, `Quit`)
- Guided 3-step onboarding with live permission status polling
- Re-open onboarding at any time from the menu
- CLI-first build flow using `swift build` and shell scripts (no `xcodebuild` workflow)

## Requirements

- macOS 13 or later
- Spotify desktop app
- Permissions:
  - Input Monitoring
  - Accessibility
  - Automation (Spotify)

## Quick Start

```bash
./scripts/run-dev.sh
```

## Build App Bundle (No Xcode Build Flow)

```bash
./scripts/build-app.sh
```

Output app bundle:

- `build/MediaKeys for Spotify.app`

## Build DMG

```bash
./scripts/build-dmg.sh
```

Output installer:

- `build/MediaKeys-for-Spotify.dmg`

## Permissions Behavior

The app checks and updates permissions in real time:

- Input Monitoring: `CGPreflightListenEventAccess()`
- Accessibility: `AXIsProcessTrusted()`
- Automation: AppleScript probe against Spotify

If required permissions are missing, onboarding opens automatically and can be re-opened from the menu.

## Icon Pipeline

Source SVGs:

- `assets/svg/enabled.svg`
- `assets/svg/disabled.svg`

Generate PNGs + `AppIcon.icns`:

```bash
./scripts/generate-icons.sh
```

Generated artifacts are placed in `assets/generated/` and copied into source resources.

## Tests

Run unit tests:

```bash
swift test
```

Current suite includes:

- Media key decode behavior
- Spotify routing and auto-launch timing behavior
- App state persistence and onboarding gating behavior
