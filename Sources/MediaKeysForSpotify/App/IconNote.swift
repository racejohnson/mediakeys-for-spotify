import AppKit
import os

/// `--icon-note <file>`: writes the app icon's note layer, an SVG on the icon's 1024 × 1024
/// artboard, from the menu bar glyph's path. The note is drawn once, in `MenuBarGlyph`,
/// so the icon and the menu bar cannot drift apart.
enum IconNote {
    /// The note's green, a little brighter at the beam than at the heads.
    private static let top = "#2BE06C", bottom = "#19C457"

    static func write(to url: URL) -> Bool {
        var data = ""
        func number(_ value: CGFloat) -> String { String(format: "%.2f", value) }
        func point(_ point: CGPoint) -> String { "\(number(point.x)),\(number(point.y))" }
        MenuBarGlyph.glyphPath().applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: data += "M\(point(points[0])) "
            case .addLineToPoint: data += "L\(point(points[0])) "
            case .addQuadCurveToPoint: data += "Q\(point(points[0])) \(point(points[1])) "
            case .addCurveToPoint: data += "C\(point(points[0])) \(point(points[1])) \(point(points[2])) "
            case .closeSubpath: data += "Z"
            @unknown default: break
            }
        }
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\
        <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="\(top)"/><stop offset="1" stop-color="\(bottom)"/></linearGradient></defs>\
        <path fill="url(#g)" d="\(data)"/></svg>

        """
        do {
            try svg.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            Logger.app.error("Could not write \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
