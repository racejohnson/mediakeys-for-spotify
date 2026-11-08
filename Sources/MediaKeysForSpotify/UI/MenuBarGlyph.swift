import AppKit

/// The menu bar icon: a template image, so macOS tints it for light, dark and tinted menu bars.
enum MenuBarGlyph {
    static let image = makeImage(badged: false)
    /// The glyph with a dot in its bottom-right corner, for "needs setup".
    static let badgedImage = makeImage(badged: true)

    private static func makeImage(badged: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let path = MenuBarGlyph.glyphPath()
            let bounds = path.boundingBoxOfPath
            // 15.3 pt tall: this puts the two stems exactly 8 pt apart, so both land on whole pixels at 1x.
            let inset: CGFloat = 1.34
            let scale = min((rect.width - 2 * inset) / bounds.width, (rect.height - 2 * inset) / bounds.height)
            context.setFillColor(.black)
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            if badged {
                // A clear ring keeps the dot apart from the beam, then the dot itself.
                let dot = CGPoint(x: 15.5, y: 15.5)
                context.setBlendMode(.clear)
                context.fillEllipse(in: CGRect(x: dot.x - 3.75, y: dot.y - 3.75, width: 7.5, height: 7.5))
                context.setBlendMode(.normal)
                context.fillEllipse(in: CGRect(x: dot.x - 2.5, y: dot.y - 2.5, width: 5, height: 5))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MediaKeys for Spotify"
        return image
    }

    // MARK: - Glyph path
    // Mirrors Packaging/AppIcon.icon/Assets/note.svg (the same numbers); change both together.

    /// The app icon's beamed eighth-note pair, in its 1024 × 1024 artboard (y down).
    /// Two tilted elliptical heads, two stems and an arched beam, with filleted corners.
    /// Any closed path works: the image fits its bounding box into 18 × 18 pt.
    nonisolated static func glyphPath() -> CGPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }
        let path = CGMutablePath()

        /// A rounded corner: part of a circle, swept from one angle to the other (degrees, y down).
        func fillet(_ center: CGPoint, _ radius: CGFloat, from start: CGFloat, to end: CGFloat) {
            path.addArc(center: center, radius: radius, startAngle: radians(start), endAngle: radians(end), clockwise: end < start)
        }
        /// A note head: an ellipse 222 × 158 tilted 21° anticlockwise, swept clockwise on screen.
        func head(_ center: CGPoint, from start: CGFloat, to end: CGFloat) {
            let ellipse = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians(-21))
                .scaledBy(x: 111.07, y: 78.76)
            path.addArc(center: .zero, radius: 1, startAngle: radians(start), endAngle: radians(end), clockwise: false, transform: ellipse)
        }

        // Left stem top, up along the arched beam to the right stem.
        path.move(to: p(384.72, 300.54))
        fillet(p(406.93, 300.54), 22.21, from: -180, to: -110.86)
        path.addQuadCurve(to: p(735.85, 213.15), control: p(567.43, 215.28))
        fillet(p(736.12, 235.36), 22.21, from: -90.7, to: 0)
        // Right stem down, around its head, back up the stem's inner edge.
        path.addLine(to: p(758.33, 631.81))
        head(p(650.86, 650.90), from: 15.23, to: 297.48)
        fillet(p(673.51, 553.16), 14.14, from: 89.31, to: 0)
        path.addLine(to: p(687.65, 349.41))
        // Under the beam, right to left.
        fillet(p(673.51, 349.41), 14.14, from: 0, to: -94.62)
        path.addQuadCurve(to: p(465.34, 375.95), control: p(568.86, 343.85))
        fillet(p(469.54, 389.45), 14.14, from: -107.28, to: -180)
        // Left stem down, around its head, and home.
        path.addLine(to: p(455.40, 690.37))
        head(p(347.93, 709.47), from: 15.22, to: 297.49)
        fillet(p(370.58, 611.73), 14.14, from: 89.27, to: 0)
        path.closeSubpath()
        return path
    }
}
