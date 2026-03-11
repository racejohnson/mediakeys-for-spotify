import AppKit
import Foundation

final class SpotifyController: SpotifyControlling {
    static let spotifyBundleIdentifier = "com.spotify.client"

    private let startupTimeout: TimeInterval
    private let isSpotifyRunning: () -> Bool
    private let launchSpotify: () -> Void
    private let executeAppleScript: (MediaKeyCommand) -> Bool
    private let sleepStep: (TimeInterval) -> Void

    init(
        startupTimeout: TimeInterval = 8.0,
        isSpotifyRunning: @escaping () -> Bool = SpotifyController.defaultIsSpotifyRunning,
        launchSpotify: @escaping () -> Void = SpotifyController.defaultLaunchSpotify,
        executeAppleScript: @escaping (MediaKeyCommand) -> Bool = SpotifyController.defaultExecuteAppleScript,
        sleepStep: @escaping (TimeInterval) -> Void = SpotifyController.defaultSleepStep
    ) {
        self.startupTimeout = startupTimeout
        self.isSpotifyRunning = isSpotifyRunning
        self.launchSpotify = launchSpotify
        self.executeAppleScript = executeAppleScript
        self.sleepStep = sleepStep
    }

    @discardableResult
    func handle(_ command: MediaKeyCommand) -> Bool {
        if !isSpotifyRunning() {
            launchSpotify()
        }

        let deadline = Date().addingTimeInterval(startupTimeout)
        while !isSpotifyRunning(), Date() < deadline {
            sleepStep(0.1)
        }

        guard isSpotifyRunning() else {
            return false
        }

        return executeAppleScript(command)
    }

    static func defaultIsSpotifyRunning() -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: spotifyBundleIdentifier)
            .contains(where: { !$0.isTerminated })
    }

    static func defaultLaunchSpotify() {
        guard let url = URL(string: "spotify:") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func defaultExecuteAppleScript(command: MediaKeyCommand) -> Bool {
        let commandText: String
        switch command {
        case .playPause:
            commandText = "playpause"
        case .nextTrack:
            commandText = "next track"
        case .previousTrack:
            commandText = "previous track"
        }

        let source = "tell application \"Spotify\" to \(commandText)"
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return false
        }
        script.executeAndReturnError(&error)
        return error == nil
    }

    static func automationProbe() -> Bool {
        let source = """
        tell application "Spotify"
            if it is running then
                player state as string
            else
                "not running"
            end if
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return false
        }
        script.executeAndReturnError(&error)
        return error == nil
    }

    static func defaultSleepStep(_ interval: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }
}
