import AppKit
import CoreGraphics
import Foundation

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func appleBody() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 511, y: 731))
    path.addCurve(to: CGPoint(x: 331, y: 736), control1: CGPoint(x: 464, y: 757), control2: CGPoint(x: 390, y: 764))
    path.addCurve(to: CGPoint(x: 210, y: 476), control1: CGPoint(x: 230, y: 684), control2: CGPoint(x: 190, y: 583))
    path.addCurve(to: CGPoint(x: 422, y: 191), control1: CGPoint(x: 233, y: 331), control2: CGPoint(x: 334, y: 208))
    path.addCurve(to: CGPoint(x: 514, y: 223), control1: CGPoint(x: 467, y: 184), control2: CGPoint(x: 490, y: 219))
    path.addCurve(to: CGPoint(x: 608, y: 191), control1: CGPoint(x: 541, y: 222), control2: CGPoint(x: 562, y: 188))
    path.addCurve(to: CGPoint(x: 807, y: 448), control1: CGPoint(x: 710, y: 204), control2: CGPoint(x: 790, y: 340))
    path.addCurve(to: CGPoint(x: 729, y: 539), control1: CGPoint(x: 756, y: 459), control2: CGPoint(x: 733, y: 494))
    path.addCurve(to: CGPoint(x: 803, y: 626), control1: CGPoint(x: 726, y: 581), control2: CGPoint(x: 754, y: 615))
    path.addCurve(to: CGPoint(x: 649, y: 764), control1: CGPoint(x: 775, y: 707), control2: CGPoint(x: 720, y: 758))
    path.addCurve(to: CGPoint(x: 511, y: 731), control1: CGPoint(x: 593, y: 770), control2: CGPoint(x: 548, y: 744))
    path.closeSubpath()
    return path
}

func leaf() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 526, y: 767))
    path.addCurve(to: CGPoint(x: 700, y: 866), control1: CGPoint(x: 554, y: 862), control2: CGPoint(x: 622, y: 907))
    path.addCurve(to: CGPoint(x: 526, y: 767), control1: CGPoint(x: 675, y: 806), control2: CGPoint(x: 612, y: 779))
    path.closeSubpath()
    return path
}

let panes: [(CGRect, UInt32)] = [
    (CGRect(x: 334, y: 525, width: 160, height: 148), 0x5bbbdc),
    (CGRect(x: 516, y: 525, width: 160, height: 148), 0xee866e),
    (CGRect(x: 334, y: 355, width: 160, height: 148), 0xf1bf63),
    (CGRect(x: 516, y: 355, width: 160, height: 148), 0x72caa6),
]

func renderAppIcon(_ context: CGContext) {
    let plate = CGPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864),
                       cornerWidth: 188, cornerHeight: 188, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -22), blur: 34, color: color(0x09171c, alpha: 0.32))
    context.addPath(plate)
    context.setFillColor(color(0x20363c))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    let plateGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [color(0x38565b), color(0x1a3038)] as CFArray,
                                   locations: [0, 1])!
    context.drawLinearGradient(plateGradient,
                               start: CGPoint(x: 180, y: 930), end: CGPoint(x: 850, y: 100), options: [])
    context.restoreGState()

    context.addPath(plate)
    context.setStrokeColor(color(0xb3d4d0, alpha: 0.2))
    context.setLineWidth(4)
    context.strokePath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 26, color: color(0x08151a, alpha: 0.35))
    context.addPath(appleBody())
    context.setFillColor(color(0xf4f8f5))
    context.fillPath()
    context.restoreGState()

    context.addPath(leaf())
    context.setFillColor(color(0x8ad49b))
    context.fillPath()

    for (rect, hex) in panes {
        let pane = CGPath(roundedRect: rect, cornerWidth: 13, cornerHeight: 13, transform: nil)
        context.addPath(pane)
        context.setFillColor(color(hex))
        context.fillPath()
    }
}

func renderMenuBarIcon(_ context: CGContext) {
    context.translateBy(x: 64, y: 64)
    context.scaleBy(x: 0.158, y: 0.158)
    context.translateBy(x: -512, y: -520)
    context.addPath(appleBody())
    context.setFillColor(color(0x000000))
    context.fillPath()
    context.addPath(leaf())
    context.fillPath()
    context.setBlendMode(.clear)
    for (rect, _) in panes {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 13, cornerHeight: 13, transform: nil))
        context.fillPath()
    }
}

func writePNG(size: Int, logicalSize: Int = 1024, to url: URL, draw: (CGContext) -> Void) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.scaleBy(x: CGFloat(size) / CGFloat(logicalSize), y: CGFloat(size) / CGFloat(logicalSize))
    draw(context)
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fatalError("Usage: swift render_icon.swift ICONSET_DIRECTORY PREVIEW_PNG MENUBAR_PNG")
}
let iconset = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let variants: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (size, name) in variants {
    try writePNG(size: size, to: iconset.appendingPathComponent(name), draw: renderAppIcon)
}
try writePNG(size: 1024, to: URL(fileURLWithPath: arguments[2]), draw: renderAppIcon)
try writePNG(size: 128, logicalSize: 128, to: URL(fileURLWithPath: arguments[3]), draw: renderMenuBarIcon)
