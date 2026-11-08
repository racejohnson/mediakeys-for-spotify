import Testing
@testable import MediaKeysForSpotify

struct MediaKeyEventTests {
    private func data1(code: Int, state: Int, isRepeat: Bool = false) -> Int {
        code << 16 | state << 8 | (isRepeat ? 1 : 0)
    }

    @Test(arguments: [
        (16, MediaKey.playPause),
        (17, .next), (19, .next),
        (18, .previous), (20, .previous),
    ])
    func decodesKeyDown(code: Int, key: MediaKey) {
        let event = MediaKeyEvent(subtype: 8, data1: data1(code: code, state: 0xA))
        #expect(event?.key == key)
        #expect(event?.isDown == true)
        #expect(event?.isRepeat == false)
    }

    @Test func decodesKeyUp() {
        let event = MediaKeyEvent(subtype: 8, data1: data1(code: 16, state: 0xB))
        #expect(event?.isDown == false)
    }

    @Test func decodesRepeat() {
        let event = MediaKeyEvent(subtype: 8, data1: data1(code: 17, state: 0xA, isRepeat: true))
        #expect(event?.isRepeat == true)
    }

    /// The tap swallows every decoded event but acts only on the first key-down of a press.
    @Test func onlyFirstKeyDownPresses() {
        let down = MediaKeyEvent(subtype: 8, data1: data1(code: 19, state: 0xA))
        let up = MediaKeyEvent(subtype: 8, data1: data1(code: 19, state: 0xB))
        let held = MediaKeyEvent(subtype: 8, data1: data1(code: 19, state: 0xA, isRepeat: true))
        #expect(down?.press == .next)
        #expect(up != nil && up?.press == nil)
        #expect(held != nil && held?.press == nil)
    }

    @Test func ignoresUnknownKeys() {
        // 0 is NX_KEYTYPE_SOUND_UP: volume keys must pass through.
        #expect(MediaKeyEvent(subtype: 8, data1: data1(code: 0, state: 0xA)) == nil)
        #expect(MediaKeyEvent(subtype: 8, data1: data1(code: 42, state: 0xA)) == nil)
    }

    @Test func ignoresUnknownState() {
        #expect(MediaKeyEvent(subtype: 8, data1: data1(code: 16, state: 0x3)) == nil)
    }

    @Test func ignoresOtherSubtypes() {
        #expect(MediaKeyEvent(subtype: 7, data1: data1(code: 16, state: 0xA)) == nil)
    }
}

