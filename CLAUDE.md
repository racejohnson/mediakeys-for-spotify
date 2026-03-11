# CLAUDE.md

## Project Overview

MediaKeys for Spotify is a native macOS menu bar app (Swift 6.0, macOS 13+) that globally intercepts media keys (Play/Pause, Next, Previous) and routes them exclusively to Spotify. Built with SwiftPM — no Xcode build flow.

## Commands

- **Dev run**: `./scripts/run-dev.sh` (generates icons, then `swift run`)
- **Build app**: `./scripts/build-app.sh` → `build/MediaKeys for Spotify.app`
- **Build DMG**: `./scripts/build-dmg.sh` → `build/MediaKeys-for-Spotify.dmg`
- **Generate icons**: `./scripts/generate-icons.sh` (SVG → PNG/icns pipeline)
- **Run all tests**: `swift test`
- **Run single test**: `swift test --filter MediaKeyDecoderTests`

## Architecture

```
Sources/MediaKeysForSpotify/
├── App/          # Entry point (@main), NSAppDelegate, AppState (Observable)
├── Core/         # Media key interception, Spotify control, permissions, login item
├── MenuBar/      # NSStatusItem, context menu, SVG→CGPath icon rendering
├── Onboarding/   # SwiftUI 3-step setup wizard (NSHostingController)
└── Resources/    # Bundle assets (AppIcon.icns, menu bar PNGs)
```

## Key Conventions

- **Concurrency**: All UI-touching classes are `@MainActor final`. Non-UI code (MediaKeyDecoder, MediaKeyInterceptor) uses closure-based callbacks.
- **Protocols**: Use verb-ing suffix (`SpotifyControlling`, `PermissionManaging`, `LoginItemManaging`). Tests inject mock implementations.
- **State persistence**: AppState syncs `@Published` properties to UserDefaults via `didSet`. Keys stored in private `enum Keys`.
- **Error handling**: No throws — uses optional returns and Bool success values. Errors go to stderr.
- **Testing**: Closure-based dependency injection, isolated UserDefaults suites per test, mock managers for protocols.
- **Icons**: SVG source in `assets/svg/`, rasterized to `assets/generated/` and copied into `Sources/.../Resources/`.

## Build Details

- Release builds target `arm64` only
- App bundle is ad-hoc signed (`codesign --force --deep --sign -`)
- Bundle ID: `com.racejohnson.mediakeys-for-spotify`
- LSUIElement: true (menu bar only, no dock icon)
