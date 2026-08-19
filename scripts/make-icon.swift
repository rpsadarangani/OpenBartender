#!/usr/bin/env swift
// Renders OpenBartender's app icon into an .iconset directory (offscreen, no
// window server needed). Usage: swift make-icon.swift <output.iconset>
import AppKit

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let s = CGFloat(size)
    let rect = NSRect(x: 0, y: 0, width: s, height: s)

    // Rounded-rect background with a vertical blue gradient.
    let inset = s * 0.06
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                          xRadius: s * 0.22, yRadius: s * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.11, green: 0.33, blue: 0.82, alpha: 1),
    ])!
    gradient.draw(in: bg, angle: -90)

    // Menu-bar strip near the top.
    let barHeight = s * 0.14
    let bar = NSBezierPath(roundedRect: NSRect(x: s * 0.24, y: s * 0.60,
                                               width: s * 0.52, height: barHeight),
                           xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSColor.white.withAlphaComponent(0.9).setFill()
    bar.fill()

    // Three "icons" on the strip.
    NSColor(calibratedRed: 0.11, green: 0.33, blue: 0.82, alpha: 1).setFill()
    let dot = s * 0.05
    for i in 0..<3 {
        let x = s * 0.31 + CGFloat(i) * s * 0.14
        NSBezierPath(ovalIn: NSRect(x: x, y: s * 0.635, width: dot, height: dot)).fill()
    }

    // Chevron below.
    let chevron = NSBezierPath()
    chevron.lineWidth = s * 0.06
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.move(to: NSPoint(x: s * 0.56, y: s * 0.46))
    chevron.line(to: NSPoint(x: s * 0.42, y: s * 0.36))
    chevron.line(to: NSPoint(x: s * 0.56, y: s * 0.26))
    NSColor.white.setStroke()
    chevron.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.iconset>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel size)
let targets: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in targets {
    let data = render(size: size)
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("wrote \(targets.count) images to \(outDir)")
