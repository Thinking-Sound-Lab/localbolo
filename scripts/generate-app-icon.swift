#!/usr/bin/env swift
//
// Renders LocalBolo's app icon (a black dictation pill with a waveform, on
// warm paper) into the Mac app's asset catalog and the website, plus a
// variant with a "DEV" badge for development builds.
//
// Usage: swift scripts/generate-app-icon.swift

import AppKit

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assetCatalog = repoRoot.appending(path: "apps/mac/LocalBolo/Resources/Assets.xcassets")
let webApp = repoRoot.appending(path: "apps/web/src/app")
let webPublic = repoRoot.appending(path: "apps/web/public")

/// Draws the icon into a square context of the given pixel size, optionally
/// with a text badge along the bottom.
func drawIcon(in context: CGContext, size: CGFloat, badge: String? = nil) {
    let scale = size / 1024
    context.scaleBy(x: scale, y: scale)

    // macOS icon grid: an 824 pt rounded square centred on a 1024 pt canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow beneath the body.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.28))
    context.addPath(bodyPath)
    context.setFillColor(CGColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1))
    context.fillPath()
    context.restoreGState()

    // Warm paper gradient.
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let paper = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(red: 1.00, green: 0.99, blue: 0.97, alpha: 1),
            CGColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(paper, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // The pill.
    let pill = CGRect(x: 212, y: 402, width: 600, height: 220)
    let pillPath = CGPath(roundedRect: pill, cornerWidth: 110, cornerHeight: 110, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(pillPath)
    context.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1))
    context.fillPath()
    context.restoreGState()

    // Waveform bars, tallest in the middle.
    let heights: [CGFloat] = [44, 84, 124, 150, 104, 150, 124, 84, 44]
    let barWidth: CGFloat = 26
    let spacing: CGFloat = 22
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
    var x = pill.midX - totalWidth / 2
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    for height in heights {
        let bar = CGRect(x: x, y: pill.midY - height / 2, width: barWidth, height: height)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        context.fillPath()
        x += barWidth + spacing
    }

    if let badge {
        drawBadge(badge, in: context)
    }
}

/// An ember-coloured label near the bottom of the icon.
func drawBadge(_ text: String, in context: CGContext) {
    let badge = CGRect(x: 332, y: 170, width: 360, height: 140)
    context.addPath(CGPath(roundedRect: badge, cornerWidth: 70, cornerHeight: 70, transform: nil))
    context.setFillColor(CGColor(red: 0.965, green: 0.353, blue: 0.180, alpha: 1))
    context.fillPath()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 92, weight: .heavy),
        .foregroundColor: NSColor.white,
        .kern: 6,
    ]
    let label = NSAttributedString(string: text, attributes: attributes)
    let labelSize = label.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    label.draw(at: CGPoint(x: badge.midX - labelSize.width / 2, y: badge.midY - labelSize.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

func renderPNG(size: Int, badge: String? = nil, to url: URL) throws {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Couldn't create a \(size)px context") }

    drawIcon(in: context, size: CGFloat(size), badge: badge)
    let image = context.makeImage()!
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

/// Writes an app icon set with every size macOS asks for, at 1x and 2x.
func writeIconSet(named name: String, badge: String? = nil) throws {
    let iconSet = assetCatalog.appending(path: "\(name).appiconset")
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let filename = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try renderPNG(size: points * scale, badge: badge, to: iconSet.appending(path: filename))
            images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": filename])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: iconSet.appending(path: "Contents.json"))
}

try writeIconSet(named: "AppIcon")
try writeIconSet(named: "AppIcon-Dev", badge: "DEV")

// Website: Next.js picks up icon.png and apple-icon.png from the app folder.
try renderPNG(size: 256, to: webApp.appending(path: "icon.png"))
try renderPNG(size: 180, to: webApp.appending(path: "apple-icon.png"))
try renderPNG(size: 512, to: webPublic.appending(path: "app-icon.png"))

print("App icon written to the Mac asset catalog and the website.")
