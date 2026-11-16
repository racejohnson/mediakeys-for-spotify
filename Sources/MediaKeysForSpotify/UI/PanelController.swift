import AppKit
import SwiftUI

/// A Control Center–style glass panel that hangs under the status item.
/// From DayNight, by the same author.
final class PanelController {
    var onVisibilityChange: ((Bool) -> Void)?

    private let model: AppModel
    private let panel = FloatingPanel()
    private let content: SizeReportingHostingView<PanelView>
    private var anchor: NSRect = .zero
    private var screen: NSScreen?
    /// The status item the panel hangs from; nil when it was shown without one.
    private weak var button: NSStatusBarButton?
    private var monitors: [Any] = []
    private var observers: [(NotificationCenter, any NSObjectProtocol)] = []
    /// When the panel last closed, in system uptime.
    private var closedAt: TimeInterval = 0

    private static let cornerRadius: CGFloat = 22
    private static let gapBelowMenuBar: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    init(model: AppModel) {
        self.model = model
        content = SizeReportingHostingView(rootView: PanelView(model: model))
        content.sizingOptions = [.intrinsicContentSize]

        let glass = NSGlassEffectView()
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = content
        panel.contentView = RoundedClipView(content: glass, cornerRadius: Self.cornerRadius)

        content.onSizeChange = { [weak self] in self?.fit() }
        panel.onCancel = { [weak self] in self?.close() }
    }

    var isVisible: Bool { panel.isVisible }

    /// A click on the status item while the panel is open closes it. On
    /// macOS 26 and later that click can also reach the outside-click monitor,
    /// which closes the panel a moment before this runs; without the check the
    /// same click would then open it again.
    func toggle(below button: NSStatusBarButton) {
        if isVisible {
            close()
        } else if ProcessInfo.processInfo.systemUptime - closedAt > 0.25 {
            show(below: button)
        }
    }

    /// `takingFocus` is false when nobody clicked to open the panel (at launch): it must
    /// not take the keyboard from whatever the person is typing in. A click inside it does.
    func show(below button: NSStatusBarButton, takingFocus: Bool = true) {
        guard let window = button.window, let screen = window.screen else { return }
        self.button = button
        show(anchoredAt: window.convertToScreen(button.convert(button.bounds, to: nil)), on: screen, takingFocus: takingFocus)
    }

    /// Shows the panel under `anchor`, a rectangle in screen coordinates.
    func show(anchoredAt anchor: NSRect, on screen: NSScreen, takingFocus: Bool = true) {
        self.anchor = anchor
        self.screen = screen
        model.isPanelVisible = true
        Task { await model.refresh() }
        fit()

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        if takingFocus {
            panel.makeKey()
            // Nothing starts out focused: otherwise the first row, or the one
            // clicked last time, opens looking hovered. Tab still moves in.
            panel.makeFirstResponder(nil)
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        refreshShadow()
        startMonitoring()
        onVisibilityChange?(true)
    }

    func close() {
        guard panel.isVisible else { return }
        stopMonitoring()
        panel.orderOut(nil)
        button = nil
        closedAt = ProcessInfo.processInfo.systemUptime
        model.isPanelVisible = false
        onVisibilityChange?(false)
    }

    /// A click elsewhere, or another app coming forward, closes the panel. Not while a
    /// permission is missing: allowing one means working in System Settings or answering
    /// a prompt, and the panel is what says what is left. Esc and the status item still close it.
    private func closeForOutsideActivity() {
        guard !model.needsPermission else { return }
        close()
    }

    /// A display change can leave the anchor on a screen that moved or is gone. Outside
    /// setup that closes the panel, as in the sibling apps. During setup it stays open
    /// and moves back under the status item.
    private func screenParametersChanged() {
        guard model.needsPermission else { return close() }
        // The status item's window moves after this notification arrives.
        DispatchQueue.main.async { [weak self] in
            guard let self, panel.isVisible else { return }
            guard let button, let window = button.window, let screen = window.screen else { return close() }
            anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
            self.screen = screen
            fit()
        }
    }

    /// Sizes the panel to its content, centred under the status item and kept
    /// inside the visible frame of that item's screen.
    private func fit() {
        guard let screen else { return }
        let size = content.fittingSize
        let visible = screen.visibleFrame
        let x = min(
            max(anchor.midX - size.width / 2, visible.minX + Self.screenMargin),
            visible.maxX - Self.screenMargin - size.width
        )
        let top = min(anchor.minY, visible.maxY) - Self.gapBelowMenuBar
        let frame = NSRect(x: x, y: top - size.height, width: size.width, height: size.height)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        refreshShadow()
    }

    /// The window server traces the shadow and edge from what the window has
    /// drawn, so recompute it once the glass has rendered at its new size.
    private func refreshShadow() {
        DispatchQueue.main.async { [panel] in panel.invalidateShadow() }
    }

    private func startMonitoring() {
        // A click anywhere outside this app. A click on our own status item
        // may or may not arrive here; `toggle` handles both.
        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in MainActor.assumeIsolated { self?.closeForOutsideActivity() } }
        ) {
            monitors.append(monitor)
        }
        observe(NSApplication.didResignActiveNotification, on: .default)
        observe(NSWorkspace.didActivateApplicationNotification, on: NSWorkspace.shared.notificationCenter)
        let center = NotificationCenter.default
        let observer = center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }
        observers.append((center, observer))
    }

    private func stopMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    private func observe(_ name: Notification.Name, on center: NotificationCenter) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let isSelf = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            MainActor.assumeIsolated {
                if !isSelf { self?.closeForOutsideActivity() }
            }
        }
        observers.append((center, observer))
    }
}

/// A borderless panel that takes key focus (for Esc, ⌘Q and Tab)
/// without activating the app.
private final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Caps Lock is a modifier flag too, and must not stop ⌘Q.
        if event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Clips the window to the panel's rounded shape, so its corners are truly
/// transparent and the window's shadow and edge follow the curve.
private final class RoundedClipView: NSView {
    init(content: NSView, cornerRadius: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// Reports SwiftUI content-size changes so the panel can refit while open.
private final class SizeReportingHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // Refit after the current layout pass, not in the middle of it.
        Task { [weak self] in self?.onSizeChange?() }
    }
}
