import AppKit
import CoreGraphics
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

let canvasSize: CGFloat = 1024
let background = CGPath(
    roundedRect: CGRect(x: 96, y: 96, width: 832, height: 832),
    cornerWidth: 188,
    cornerHeight: 188,
    transform: nil
)
let colors = CGColorSpaceCreateDeviceRGB()

func gradient(_ stops: [NSColor]) -> CGGradient {
    CGGradient(colorsSpace: colors, colors: stops.map(\.cgColor) as CFArray, locations: nil)!
}

func renderIcon(at size: Int) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SoundMixIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(size) / canvasSize, y: CGFloat(size) / canvasSize)
    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -22), blur: 39, color: NSColor(calibratedRed: 0.24, green: 0.15, blue: 0.49, alpha: 0.30).cgColor)
    context.addPath(background)
    context.setFillColor(NSColor(calibratedRed: 0.38, green: 0.28, blue: 0.72, alpha: 1).cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(background)
    context.clip()
    context.drawLinearGradient(
        gradient([
            NSColor(calibratedRed: 0.75, green: 0.57, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.51, green: 0.38, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.68, alpha: 1)
        ]),
        start: CGPoint(x: 155, y: 850),
        end: CGPoint(x: 855, y: 145),
        options: []
    )
    context.drawRadialGradient(
        gradient([NSColor.white.withAlphaComponent(0.34), NSColor.white.withAlphaComponent(0)]),
        startCenter: CGPoint(x: 215, y: 845),
        startRadius: 0,
        endCenter: CGPoint(x: 215, y: 845),
        endRadius: 680,
        options: []
    )
    context.restoreGState()

    context.addPath(background)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.62).cgColor)
    context.setLineWidth(10)
    context.strokePath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -7), blur: 17, color: NSColor(calibratedRed: 0.23, green: 0.14, blue: 0.52, alpha: 0.28).cgColor)
    for (index, height) in [180.0, 330.0, 450.0, 300.0, 200.0].enumerated() {
        let bar = CGPath(
            roundedRect: CGRect(x: 267 + CGFloat(index) * 105, y: 512 - height / 2, width: 70, height: height),
            cornerWidth: 35,
            cornerHeight: 35,
            transform: nil
        )
        context.addPath(bar)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
    }
    context.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SoundMixIcon", code: 2)
    }
    try png.write(to: destination.appendingPathComponent("icon_\(size).png"))
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try renderIcon(at: size)
}
