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
            // Sized so the stems' left edges are exactly 7 pt apart (15.7 pt tall), then moved sideways by a
            // fraction of a point so both stems, each about 1 pt wide, land on whole pixels at 1x.
            let scale = 7 / (Note.stemRight - Note.stemWidth - Note.stemLeft)
            var originX = rect.midX - bounds.midX * scale
            let stem = originX + Note.stemLeft * scale
            originX += stem.rounded() - stem
            // With the dot, the note moves a point up and left, so the dot only nicks the right head instead of replacing it.
            let shift: CGFloat = badged ? -1 : 0
            context.setFillColor(.black)
            context.saveGState()
            context.translateBy(x: originX + shift, y: rect.midY - bounds.midY * scale + shift)
            context.scaleBy(x: scale, y: scale)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            if badged {
                // A clear ring keeps the dot apart from the note, then the dot itself.
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

    // MARK: - The note
    // The one drawing of the note. The app icon's layer, Packaging/AppIcon.icon/Assets/note.svg,
    // is written from this path by scripts/icon.sh; never edit that file by hand.

    /// The note's measurements on the app icon's 1024 × 1024 artboard (y down): where it sits
    /// on the icon as well as its shape. A beamed pair of eighth notes after the one on Apple's
    /// Music icon, fitted to it to within 1% of its area.
    nonisolated private enum Note {
        /// The left edge of the left stem, each stem's width, and the right edge of the right stem.
        static let stemLeft: CGFloat = 391.4
        static let stemWidth: CGFloat = 43.9
        static let stemRight: CGFloat = 750.4
        /// The straight beam: its top edge at the two outer stem edges, its lower edge at the two inner ones.
        static let beamTop: (left: CGFloat, right: CGFloat) = (262.7, 137.9)
        static let beamUnder: (left: CGFloat, right: CGFloat) = (422.8, 328.5)
        /// Each head is an ellipse with these radii, tipped up to the right, hanging from its stem.
        static let headRadii = CGSize(width: 109.8, height: 79.5)
        static let headTilt: CGFloat = -32.8 * .pi / 180
        static let headCentreY: (left: CGFloat, right: CGFloat) = (752.4, 643.0)
        /// Corner radii: the beam's two top corners, the two under it, and where a head meets its stem.
        static let outerRadius: CGFloat = 19.3
        static let innerRadius: CGFloat = 11.7
        static let headRadius: CGFloat = 20.6
    }

    /// A head, placed so the right edge of its stem (`outer`) runs tangent into it.
    private nonisolated struct Head {
        /// Where the outline leaves the stem's right edge and joins the ellipse.
        let tangent: CGPoint
        let centre: CGPoint
        /// The ellipse's own angles between that point and where the fillet takes over.
        let from: CGFloat, to: CGFloat
        /// The fillet back up to the stem's left edge (`inner`): its centre, and the angle it starts at. It ends at 0.
        let fillet: CGPoint
        let filletFrom: CGFloat

        init(inner: CGFloat, outer: CGFloat, centreY: CGFloat) {
            let rx = Note.headRadii.width, ry = Note.headRadii.height, tilt = Note.headTilt
            // The angle at which the tilted ellipse reaches furthest right, and how far that is.
            let rightmost = atan2(-ry * sin(tilt), rx * cos(tilt))
            let centre = CGPoint(x: outer - hypot(rx * cos(tilt), ry * sin(tilt)), y: centreY)
            func point(_ t: CGFloat) -> CGPoint {
                CGPoint(x: centre.x + rx * cos(t) * cos(tilt) - ry * sin(t) * sin(tilt),
                        y: centre.y + rx * cos(t) * sin(tilt) + ry * sin(t) * cos(tilt))
            }
            func normal(_ t: CGFloat) -> CGPoint {
                let x = cos(t) / rx * cos(tilt) - sin(t) / ry * sin(tilt), y = cos(t) / rx * sin(tilt) + sin(t) / ry * cos(tilt)
                return CGPoint(x: x / hypot(x, y), y: y / hypot(x, y))
            }
            // The fillet's centre is one radius left of the stem's left edge and one radius off the ellipse.
            // Walking over the top of the head from its left side, find where both hold.
            var low = CGFloat.pi, high = 2 * CGFloat.pi + rightmost
            for _ in 0..<60 {
                let mid = (low + high) / 2
                if point(mid).x + Note.headRadius * normal(mid).x < inner - Note.headRadius { low = mid } else { high = mid }
            }
            let join = (low + high) / 2, on = point(join), out = normal(join)
            self.centre = centre
            tangent = point(rightmost)
            from = rightmost
            to = join
            fillet = CGPoint(x: on.x + Note.headRadius * out.x, y: on.y + Note.headRadius * out.y)
            filletFrom = atan2(on.y - fillet.y, on.x - fillet.x)
        }

        /// Down the stem's right edge, round the head, and back to the stem's left edge.
        func add(to path: CGMutablePath) {
            path.addLine(to: tangent)
            let ellipse = CGAffineTransform(translationX: centre.x, y: centre.y)
                .rotated(by: Note.headTilt)
                .scaledBy(x: Note.headRadii.width, y: Note.headRadii.height)
            path.addArc(center: .zero, radius: 1, startAngle: from, endAngle: to, clockwise: false, transform: ellipse)
            path.addArc(center: fillet, radius: Note.headRadius, startAngle: filletFrom, endAngle: 0, clockwise: true)
        }
    }

    /// The note's outline, on the icon's artboard: two stems, a straight beam and two tilted heads,
    /// with every corner filleted.
    nonisolated static func glyphPath() -> CGPath {
        let leftInner = Note.stemLeft + Note.stemWidth, rightInner = Note.stemRight - Note.stemWidth
        let left = Head(inner: Note.stemLeft, outer: leftInner, centreY: Note.headCentreY.left)
        let right = Head(inner: rightInner, outer: Note.stemRight, centreY: Note.headCentreY.right)
        let path = CGMutablePath()

        // Up the left stem, along the top of the beam, down the right stem and round its head.
        path.move(to: CGPoint(x: Note.stemLeft, y: left.fillet.y))
        path.addArc(
            tangent1End: CGPoint(x: Note.stemLeft, y: Note.beamTop.left),
            tangent2End: CGPoint(x: Note.stemRight, y: Note.beamTop.right), radius: Note.outerRadius
        )
        path.addArc(tangent1End: CGPoint(x: Note.stemRight, y: Note.beamTop.right), tangent2End: right.tangent, radius: Note.outerRadius)
        right.add(to: path)
        // Up the right stem's inner edge, back under the beam, down the left stem and round its head.
        path.addArc(
            tangent1End: CGPoint(x: rightInner, y: Note.beamUnder.right),
            tangent2End: CGPoint(x: leftInner, y: Note.beamUnder.left), radius: Note.innerRadius
        )
        path.addArc(tangent1End: CGPoint(x: leftInner, y: Note.beamUnder.left), tangent2End: left.tangent, radius: Note.innerRadius)
        left.add(to: path)
        path.closeSubpath()
        return path
    }
}
