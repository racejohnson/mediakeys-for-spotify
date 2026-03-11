import Foundation

enum MediaKeyDecoder {
    static let systemDefinedSubtype = 8
    static let keyStateDown = 0xA

    // NX key types from IOKit/hidsystem/ev_keymap.h
    static let playPauseCode = 16
    static let nextCode = 17
    static let previousCode = 18

    static func decode(data1: Int) -> MediaKeyCommand? {
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8

        guard keyState == keyStateDown else {
            return nil
        }

        switch keyCode {
        case playPauseCode:
            return .playPause
        case nextCode:
            return .nextTrack
        case previousCode:
            return .previousTrack
        default:
            return nil
        }
    }
}
