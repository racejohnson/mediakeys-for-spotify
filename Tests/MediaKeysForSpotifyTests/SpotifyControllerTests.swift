import XCTest
@testable import MediaKeysForSpotify

final class SpotifyControllerTests: XCTestCase {
    func testHandleDispatchesWhenSpotifyAlreadyRunning() {
        var launched = false
        var executed: [MediaKeyCommand] = []

        let controller = SpotifyController(
            startupTimeout: 0.0,
            isSpotifyRunning: { true },
            launchSpotify: { launched = true },
            executeAppleScript: { command in
                executed.append(command)
                return true
            },
            sleepStep: { _ in }
        )

        let result = controller.handle(.nextTrack)

        XCTAssertTrue(result)
        XCTAssertFalse(launched)
        XCTAssertEqual(executed, [.nextTrack])
    }

    func testHandleLaunchesThenDispatchesWhenSpotifyStarts() {
        var running = false
        var launched = false
        var executed: [MediaKeyCommand] = []
        var sleepTicks = 0

        let controller = SpotifyController(
            startupTimeout: 1.0,
            isSpotifyRunning: { running },
            launchSpotify: {
                launched = true
            },
            executeAppleScript: { command in
                executed.append(command)
                return true
            },
            sleepStep: { _ in
                sleepTicks += 1
                if sleepTicks >= 1 {
                    running = true
                }
            }
        )

        let result = controller.handle(.playPause)

        XCTAssertTrue(result)
        XCTAssertTrue(launched)
        XCTAssertEqual(executed, [.playPause])
    }

    func testHandleFailsIfSpotifyNeverStarts() {
        var launched = false
        var executedCount = 0

        let controller = SpotifyController(
            startupTimeout: 0.0,
            isSpotifyRunning: { false },
            launchSpotify: { launched = true },
            executeAppleScript: { _ in
                executedCount += 1
                return true
            },
            sleepStep: { _ in }
        )

        let result = controller.handle(.previousTrack)

        XCTAssertFalse(result)
        XCTAssertTrue(launched)
        XCTAssertEqual(executedCount, 0)
    }
}
