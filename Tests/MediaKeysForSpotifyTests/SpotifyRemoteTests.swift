import Testing
@testable import MediaKeysForSpotify

/// A pretend Spotify: closed or open, installed or not, with a record of what it was sent.
private final class FakeSpotify {
    var isRunning = false
    var isInstalled = true
    /// How many polls after launching until Spotify reports running; nil means never.
    var pollsUntilRunning: Int? = 2
    var launches = 0
    var sent: [SpotifyCommand] = []
    /// What each send returns, in order; `.sent` once these run out.
    var results: [SendResult] = []
    var denials = 0
    private var polls = 0

    func makeRemote() -> SpotifyRemote {
        let remote = SpotifyRemote(
            isRunning: { self.isRunning },
            launch: {
                guard self.isInstalled else { return false }
                self.launches += 1
                return true
            },
            send: { command in
                self.sent.append(command)
                return self.results.isEmpty ? .sent : self.results.removeFirst()
            },
            sleep: { _ in
                self.polls += 1
                if self.launches > 0, let limit = self.pollsUntilRunning, self.polls >= limit {
                    self.isRunning = true
                }
            }
        )
        remote.onDenied = { self.denials += 1 }
        return remote
    }
}

struct SpotifyRemoteTests {
    @Test(arguments: [
        (MediaKey.playPause, SpotifyCommand.playPause),
        (.next, .next),
        (.previous, .previous),
    ])
    func sendsToRunningSpotify(key: MediaKey, command: SpotifyCommand) async {
        let spotify = FakeSpotify()
        spotify.isRunning = true
        await spotify.makeRemote().handle(key).value
        #expect(spotify.sent == [command])
        #expect(spotify.launches == 0)
    }

    @Test func keepsOrderOfQuickPresses() async {
        let spotify = FakeSpotify()
        spotify.isRunning = true
        let remote = spotify.makeRemote()
        remote.handle(.next)
        remote.handle(.previous)
        await remote.handle(.playPause).value
        #expect(spotify.sent == [.next, .previous, .playPause])
    }

    @Test func launchesThenPlaysForPlayPause() async {
        let spotify = FakeSpotify()
        await spotify.makeRemote().handle(.playPause).value
        #expect(spotify.launches == 1)
        #expect(spotify.sent == [.play])
    }

    @Test func launchesThenSkipsForNext() async {
        let spotify = FakeSpotify()
        await spotify.makeRemote().handle(.next).value
        #expect(spotify.sent == [.next])
    }

    @Test func sendsNothingWhenSpotifyNeverStarts() async {
        let spotify = FakeSpotify()
        spotify.pollsUntilRunning = nil
        await spotify.makeRemote().handle(.playPause).value
        #expect(spotify.launches == 1)
        #expect(spotify.sent.isEmpty)
    }

    @Test func ignoresPressesWhileLaunching() async {
        let spotify = FakeSpotify()
        let remote = spotify.makeRemote()
        let first = remote.handle(.playPause)
        let second = remote.handle(.next)
        await first.value
        await second.value
        #expect(spotify.launches == 1)
        #expect(spotify.sent == [.play])
    }

    @Test func doesNothingWhenNotInstalled() async {
        let spotify = FakeSpotify()
        spotify.isInstalled = false
        await spotify.makeRemote().handle(.playPause).value
        #expect(spotify.launches == 0)
        #expect(spotify.sent.isEmpty)
    }

    @Test func retriesWhileSpotifyIsNotReady() async {
        let spotify = FakeSpotify()
        spotify.results = [.notReady, .notReady]
        await spotify.makeRemote().handle(.next).value
        #expect(spotify.sent == [.next, .next, .next])
    }

    @Test func neverResendsAfterOtherFailures() async {
        // A timeout may come after Spotify already skipped; sending again would skip twice.
        let spotify = FakeSpotify()
        spotify.results = [.failed]
        await spotify.makeRemote().handle(.next).value
        #expect(spotify.sent == [.next])
    }

    @Test(arguments: [true, false])
    func reportsDenial(spotifyWasRunning: Bool) async {
        let spotify = FakeSpotify()
        spotify.isRunning = spotifyWasRunning
        spotify.results = [.denied]
        await spotify.makeRemote().handle(.next).value
        #expect(spotify.sent == [.next])
        #expect(spotify.denials == 1)
    }

    @Test func eventIDsMatchSpotifysDictionary() {
        #expect(fourCharCode("spfy") == 0x7370_6679)
        #expect(SpotifyCommand.playPause.eventID == 0x506C_5073)
    }
}
