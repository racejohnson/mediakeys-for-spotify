import AppKit
import Foundation

final class MediaKeyInterceptor {
    private let systemDefinedEventRawValue: UInt32 = 14
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let isEnabledProvider: () -> Bool
    private let onCommand: (MediaKeyCommand) -> Void

    init(
        isEnabledProvider: @escaping () -> Bool,
        onCommand: @escaping (MediaKeyCommand) -> Void
    ) {
        self.isEnabledProvider = isEnabledProvider
        self.onCommand = onCommand
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let eventMask = (1 << systemDefinedEventRawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            return interceptor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handleEvent(
        proxy _: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        default:
            if type.rawValue != systemDefinedEventRawValue {
                return Unmanaged.passUnretained(event)
            }
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == MediaKeyDecoder.systemDefinedSubtype,
              let command = MediaKeyDecoder.decode(data1: nsEvent.data1)
        else {
            return Unmanaged.passUnretained(event)
        }

        guard isEnabledProvider() else {
            return Unmanaged.passUnretained(event)
        }

        onCommand(command)
        return nil
    }
}
