# MediaKeys for Spotify

A lightweight macOS menu bar app that intercepts your keyboard's media keys (Play/Pause, Next, Previous) and sends them exclusively to Spotify — no matter which app is in the foreground.

If you've ever hit Play and had Apple Music, a browser tab, or another app steal the command instead of Spotify, this fixes that.

## How It Works

1. **Download** the app and drop it in Applications.
2. **Grant three permissions** — the built-in setup wizard walks you through each one.
3. **Press play** — Spotify responds every time.

The app lives in your menu bar. Left-click the icon to toggle interception on or off. Right-click for options like Launch at Login and re-opening the setup wizard.

## Features

- **Global media key capture** — Play/Pause, Next, and Previous are intercepted system-wide, regardless of which app is focused.
- **Spotify auto-launch** — Press a media key when Spotify isn't running and it launches automatically and starts playing.
- **Menu bar control** — Left-click to toggle, right-click for options. No dock icon, no windows in the way.
- **Guided onboarding** — A 3-step setup wizard walks you through the permissions macOS requires. Re-open it anytime from the menu.
- **Launch at login** — One toggle to start the app every time your Mac boots.

## Requirements

- macOS 13 (Ventura) or later
- [Spotify](https://www.spotify.com/download/) desktop app
- Three macOS permissions (the app guides you through granting these):
  - **Input Monitoring** — to detect media key presses
  - **Accessibility** — to intercept and suppress keys so other apps don't respond
  - **Automation** — to send playback commands to Spotify

## Installation

### Download

Grab the latest `.dmg` from [Releases](https://github.com/racejohnson/mediakeys-for-spotify/releases), open it, and drag the app to your Applications folder.

### Build from Source

Requires Swift 6.0+ and macOS 13+. No Xcode project — built entirely with Swift Package Manager.

```bash
# Run in development mode (builds and launches)
./scripts/run-dev.sh

# Build the .app bundle
./scripts/build-app.sh
# Output: build/MediaKeys for Spotify.app

# Build the .dmg installer
./scripts/build-dmg.sh
# Output: build/MediaKeys-for-Spotify.dmg
```

## Permissions

The app checks permissions in real time and updates status automatically during onboarding:

| Permission | Why it's needed | How it's checked |
|---|---|---|
| Input Monitoring | Detect media key presses | `CGPreflightListenEventAccess()` |
| Accessibility | Intercept and suppress keys globally | `AXIsProcessTrusted()` |
| Automation | Send playback commands to Spotify | AppleScript probe |

If any permissions are missing when the app launches, the onboarding wizard opens automatically. You can also re-open it anytime from the right-click menu.

## Running Tests

```bash
swift test
```

Tests cover media key decoding, Spotify routing and auto-launch behavior, and app state persistence.

## License

MIT
