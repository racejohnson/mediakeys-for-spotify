import AppKit
import os

protocol MediaKeyTapping: AnyObject {
    var isRunning: Bool { get }
    func start() -> Bool
    func stop()
}

/// An active event tap that takes play, next and previous away from every other app.
///
/// The tap sits in the system's event stream, so its callback must return at once:
/// it only decides whether to swallow the event and hands the press to `onPress` later.
final class MediaKeyTap: MediaKeyTapping {
    private let onPress: (MediaKey) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(onPress: @escaping (MediaKey) -> Void) {
        self.onPress = onPress
    }

    /// False once macOS has disabled the tap, for example after Accessibility was turned off.
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Fails while the app lacks Accessibility access.
    func start() -> Bool {
        if isRunning { return true }
        stop() // A tap macOS disabled is dead; replace it.

        // Lives for the app's lifetime, so an unretained pointer is safe here.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << NSEvent.EventType.systemDefined.rawValue,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.app.error("Could not create the media key event tap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
    }

    /// Returns true when the event is ours and must not reach any other app.
    fileprivate func shouldSwallow(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Logger.app.notice("Media key tap was disabled by the system; re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              let keyEvent = MediaKeyEvent(subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1)
        else { return false }

        if let key = keyEvent.press {
            Task { onPress(key) }
        }
        return true
    }
}

/// The tap's run loop source is on the main run loop, so this always runs on the main thread.
private nonisolated func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Already on the main thread, so handing these to the main actor cannot race.
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo)
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated {
        tap.takeUnretainedValue().shouldSwallow(type, event)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
