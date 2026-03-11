import AppKit
import Foundation

enum MenuIconRenderer {
    private static let notePathData = """
    M395,91.239391 C282.065057,87.4852433 189.562302,129.127975 189.562302,129.127975 L189.49488,340.455486 C177.996086,335.892546 164.012798,334.810785 149.810388,338.261635 C119.190763,345.699161 99.1395094,371.35475 105.025435,395.574732 C110.911362,419.794714 140.502804,433.402657 171.119059,425.9685 C199.989088,418.955591 219.453772,395.743231 216.652394,372.817318 L216.652394,214.917327 C216.652394,214.917327 282.065057,192.055443 366.912064,186.323123 L366.912064,303.763242 C355.538001,299.40924 341.821029,298.421838 327.878193,301.808659 C297.258568,309.242815 277.207314,334.898404 283.09324,359.121756 C288.975795,383.341737 318.567238,396.94631 349.186864,389.512154 C375.922992,383.01822 394.59884,362.629896 394.989887,341.442888 L395,341.456368 L395,91.239391 Z
    """

    private static let spotifyGreen = NSColor(
        calibratedRed: 0.1137,
        green: 0.7254,
        blue: 0.3294,
        alpha: 1.0
    )

    static func makeEnabledIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage? {
        makeIcon(size: size, style: .enabled)
    }

    static func makeDisabledIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage? {
        makeIcon(size: size, style: .disabled)
    }

    private enum DrawStyle {
        case enabled
        case disabled
    }

    private static func makeIcon(size: NSSize, style: DrawStyle) -> NSImage? {
        guard let path = SVGPathParser.parse(pathData: notePathData) else {
            return nil
        }

        let scaleFactor: CGFloat = 2
        let pixelWidth = Int(size.width * scaleFactor)
        let pixelHeight = Int(size.height * scaleFactor)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = size

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let cg = context.cgContext
        cg.clear(CGRect(origin: .zero, size: size))
        cg.setAllowsAntialiasing(true)
        cg.setShouldAntialias(true)
        cg.interpolationQuality = .high

        let bounds = path.boundingBoxOfPath
        let inset: CGFloat = 0.9
        let target = CGRect(
            x: inset,
            y: inset,
            width: size.width - (inset * 2),
            height: size.height - (inset * 2)
        )

        let drawScale = min(target.width / bounds.width, target.height / bounds.height)
        let drawnWidth = bounds.width * drawScale
        let drawnHeight = bounds.height * drawScale
        let offsetX = target.midX - (drawnWidth / 2)
        let offsetY = target.midY - (drawnHeight / 2)

        cg.saveGState()
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        cg.translateBy(x: offsetX, y: offsetY)
        cg.scaleBy(x: drawScale, y: drawScale)
        cg.translateBy(x: -bounds.minX, y: -bounds.minY)
        cg.addPath(path)

        switch style {
        case .enabled:
            cg.setFillColor(spotifyGreen.cgColor)
            cg.fillPath()
        case .disabled:
            // Apple-native disabled look: same glyph, monochrome, lighter/translucent.
            cg.setFillColor(NSColor.black.withAlphaComponent(0.36).cgColor)
            cg.fillPath()
        }

        cg.restoreGState()
        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        output.isTemplate = (style == .disabled)
        return output
    }
}

private enum SVGPathParser {
    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    static func parse(pathData: String) -> CGPath? {
        let tokens = tokenize(pathData)
        guard !tokens.isEmpty else {
            return nil
        }

        let path = CGMutablePath()
        var currentCommand: Character?
        var index = 0

        func peekNumber() -> Bool {
            guard index < tokens.count else {
                return false
            }
            if case .number = tokens[index] {
                return true
            }
            return false
        }

        func readNumber() -> CGFloat? {
            guard index < tokens.count else {
                return nil
            }
            guard case let .number(value) = tokens[index] else {
                return nil
            }
            index += 1
            return value
        }

        while index < tokens.count {
            if case let .command(command) = tokens[index] {
                currentCommand = command
                index += 1
            }

            guard let command = currentCommand else {
                return nil
            }

            switch command {
            case "M":
                guard let x = readNumber(), let y = readNumber() else {
                    return nil
                }
                path.move(to: CGPoint(x: x, y: y))
                while peekNumber() {
                    guard let lx = readNumber(), let ly = readNumber() else {
                        return nil
                    }
                    path.addLine(to: CGPoint(x: lx, y: ly))
                }
                currentCommand = "L"
            case "L":
                while peekNumber() {
                    guard let x = readNumber(), let y = readNumber() else {
                        return nil
                    }
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            case "C":
                while peekNumber() {
                    guard let x1 = readNumber(),
                          let y1 = readNumber(),
                          let x2 = readNumber(),
                          let y2 = readNumber(),
                          let x = readNumber(),
                          let y = readNumber()
                    else {
                        return nil
                    }
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: x1, y: y1),
                        control2: CGPoint(x: x2, y: y2)
                    )
                }
            case "Z", "z":
                path.closeSubpath()
            default:
                return nil
            }
        }

        return path
    }

    private static func tokenize(_ input: String) -> [Token] {
        let chars = Array(input)
        var tokens: [Token] = []
        var index = 0

        func isNumberStart(_ c: Character) -> Bool {
            c.isNumber || c == "-" || c == "+" || c == "."
        }

        while index < chars.count {
            let c = chars[index]

            if c.isLetter {
                tokens.append(.command(c))
                index += 1
                continue
            }

            if isNumberStart(c) {
                let start = index
                index += 1
                while index < chars.count {
                    let n = chars[index]
                    let previous = chars[index - 1]
                    let isExponentSign = (n == "-" || n == "+") && (previous == "e" || previous == "E")
                    if n.isNumber || n == "." || n == "e" || n == "E" || isExponentSign {
                        index += 1
                    } else {
                        break
                    }
                }
                let raw = String(chars[start ..< index])
                if let value = Double(raw) {
                    tokens.append(.number(CGFloat(value)))
                }
                continue
            }

            index += 1
        }

        return tokens
    }
}
