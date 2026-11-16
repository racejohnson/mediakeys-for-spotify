import AppKit
import SwiftUI
import os

/// `--readme <folder>`: the README's picture of the panel, drawn off screen from made-up
/// state so it comes out the same on any Mac. Nothing real is read, asked or changed:
/// the models here run on stand-ins and a throwaway defaults suite.
enum ReadmePictures {
    private struct Shot {
        var panel: CGImage
        var size: CGSize
        var item: NSImage
        var itemAlpha: CGFloat
        var isDark: Bool
    }

    static func write(to folder: URL) {
        Task {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var shots: [Shot] = []
            // 1. On, with Spotify open.
            if let shot = await shoot(dark: false) { shots.append(shot) }
            // 2. First launch: both permissions still to allow.
            if let shot = await shoot(isAllowed: false, dark: false) { shots.append(shot) }
            // 3. Off, with Spotify closed, in dark mode.
            if let shot = await shoot(isEnabled: false, isSpotifyOpen: false, dark: true) { shots.append(shot) }

            let url = folder.appendingPathComponent("panel.png")
            if let tiff = hero(shots).tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               (try? rep.representation(using: .png, properties: [:])?.write(to: url)) != nil {
                Logger.app.notice("Wrote \(url.path, privacy: .public)")
            } else {
                Logger.app.error("Could not write \(url.path, privacy: .public)")
            }
            NSApp.terminate(nil)
        }
    }

    private static func shoot(isEnabled: Bool = true, isAllowed: Bool = true, isSpotifyOpen: Bool = true, dark: Bool) async -> Shot? {
        let suite = "ReadmePictures-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return nil }
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(
            defaults: defaults,
            tap: DemoTap(),
            spotify: DemoSpotify(isRunning: isSpotifyOpen, status: isAllowed ? .granted : .notDetermined),
            accessibility: DemoAccessibility(isTrusted: isAllowed),
            loginItem: DemoLoginItem(),
            openSettings: { _ in }
        )
        model.isEnabled = isEnabled
        await model.refresh()

        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let view = PanelView(model: model)
            .background(Color(nsColor: backdrop(dark: dark)))
            .environment(\.colorScheme, dark ? .dark : .light)
            // System switches draw grey in a window that is not on screen.
            .environment(\.drawsSwitchesForPictures, true)
        let host = NSHostingView(rootView: view)
        host.appearance = appearance
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let image = rep.cgImage else { return nil }
        return Shot(
            panel: image, size: rep.size,
            item: model.status == .needsSetup ? MenuBarGlyph.badgedImage : MenuBarGlyph.image,
            itemAlpha: model.status == .paused ? 0.35 : 1, isDark: dark
        )
    }

    /// A flat stand-in for the glass.
    private static func backdrop(dark: Bool) -> NSColor {
        dark ? NSColor(white: 0.14, alpha: 1) : NSColor(white: 0.95, alpha: 1)
    }

    /// The panels side by side, each under a strip of menu bar with the note pressed.
    private static func hero(_ shots: [Shot]) -> NSImage {
        let panelWidth: CGFloat = 312, gap: CGFloat = 44, margin: CGFloat = 40
        let barHeight: CGFloat = 30, barGap: CGFloat = 7, radius: CGFloat = 22
        let tallest = shots.map(\.size.height).max() ?? 0
        let width = margin * 2 + CGFloat(shots.count) * panelWidth + CGFloat(max(shots.count - 1, 0)) * gap
        let height = margin * 0.6 + barHeight + barGap + tallest + margin * 1.4
        return draw(width: width, height: height) { context in
            for (index, shot) in shots.enumerated() {
                let left = margin + CGFloat(index) * (panelWidth + gap)
                let top = height - margin * 0.6

                // The menu bar: black, fading out to either side, with the item pressed.
                let bar = CGRect(x: left - 6, y: top - barHeight, width: panelWidth + 12, height: barHeight)
                context.saveGState()
                context.clip(to: bar)
                if let fade = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [0, 1, 1, 0].map { CGColor(gray: 0, alpha: $0) } as CFArray, locations: [0, 0.3, 0.7, 1]
                ) {
                    context.drawLinearGradient(fade, start: CGPoint(x: bar.minX, y: 0), end: CGPoint(x: bar.maxX, y: 0), options: [])
                }
                context.restoreGState()
                let item = shot.item.size
                context.setFillColor(CGColor(gray: 1, alpha: 0.18))
                context.addPath(CGPath(
                    roundedRect: CGRect(x: bar.midX - item.width / 2 - 6, y: bar.midY - 12, width: item.width + 12, height: 24),
                    cornerWidth: 7, cornerHeight: 7, transform: nil
                ))
                context.fillPath()
                // A template image is one ink: draw it, then tint what was drawn.
                let itemRect = CGRect(x: bar.midX - item.width / 2, y: bar.midY - item.height / 2, width: item.width, height: item.height)
                context.saveGState()
                context.setAlpha(shot.itemAlpha)
                context.beginTransparencyLayer(in: itemRect, auxiliaryInfo: nil)
                shot.item.draw(in: itemRect)
                context.setBlendMode(.sourceIn)
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fill(itemRect)
                context.endTransparencyLayer()
                context.restoreGState()

                // The panel: rounded, with its shadow and a hairline edge.
                let frame = CGRect(x: left, y: bar.minY - barGap - shot.size.height, width: panelWidth, height: shot.size.height)
                let shape = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(gray: 0, alpha: 0.22))
                context.setFillColor(backdrop(dark: shot.isDark).cgColor)
                context.addPath(shape)
                context.fillPath()
                context.restoreGState()
                context.saveGState()
                context.addPath(shape)
                context.clip()
                context.draw(shot.panel, in: frame)
                context.restoreGState()
                context.setStrokeColor(CGColor(gray: shot.isDark ? 1 : 0, alpha: shot.isDark ? 0.16 : 0.12))
                context.setLineWidth(0.5)
                context.addPath(CGPath(roundedRect: frame.insetBy(dx: 0.25, dy: 0.25), cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.strokePath()
            }
        }
    }

    /// Draws into a 2× bitmap, in points.
    private static func draw(width: CGFloat, height: CGFloat, _ body: (CGContext) -> Void) -> NSImage {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int((width * 2).rounded(.up)), pixelsHigh: Int((height * 2).rounded(.up)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return image }
        // Set before the context is made, so drawing is in points, not pixels.
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        body(context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        return image
    }
}

// MARK: - Stand-ins

private final class DemoTap: MediaKeyTapping {
    private(set) var isRunning = false

    func start() -> Bool {
        isRunning = true
        return true
    }

    func stop() { isRunning = false }
}

private final class DemoSpotify: SpotifyControlling {
    let isInstalled = true
    let isRunning: Bool
    let status: AutomationStatus

    init(isRunning: Bool, status: AutomationStatus) {
        self.isRunning = isRunning
        self.status = status
    }

    func automationStatus(askingIfNeeded: Bool) async -> AutomationStatus? { status }
    func launchInBackground() async -> Bool { false }
}

private struct DemoAccessibility: AccessibilityChecking {
    let isTrusted: Bool
    func prompt() {}
}

private struct DemoLoginItem: LoginItemManaging {
    let isEnabled = true
    let needsApproval = false
    func setEnabled(_ enabled: Bool) {}
    func openSystemSettings() {}
}
