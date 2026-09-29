#!/usr/bin/env swift
//
// Draws LocalBolo's icons from the monogram in brand/monogram.svg:
//
// - the app icon, a white monogram on a black tile, plus a development
//   variant with a DEV badge, into the Mac app's asset catalog;
// - the menu bar icons, as template images for idle and listening;
// - the website's favicon, Apple touch icon and app icon.
//
// Usage: swift scripts/generate-icons.swift

import AppKit

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assetCatalog = repoRoot.appending(path: "apps/mac/LocalBolo/Resources/Assets.xcassets")
let webApp = repoRoot.appending(path: "apps/web/src/app")
let webPublic = repoRoot.appending(path: "apps/web/public")

let white = CGColor(gray: 1, alpha: 1)
let black = CGColor(gray: 0, alpha: 1)
let blue = CGColor(red: 0.122, green: 0.239, blue: 1, alpha: 1) // #1f3dff, the site's blue

// MARK: - The monogram

/// The monogram's outline and the SVG view box it's drawn in.
struct Glyph {
    let path: CGPath
    let viewBox: CGRect

    /// Loads an SVG with a single path made of M, L, C and Z commands, as the
    /// brand files are.
    init(svg url: URL) throws {
        let svg = try String(contentsOf: url, encoding: .utf8)
        func attribute(_ name: String) -> String {
            let regex = try! NSRegularExpression(pattern: #"\s\#(name)="([^"]*)""#)
            guard let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)) else {
                fatalError("\(url.lastPathComponent) has no \(name) attribute")
            }
            return String(svg[Range(match.range(at: 1), in: svg)!])
        }

        let box = attribute("viewBox").split(separator: " ").map { CGFloat(Double($0)!) }
        viewBox = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
        path = Self.parse(attribute("d"))
    }

    private static func parse(_ data: String) -> CGPath {
        let regex = try! NSRegularExpression(pattern: #"[MLCZ]|-?[0-9]*\.?[0-9]+"#, options: .caseInsensitive)
        let tokens = regex.matches(in: data, range: NSRange(data.startIndex..., in: data))
            .map { String(data[Range($0.range, in: data)!]) }

        let path = CGMutablePath()
        var command = "M"
        var index = 0
        func point() -> CGPoint {
            defer { index += 2 }
            return CGPoint(x: Double(tokens[index])!, y: Double(tokens[index + 1])!)
        }

        while index < tokens.count {
            if tokens[index].first!.isLetter {
                command = tokens[index].uppercased()
                index += 1
                if command == "Z" { path.closeSubpath() }
                continue
            }
            switch command {
            case "M":
                path.move(to: point())
                command = "L" // Further pairs after a move are lines.
            case "L":
                path.addLine(to: point())
            case "C":
                let (control1, control2, end) = (point(), point(), point())
                path.addCurve(to: end, control1: control1, control2: control2)
            default:
                fatalError("Unsupported SVG path command \(command)")
            }
        }
        return path
    }

    /// Fills the glyph, scaled to fit `rect` (in a context whose y axis points up).
    func fill(in rect: CGRect, of context: CGContext, color: CGColor) {
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let size = CGSize(width: viewBox.width * scale, height: viewBox.height * scale)
        context.saveGState()
        // Centre it, then flip SVG's downward y axis.
        context.translateBy(x: rect.midX - size.width / 2, y: rect.midY + size.height / 2)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }
}

let monogram = try Glyph(svg: repoRoot.appending(path: "brand/monogram.svg"))

// MARK: - Drawing

/// The Mac app icon on the macOS grid: an 824 pt tile centred on a 1024 pt
/// canvas, with an optional badge along the bottom.
func drawAppIcon(in context: CGContext, badge: String?) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow beneath the tile.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(tilePath)
    context.setFillColor(black)
    context.fillPath()
    context.restoreGState()

    // Soft black gradient, lighter at the top.
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [CGColor(gray: 0.16, alpha: 1), CGColor(gray: 0.02, alpha: 1)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // A faint edge so the tile reads on dark backgrounds.
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.1))
    context.setLineWidth(3)
    context.strokePath()

    monogram.fill(in: CGRect(x: 512 - 230, y: 512 - 222, width: 460, height: 444), of: context, color: white)

    if let badge {
        drawBadge(badge, in: context)
    }
}

/// A blue label near the bottom of the tile.
func drawBadge(_ text: String, in context: CGContext) {
    let badge = CGRect(x: 362, y: 140, width: 300, height: 110)
    context.addPath(CGPath(roundedRect: badge, cornerWidth: 55, cornerHeight: 55, transform: nil))
    context.setFillColor(blue)
    context.fillPath()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 72, weight: .heavy),
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

/// The website's icon: the tile filling the whole canvas, since browsers and
/// iOS add their own margins. `isRounded` is false for the Apple touch icon,
/// which iOS rounds itself.
func drawWebIcon(in context: CGContext, isRounded: Bool) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let radius: CGFloat = isRounded ? 225 : 0
    context.addPath(CGPath(roundedRect: canvas, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(CGColor(gray: 0.04, alpha: 1))
    context.fillPath()
    monogram.fill(in: canvas.insetBy(dx: 230, dy: 230), of: context, color: white)
}

/// The menu bar icon, on an 18 pt canvas: the monogram when idle, and the
/// monogram cut out of a filled circle while listening. Drawn in black;
/// macOS tints template images to match the menu bar.
func drawMenuBarIcon(in context: CGContext, isListening: Bool) {
    let canvas = CGRect(x: 0, y: 0, width: 18, height: 18)
    if isListening {
        context.addEllipse(in: canvas.insetBy(dx: 0.5, dy: 0.5))
        context.setFillColor(black)
        context.fillPath()
        context.setBlendMode(.clear)
        monogram.fill(in: canvas.insetBy(dx: 4.25, dy: 4.25), of: context, color: black)
    } else {
        monogram.fill(in: canvas.insetBy(dx: 1.5, dy: 1.5), of: context, color: black)
    }
}

// MARK: - Output

/// Renders a drawing made on a `canvasSize` square into a `pixels` square PNG.
func renderPNG(pixels: Int, canvasSize: CGFloat, to url: URL, draw: (CGContext) -> Void) throws {
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Couldn't create a \(pixels)px context") }

    let scale = CGFloat(pixels) / canvasSize
    context.scaleBy(x: scale, y: scale)
    draw(context)

    let data = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

func writeContents(_ contents: [String: Any], to folder: URL) throws {
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: folder.appending(path: "Contents.json"))
}

/// Writes an app icon set with every size macOS asks for, at 1x and 2x.
func writeAppIconSet(named name: String, badge: String? = nil) throws {
    let iconSet = assetCatalog.appending(path: "\(name).appiconset")
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let filename = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try renderPNG(pixels: points * scale, canvasSize: 1024, to: iconSet.appending(path: filename)) {
                drawAppIcon(in: $0, badge: badge)
            }
            images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": filename])
        }
    }
    try writeContents(["images": images, "info": ["author": "xcode", "version": 1]], to: iconSet)
}

/// Writes a menu bar icon as a template image set at 1x and 2x.
func writeMenuBarIconSet(named name: String, isListening: Bool) throws {
    let imageSet = assetCatalog.appending(path: "\(name).imageset")
    var images: [[String: String]] = []
    for scale in [1, 2] {
        let filename = scale == 1 ? "\(name).png" : "\(name)@2x.png"
        try renderPNG(pixels: 18 * scale, canvasSize: 18, to: imageSet.appending(path: filename)) {
            drawMenuBarIcon(in: $0, isListening: isListening)
        }
        images.append(["idiom": "mac", "scale": "\(scale)x", "filename": filename])
    }
    try writeContents(
        [
            "images": images,
            "info": ["author": "xcode", "version": 1],
            "properties": ["template-rendering-intent": "template"],
        ],
        to: imageSet
    )
}

try writeAppIconSet(named: "AppIcon")
try writeAppIconSet(named: "AppIcon-Dev", badge: "DEV")
try writeMenuBarIconSet(named: "MenuBarIcon", isListening: false)
try writeMenuBarIconSet(named: "MenuBarIconListening", isListening: true)

// Website: Next.js picks up icon.png and apple-icon.png from the app folder.
try renderPNG(pixels: 256, canvasSize: 1024, to: webApp.appending(path: "icon.png")) { drawWebIcon(in: $0, isRounded: true) }
try renderPNG(pixels: 180, canvasSize: 1024, to: webApp.appending(path: "apple-icon.png")) { drawWebIcon(in: $0, isRounded: false) }
try renderPNG(pixels: 512, canvasSize: 1024, to: webPublic.appending(path: "app-icon.png")) { drawAppIcon(in: $0, badge: nil) }

print("Icons written to the Mac asset catalog and the website.")
