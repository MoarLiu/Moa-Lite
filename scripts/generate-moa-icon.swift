#!/usr/bin/env swift
import AppKit
import Foundation

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let assets = root.appendingPathComponent("assets", isDirectory: true)
private let iconset = assets.appendingPathComponent("Moa.iconset", isDirectory: true)
private let preview = assets.appendingPathComponent("moa-icon-1024.png")
private let icns = assets.appendingPathComponent("moa-icon.icns")

try fileManager.createDirectory(at: assets, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

private func color(_ hex: UInt32) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(red: red, green: green, blue: blue, alpha: 1)
}

private func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func boltPath(_ scale: CGFloat) -> NSBezierPath {
    let points = [
        CGPoint(x: 495, y: 872), CGPoint(x: 267, y: 490),
        CGPoint(x: 451, y: 490), CGPoint(x: 381, y: 152),
        CGPoint(x: 739, y: 615), CGPoint(x: 548, y: 615),
        CGPoint(x: 633, y: 872)
    ]

    let path = NSBezierPath()
    path.move(to: CGPoint(x: points[0].x * scale, y: points[0].y * scale))
    for point in points.dropFirst() {
        path.line(to: CGPoint(x: point.x * scale, y: point.y * scale))
    }
    path.close()
    return path
}

private func drawMenuLine(_ rect: NSRect) {
    let path = roundedPath(rect, radius: rect.height / 2)
    NSColor.white.withAlphaComponent(0.88).setFill()
    path.fill()
}

private func drawIcon(pixelSize: Int) throws -> Data {
    let size = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [.alphaFirst],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "MoaIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
    }

    rep.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "MoaIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let scale = size / 1024
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let background = roundedPath(canvas, radius: 224 * scale)
    background.addClip()
    NSGradient(colors: [color(0x191B24), color(0x1E5CE6), color(0x22C7A9)])?.draw(in: canvas, angle: -45)

    NSColor.black.withAlphaComponent(0.18).setFill()
    roundedPath(
        NSRect(x: 118 * scale, y: 94 * scale, width: 788 * scale, height: 788 * scale),
        radius: 180 * scale
    ).fill()

    drawMenuLine(NSRect(x: 702 * scale, y: 728 * scale, width: 188 * scale, height: 80 * scale))
    drawMenuLine(NSRect(x: 630 * scale, y: 588 * scale, width: 260 * scale, height: 80 * scale))
    drawMenuLine(NSRect(x: 684 * scale, y: 448 * scale, width: 206 * scale, height: 80 * scale))

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
    shadow.shadowBlurRadius = 24 * scale
    shadow.set()
    NSGradient(colors: [color(0xFFF4A8), color(0xFFD23F), color(0xFF8A1E)])?.draw(in: boltPath(scale), angle: -65)
    NSGraphicsContext.restoreGraphicsState()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let text = NSAttributedString(
        string: "Moa",
        attributes: [
            .font: NSFont.systemFont(ofSize: 134 * scale, weight: .black),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
    )
    let textRect = NSRect(x: 128 * scale, y: 126 * scale, width: 768 * scale, height: 164 * scale)
    text.draw(in: textRect)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MoaIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }
    return data
}

private let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconFiles {
    let data = try drawIcon(pixelSize: size)
    try data.write(to: iconset.appendingPathComponent(name), options: .atomic)
    if size == 1024 {
        try data.write(to: preview, options: .atomic)
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", icns.path, iconset.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "MoaIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

try? fileManager.removeItem(at: iconset)

print("Generated: \(icns.path)")
