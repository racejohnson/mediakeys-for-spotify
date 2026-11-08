import AppKit
import os

/// A command from Spotify's scripting dictionary (event class `spfy`).
nonisolated enum SpotifyCommand: Equatable, Sendable {
    case playPause, next, previous, play

    init(_ key: MediaKey) {
        switch key {
        case .playPause: self = .playPause
        case .next: self = .next
        case .previous: self = .previous
        }
    }

    var eventID: AEEventID {
        switch self {
        case .playPause: fourCharCode("PlPs")
        case .next: fourCharCode("Next")
        case .previous: fourCharCode("Prev")
        case .play: fourCharCode("Play")
        }
    }
}

/// Whether macOS lets MediaKeys send Apple Events to Spotify (Privacy & Security › Automation).
nonisolated enum AutomationStatus: String, Sendable {
    case granted, denied, notDetermined
}

/// How one Apple Event to Spotify went.
nonisolated enum SendResult: Sendable {
    case sent
    /// Spotify is still starting up; sending again may work.
    case notReady
    /// The person turned off Automation for Spotify.
    case denied
    /// Anything else, including a timeout after Spotify may already have acted.
    case failed
}

protocol SpotifyControlling: AnyObject {
    /// Whether the Spotify desktop app is on this Mac.
    var isInstalled: Bool { get }
    /// nil when Spotify is not running, so macOS cannot say.
    func automationStatus(askingIfNeeded: Bool) async -> AutomationStatus?
    /// Opens Spotify without bringing it forward and waits until it has finished launching.
    func launchInBackground() async -> Bool
}

/// Sends media key presses to Spotify, opening it first when it is closed.
final class SpotifyRemote: SpotifyControlling {
    nonisolated static let bundleID = "com.spotify.client"

    /// Called when a send fails because Automation was turned off.
    var onDenied: () -> Void = {}

    private let isRunning: () -> Bool
    private let launch: () async -> Bool
    private let send: (SpotifyCommand) async -> SendResult
    private let sleep: (Duration) async -> Void

    private var isLaunching = false
    private var lastSend: Task<Void, Never>?

    init(
        isRunning: @escaping () -> Bool = SpotifyRemote.isSpotifyRunning,
        launch: @escaping () async -> Bool = SpotifyRemote.openSpotify,
        send: @escaping (SpotifyCommand) async -> SendResult = SpotifyRemote.sendAppleEvent,
        sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.isRunning = isRunning
        self.launch = launch
        self.send = send
        self.sleep = sleep
    }

    /// Returns at once; the returned task finishes when the command has been sent (or given up on).
    @discardableResult
    func handle(_ key: MediaKey) -> Task<Void, Never> {
        if isRunning() {
            // Chain sends so quick presses reach Spotify in order.
            let previous = lastSend
            let task = Task {
                await previous?.value
                report(await send(SpotifyCommand(key)))
            }
            lastSend = task
            return task
        }

        // One launch at a time; presses while Spotify opens are dropped.
        guard !isLaunching else { return Task {} }
        isLaunching = true
        return Task {
            defer { isLaunching = false }
            guard await launchInBackground() else { return }
            // A fresh Spotify has nothing playing, so play-pause means play.
            let command: SpotifyCommand = key == .playPause ? .play : SpotifyCommand(key)
            // Retry only while Spotify cannot take events yet, so a skip never lands twice.
            for _ in 0..<3 {
                let result = await send(command)
                guard result == .notReady else { return report(result) }
                await sleep(.milliseconds(500))
            }
        }
    }

    func launchInBackground() async -> Bool {
        if isRunning() { return true }
        guard await launch() else { return false }
        for _ in 0..<40 {
            await sleep(.milliseconds(250))
            if isRunning() { return true }
        }
        Logger.app.error("Spotify did not finish launching in time")
        return false
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) != nil
    }

    func automationStatus(askingIfNeeded: Bool) async -> AutomationStatus? {
        await Self.determineAutomation(askingIfNeeded: askingIfNeeded)
    }

    private func report(_ result: SendResult) {
        if result == .denied { onDenied() }
    }

    // MARK: - System side effects

    nonisolated static func isSpotifyRunning() -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.isFinishedLaunching && !$0.isTerminated }
    }

    nonisolated static func openSpotify() async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            Logger.app.notice("Spotify is not installed")
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return true
        } catch {
            Logger.app.error("Could not open Spotify: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Waits for Spotify's reply (and possibly a consent prompt), so it runs off the main actor.
    @concurrent
    nonisolated static func sendAppleEvent(_ command: SpotifyCommand) async -> SendResult {
        let event = NSAppleEventDescriptor(
            eventClass: fourCharCode("spfy"),
            eventID: command.eventID,
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: bundleID),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            try event.sendEvent(options: .defaultOptions, timeout: 5)
            return .sent
        } catch {
            Logger.app.error("Spotify did not accept \(String(describing: command), privacy: .public): \(error.localizedDescription, privacy: .public)")
            switch (error as NSError).code {
            case procNotFound, connectionInvalid: return .notReady // -600, -609
            case errAEEventNotPermitted: return .denied             // -1743
            default: return .failed
            }
        }
    }

    /// Asking can block until the person answers the consent prompt, so this runs off the main actor.
    /// macOS can only answer while Spotify is running; otherwise this returns nil.
    @concurrent
    nonisolated static func determineAutomation(askingIfNeeded: Bool) async -> AutomationStatus? {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        // `aeDesc` points into `target`, so keep `target` alive until macOS has read it.
        let result = withExtendedLifetime(target) { () -> OSStatus? in
            guard let desc = target.aeDesc else { return nil }
            return AEDeterminePermissionToAutomateTarget(
                desc, AEEventClass(typeWildCard), AEEventID(typeWildCard), askingIfNeeded
            )
        }
        switch result.map(Int.init) {
        case Int(noErr): return .granted
        case errAEEventNotPermitted: return .denied               // -1743
        case errAEEventWouldRequireUserConsent: return .notDetermined // -1744
        default: return nil                                       // procNotFound (-600): not running
        }
    }
}

nonisolated func fourCharCode(_ code: StaticString) -> FourCharCode {
    code.withUTF8Buffer { $0.reduce(0) { $0 << 8 | FourCharCode($1) } }
}
