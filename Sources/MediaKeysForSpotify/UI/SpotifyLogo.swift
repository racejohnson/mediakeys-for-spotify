import SwiftUI

/// Spotify's mark: a disc with three arcs cut out of it, drawn in code like the menu bar note.
/// It stands for Spotify in the panel's rows, in one ink, and nowhere else.
nonisolated struct SpotifyLogo: Shape {
    func path(in rect: CGRect) -> Path {
        // The mark's own 24-unit box, fitted into `rect`.
        let scale = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.midX + (x - 12) * scale, y: rect.midY + (y - 12) * scale)
        }
        var path = Path()
        path.move(to: p(12, 0))
        path.addCurve(to: p(0, 12), control1: p(5.4, 0), control2: p(0, 5.4))
        path.addCurve(to: p(12, 24), control1: p(0, 18.6), control2: p(5.4, 24))
        path.addCurve(to: p(24, 12), control1: p(18.6, 24), control2: p(24, 18.6))
        path.addCurve(to: p(12, 0), control1: p(24, 5.4), control2: p(18.66, 0))
        path.closeSubpath()
        path.move(to: p(17.521, 17.34))
        path.addCurve(to: p(16.5, 17.58), control1: p(17.281, 17.699), control2: p(16.861, 17.82))
        path.addCurve(to: p(5.939, 16.439), control1: p(13.68, 15.84), control2: p(10.14, 15.479))
        path.addCurve(to: p(5.04, 15.9), control1: p(5.521, 16.561), control2: p(5.16, 16.26))
        path.addCurve(to: p(5.58, 15), control1: p(4.92, 15.479), control2: p(5.22, 15.12))
        path.addCurve(to: p(17.22, 16.32), control1: p(10.14, 13.979), control2: p(14.1, 14.4))
        path.addCurve(to: p(17.521, 17.34), control1: p(17.64, 16.5), control2: p(17.699, 16.979))
        path.closeSubpath()
        path.move(to: p(18.961, 14.04))
        path.addCurve(to: p(17.699, 14.34), control1: p(18.66, 14.46), control2: p(18.12, 14.64))
        path.addCurve(to: p(5.76, 12.96), control1: p(14.46, 12.36), control2: p(9.54, 11.76))
        path.addCurve(to: p(4.62, 12.36), control1: p(5.281, 13.08), control2: p(4.74, 12.84))
        path.addCurve(to: p(5.22, 11.219), control1: p(4.5, 11.88), control2: p(4.74, 11.339))
        path.addCurve(to: p(18.72, 12.84), control1: p(9.6, 9.9), control2: p(15, 10.561))
        path.addCurve(to: p(18.961, 14.04), control1: p(19.081, 13.021), control2: p(19.26, 13.62))
        path.closeSubpath()
        path.move(to: p(19.081, 10.68))
        path.addCurve(to: p(5.16, 9.301), control1: p(15.24, 8.4), control2: p(8.82, 8.16))
        path.addCurve(to: p(3.78, 8.58), control1: p(4.56, 9.48), control2: p(3.96, 9.12))
        path.addCurve(to: p(4.5, 7.199), control1: p(3.6, 7.979), control2: p(3.96, 7.38))
        path.addCurve(to: p(20.221, 8.82), control1: p(8.76, 5.939), control2: p(15.78, 6.179))
        path.addCurve(to: p(20.64, 10.38), control1: p(20.76, 9.12), control2: p(20.94, 9.84))
        path.addCurve(to: p(19.081, 10.68), control1: p(20.341, 10.801), control2: p(19.62, 10.979))
        path.closeSubpath()
        return path
    }
}
