/// The keyboard media keys MediaKeys handles.
nonisolated enum MediaKey: Equatable, Sendable {
    case playPause, next, previous
}

/// One phase of a media key press, decoded from an `NX_SYSDEFINED` event.
nonisolated struct MediaKeyEvent: Equatable, Sendable {
    let key: MediaKey
    let isDown: Bool
    let isRepeat: Bool

    /// Returns nil for anything that is not a play, next or previous key.
    init?(subtype: Int, data1: Int) {
        // NX_SUBTYPE_AUX_CONTROL_BUTTONS: media and other auxiliary keys.
        guard subtype == 8 else { return nil }

        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let keyState = (data1 & 0xFF00) >> 8

        // Key codes from IOKit/hidsystem/ev_keymap.h. Some keyboards send FAST and
        // REWIND instead of NEXT and PREVIOUS.
        switch keyCode {
        case 16: key = .playPause   // NX_KEYTYPE_PLAY
        case 17, 19: key = .next    // NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST
        case 18, 20: key = .previous // NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND
        default: return nil
        }

        switch keyState {
        case 0xA: isDown = true
        case 0xB: isDown = false
        default: return nil
        }

        isRepeat = data1 & 0x1 != 0
    }

    /// The tap swallows every phase (down, up, repeat) so no other app sees half a press,
    /// but acts only on this: the first key-down of each physical press.
    var press: MediaKey? {
        isDown && !isRepeat ? key : nil
    }
}
