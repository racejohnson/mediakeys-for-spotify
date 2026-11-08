<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="MediaKeys for Spotify icon">
</p>

# MediaKeys for Spotify

A small menu bar app that makes your Mac's play, pause and skip keys control Spotify, and only Spotify.

On a Mac, the media keys go to whichever app last played sound. Press play and you might get a YouTube tab, Apple Music, or a video you closed an hour ago. MediaKeys catches those keys before any other app sees them and hands them to Spotify, whatever app is in front.

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/racejohnson/mediakeys-for-spotify/releases).
2. Open it and drag **MediaKeys for Spotify** into **Applications**.
3. Open the app from Applications.

The app is not notarized by Apple, so the first time you open it macOS may refuse. Either right-click the app and choose **Open**, or go to **System Settings > Privacy & Security**, scroll down, and click **Open Anyway**. You only need to do this once.

You need macOS 14 (Sonoma) or later and the Spotify desktop app. It runs natively on Apple silicon and Intel Macs.

## First launch

A setup window asks for two permissions. MediaKeys starts working as soon as both are allowed.

- **Accessibility** lets MediaKeys catch the media keys before other apps do. Without it, macOS delivers the keys to everyone else first. macOS shows its own prompt once; after that, the button opens the Accessibility list in System Settings, where you switch MediaKeys on.
- **Spotify (Automation)** lets MediaKeys tell Spotify to play, pause and skip. macOS can only ask this while Spotify is running, so MediaKeys opens Spotify in the background first, then macOS asks.

If the Spotify desktop app isn't installed, the setup window says so and links to the download instead.

There is also an **Open at login** switch, which is on by default. MediaKeys asks for nothing else and makes no network connections.

## Using it

MediaKeys lives in your menu bar as a pair of eighth notes, with no Dock icon. Click it for the menu:

- **Send Media Keys to Spotify**: on or off. When it's off, MediaKeys steps aside and your media keys work the way macOS normally handles them.
- **Setup…**: reopens the setup window. It reads **Finish Setup…** when something is missing. Opening the app again from Finder or Spotlight does the same.
- **Open at Login**
- **About** and **Quit**

The icon dims when you turn MediaKeys off, and shows a small dot when setup isn't finished.

MediaKeys only takes the keys when it can pass them on. If Accessibility or Automation is off, or Spotify isn't installed, your media keys keep working the way macOS normally handles them.

If Spotify isn't running when you press a key, MediaKeys opens it in the background and then plays or skips. Presses made while Spotify is still starting are ignored.

## Troubleshooting

**Keys stopped working after an update.** Each build of MediaKeys has a new signature, and macOS can keep the old build's Accessibility entry, which then no longer applies. Open **System Settings > Privacy & Security > Accessibility**, select MediaKeys for Spotify, remove it with the minus button, then open MediaKeys and allow Accessibility again.

**The keys go to other apps instead of Spotify.** Check **System Settings > Privacy & Security > Automation** and make sure Spotify is switched on under MediaKeys for Spotify. If you turned it off there, the setup window's **Open Settings** button takes you straight to it. Also check that the Spotify desktop app is installed: MediaKeys does not control Spotify in a browser.

**Holding a key down doesn't skip repeatedly.** That is on purpose. Each physical press counts once, so a held key can't skip through your queue.

## Build from source

You need macOS 14 or later, Xcode 26 or later (its `actool` compiles the Icon Composer app icon, and Swift 6.2 or later builds the code), and nothing else. There is no Xcode project; it's a Swift package.

```bash
./scripts/run-dev.sh      # debug build of the app, then launch it
./scripts/build-app.sh    # build/MediaKeys for Spotify.app (universal release)
./scripts/build-dmg.sh    # build/MediaKeys-for-Spotify-<version>.dmg
swift test                # run the tests
```

The build signs with the first Developer ID Application or Apple Development certificate in your keychain, and ad-hoc if there is none. A certificate keeps the Accessibility permission across rebuilds; an ad-hoc build has to be removed from the Accessibility list and added again after each rebuild. To pick a certificate, set `SIGN_IDENTITY` (`-` forces ad-hoc):

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-dmg.sh
```

Use `run-dev.sh` rather than `swift run`: the permissions attach to the app bundle, so the app has to run as a real `.app`.

## License

MIT. See [LICENSE](LICENSE).
