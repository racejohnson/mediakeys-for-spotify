import XCTest
@testable import MediaKeysForSpotifyV2

final class MediaKeyDecoderTests: XCTestCase {
    func testDecodePlayPauseOnKeyDown() {
        let data1 = makeData1(keyCode: MediaKeyDecoder.playPauseCode, keyState: MediaKeyDecoder.keyStateDown)
        XCTAssertEqual(MediaKeyDecoder.decode(data1: data1), .playPause)
    }

    func testDecodeNextOnKeyDown() {
        let data1 = makeData1(keyCode: MediaKeyDecoder.nextCode, keyState: MediaKeyDecoder.keyStateDown)
        XCTAssertEqual(MediaKeyDecoder.decode(data1: data1), .nextTrack)
    }

    func testDecodePreviousOnKeyDown() {
        let data1 = makeData1(keyCode: MediaKeyDecoder.previousCode, keyState: MediaKeyDecoder.keyStateDown)
        XCTAssertEqual(MediaKeyDecoder.decode(data1: data1), .previousTrack)
    }

    func testDecodeIgnoresKeyUpEvents() {
        let data1 = makeData1(keyCode: MediaKeyDecoder.playPauseCode, keyState: 0xB)
        XCTAssertNil(MediaKeyDecoder.decode(data1: data1))
    }

    func testDecodeIgnoresUnknownKeys() {
        let data1 = makeData1(keyCode: 42, keyState: MediaKeyDecoder.keyStateDown)
        XCTAssertNil(MediaKeyDecoder.decode(data1: data1))
    }

    private func makeData1(keyCode: Int, keyState: Int) -> Int {
        (keyCode << 16) | (keyState << 8)
    }
}
