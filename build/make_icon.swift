#!/usr/bin/env swift
import AppKit
import CoreGraphics

func renderIcon(pixelSize: Int) -> Data? {
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
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

    // Background: rounded square with diagonal gradient
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.2237
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    ctx.saveGState()
    bgPath.addClip()

    let top = NSColor(calibratedRed: 0.33, green: 0.52, blue: 0.98, alpha: 1).cgColor
    let bot = NSColor(calibratedRed: 0.58, green: 0.32, blue: 0.93, alpha: 1).cgColor
    if let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top, bot] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }
    ctx.restoreGState()

    // Clock face
    let faceInset = size * 0.17
    let faceRect = NSRect(
        x: faceInset, y: faceInset,
        width: size - 2 * faceInset,
        height: size - 2 * faceInset
    )
    NSColor.white.setFill()
    NSBezierPath(ovalIn: faceRect).fill()

    // Soft inner shadow ring
    NSColor(calibratedWhite: 0.0, alpha: 0.08).setStroke()
    let ring = NSBezierPath(ovalIn: faceRect.insetBy(dx: size * 0.01, dy: size * 0.01))
    ring.lineWidth = size * 0.015
    ring.stroke()

    let center = NSPoint(x: size / 2, y: size / 2)
    let faceRadius = faceRect.width / 2

    // Hour ticks
    NSColor(calibratedWhite: 0.25, alpha: 1).setStroke()
    for i in 0..<12 {
        let angle = CGFloat(i) * .pi / 6
        let isMajor = (i % 3 == 0)
        let inner = faceRadius * (isMajor ? 0.78 : 0.84)
        let outer = faceRadius * 0.92
        let p = NSBezierPath()
        p.lineWidth = size * (isMajor ? 0.022 : 0.012)
        p.lineCapStyle = .round
        p.move(to: NSPoint(
            x: center.x + cos(angle) * inner,
            y: center.y + sin(angle) * inner
        ))
        p.line(to: NSPoint(
            x: center.x + cos(angle) * outer,
            y: center.y + sin(angle) * outer
        ))
        p.stroke()
    }

    // Hands — classic 10:10
    NSColor(calibratedWhite: 0.12, alpha: 1).setStroke()

    // Hour hand: pointing to 10 (angle for 10 o'clock from top = -60° from vertical)
    let hourAngle: CGFloat = .pi / 2 + (2 * .pi * (10.0 / 12.0)) // radians from +x axis
    let hourLen = faceRadius * 0.50
    let hour = NSBezierPath()
    hour.lineWidth = size * 0.045
    hour.lineCapStyle = .round
    hour.move(to: center)
    hour.line(to: NSPoint(
        x: center.x + cos(hourAngle) * hourLen,
        y: center.y + sin(hourAngle) * hourLen
    ))
    hour.stroke()

    // Minute hand: pointing to 2 (10 minutes past)
    let minuteAngle: CGFloat = .pi / 2 - (2 * .pi * (10.0 / 60.0))
    let minuteLen = faceRadius * 0.72
    let minute = NSBezierPath()
    minute.lineWidth = size * 0.032
    minute.lineCapStyle = .round
    minute.move(to: center)
    minute.line(to: NSPoint(
        x: center.x + cos(minuteAngle) * minuteLen,
        y: center.y + sin(minuteAngle) * minuteLen
    ))
    minute.stroke()

    // Center pin
    NSColor(calibratedRed: 0.95, green: 0.32, blue: 0.32, alpha: 1).setFill()
    let pinR = size * 0.032
    NSBezierPath(ovalIn: NSRect(
        x: center.x - pinR, y: center.y - pinR,
        width: pinR * 2, height: pinR * 2
    )).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count >= 2 else {
    print("usage: make_icon.swift <outDir>")
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(
    atPath: outDir,
    withIntermediateDirectories: true
)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in sizes {
    guard let data = renderIcon(pixelSize: px) else {
        print("FAILED \(name)")
        exit(1)
    }
    let path = "\(outDir)/\(name)"
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(name) (\(px)x\(px))")
}
