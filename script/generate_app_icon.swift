#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let iconset = root.appendingPathComponent("dist", isDirectory: true).appendingPathComponent("Noise.iconset", isDirectory: true)
let output = root.appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("Noise", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

func renderIcon(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "NoiseIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap rep."])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)

    NSColor.clear.setFill()
    rect.fill()

    let corner = CGFloat(pixels) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.055, dy: CGFloat(pixels) * 0.055), xRadius: corner, yRadius: corner)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.26, alpha: 1),
        NSColor(calibratedRed: 0.86, green: 0.45, blue: 0.18, alpha: 1)
    ])?.draw(in: background, angle: 42)

    let waveRect = rect.insetBy(dx: CGFloat(pixels) * 0.18, dy: CGFloat(pixels) * 0.32)
    let wave = NSBezierPath()
    let midY = waveRect.midY
    let amplitude = waveRect.height * 0.24
    let step = waveRect.width / 96
    for index in 0...96 {
        let x = waveRect.minX + CGFloat(index) * step
        let phase = CGFloat(index) / 96 * .pi * 4
        let y = midY + sin(phase) * amplitude
        if index == 0 {
            wave.move(to: NSPoint(x: x, y: y))
        } else {
            wave.line(to: NSPoint(x: x, y: y))
        }
    }
    wave.lineWidth = CGFloat(pixels) * 0.055
    wave.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.92).setStroke()
    wave.stroke()

    let dotRadius = CGFloat(pixels) * 0.105
    let dotRect = NSRect(
        x: rect.midX - dotRadius,
        y: rect.maxY - CGFloat(pixels) * 0.30,
        width: dotRadius * 2,
        height: dotRadius * 2
    )
    NSColor(calibratedRed: 1.0, green: 0.46, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: rect.midX + dotRadius * 0.25, y: dotRect.maxY - dotRadius * 0.1))
    leaf.curve(
        to: NSPoint(x: rect.midX + dotRadius * 1.25, y: dotRect.maxY + dotRadius * 0.45),
        controlPoint1: NSPoint(x: rect.midX + dotRadius * 0.55, y: dotRect.maxY + dotRadius * 0.35),
        controlPoint2: NSPoint(x: rect.midX + dotRadius * 1.05, y: dotRect.maxY + dotRadius * 0.42)
    )
    leaf.curve(
        to: NSPoint(x: rect.midX + dotRadius * 0.25, y: dotRect.maxY - dotRadius * 0.1),
        controlPoint1: NSPoint(x: rect.midX + dotRadius * 0.85, y: dotRect.maxY + dotRadius * 0.9),
        controlPoint2: NSPoint(x: rect.midX + dotRadius * 0.35, y: dotRect.maxY + dotRadius * 0.45)
    )
    NSColor(calibratedRed: 0.36, green: 0.84, blue: 0.55, alpha: 1).setFill()
    leaf.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "NoiseIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG."])
    }
    return data
}

let entries: [(name: String, pixels: Int)] = [
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

for entry in entries {
    let data = try renderIcon(pixels: entry.pixels)
    try data.write(to: iconset.appendingPathComponent(entry.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "NoiseIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

print("Generated \(output.path)")
