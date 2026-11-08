import Foundation
import AppKit
import CoreGraphics

func renderAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 1024.0
    ctx.scaleBy(x: scale, y: scale)

    // Helper for solid hex colors
    func hexColor(_ hex: String, alpha: CGFloat = 1.0) -> CGColor {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        return CGColor(
            srgbRed: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }

    // 1. macOS Squircle Background (Deep Obsidian & Warm Charcoal)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Base background gradient: Deep charcoal into warm espresso
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [hexColor("#1C1917"), hexColor("#121110")] as CFArray
    let bgLocations: [CGFloat] = [0.0, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }

    // Ambient warm citrus glow in the background
    let glowColors = [hexColor("#FF6B00", alpha: 0.18), hexColor("#FF8A00", alpha: 0.0)] as CFArray
    let glowLocations: [CGFloat] = [0.0, 1.0]
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations) {
        ctx.drawRadialGradient(glowGradient, startCenter: CGPoint(x: 512, y: 512), startRadius: 40, endCenter: CGPoint(x: 512, y: 512), endRadius: 400, options: [])
    }
    ctx.restoreGState()

    // Subtle Squircle Inner Border
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(4.0)
    ctx.setStrokeColor(hexColor("#FFFFFF", alpha: 0.08))
    ctx.strokePath()
    ctx.restoreGState()

    // 2. Citrus Slice (Wedge Wheel) - Positioned dynamically at center
    let center = CGPoint(x: 512, y: 490)
    let outerRadius: CGFloat = 250.0
    let innerRadius: CGFloat = 215.0

    // Outer Rind (Vibrant Zest Orange)
    let rindPath = CGMutablePath()
    let startAngle: CGFloat = -.pi * 0.15
    let endAngle: CGFloat = .pi + .pi * 0.15
    rindPath.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    rindPath.addLine(to: CGPoint(x: center.x - cos(startAngle) * innerRadius, y: center.y + sin(startAngle) * innerRadius))
    rindPath.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
    rindPath.closeSubpath()

    ctx.saveGState()
    ctx.addPath(rindPath)
    ctx.setFillColor(hexColor("#FF6B00")) // Electric Tang Orange
    ctx.fillPath()
    ctx.restoreGState()

    // Inner Pith Ring (Warm Cream)
    let pithPath = CGMutablePath()
    pithPath.addArc(center: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    pithPath.addLine(to: CGPoint(x: center.x - cos(startAngle) * (innerRadius - 10), y: center.y + sin(startAngle) * (innerRadius - 10)))
    pithPath.addArc(center: center, radius: innerRadius - 10, startAngle: endAngle, endAngle: startAngle, clockwise: true)
    pithPath.closeSubpath()

    ctx.saveGState()
    ctx.addPath(pithPath)
    ctx.setFillColor(hexColor("#FFF7ED", alpha: 0.85))
    ctx.fillPath()
    ctx.restoreGState()

    // 3. Segmented Citrus Pulp Wedges
    let segmentCount = 5
    let totalSpan = endAngle - startAngle
    let segmentSpan = totalSpan / CGFloat(segmentCount)
    let margin: CGFloat = 0.05 // angular gap between wedges

    for i in 0..<segmentCount {
        let segStart = startAngle + CGFloat(i) * segmentSpan + margin
        let segEnd = startAngle + CGFloat(i + 1) * segmentSpan - margin
        let pulpOuterRadius = innerRadius - 16
        let pulpInnerRadius: CGFloat = 55

        let pulpPath = CGMutablePath()
        pulpPath.addArc(center: center, radius: pulpOuterRadius, startAngle: segStart, endAngle: segEnd, clockwise: false)
        pulpPath.addLine(to: CGPoint(x: center.x + cos(segEnd) * pulpInnerRadius, y: center.y + sin(segEnd) * pulpInnerRadius))
        pulpPath.addArc(center: center, radius: pulpInnerRadius, startAngle: segEnd, endAngle: segStart, clockwise: true)
        pulpPath.closeSubpath()

        ctx.saveGState()
        ctx.addPath(pulpPath)
        // Alternate subtle gradient tones for natural citrus depth
        if i % 2 == 0 {
            ctx.setFillColor(hexColor("#F59E0B")) // Amber
        } else {
            ctx.setFillColor(hexColor("#FBBF24")) // Golden Citrus
        }
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 4. Central Dynamic Lightning Bolt (Instant Speed & Electric Zest)
    // Slicing through the citrus emblem with high energy
    let boltPath = CGMutablePath()
    boltPath.move(to: CGPoint(x: 575, y: 775))     // Top apex
    boltPath.addLine(to: CGPoint(x: 410, y: 515)) // Left mid notch
    boltPath.addLine(to: CGPoint(x: 520, y: 515)) // Horizontal shelf
    boltPath.addLine(to: CGPoint(x: 460, y: 245)) // Bottom sharp tip
    boltPath.addLine(to: CGPoint(x: 650, y: 545)) // Right mid notch
    boltPath.addLine(to: CGPoint(x: 540, y: 545)) // Center shelf
    boltPath.closeSubpath()

    // Bolt Drop Shadow for dimensional pop
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: hexColor("#000000", alpha: 0.55))
    ctx.addPath(boltPath)
    ctx.setFillColor(hexColor("#FBBF24"))
    ctx.fillPath()
    ctx.restoreGState()

    // Bolt Inner Fill (Bright Yellow to White Highlight)
    ctx.saveGState()
    ctx.addPath(boltPath)
    ctx.clip()
    let boltColors = [hexColor("#FFFFFF"), hexColor("#FDE047"), hexColor("#F59E0B")] as CFArray
    let boltLocations: [CGFloat] = [0.0, 0.45, 1.0]
    if let boltGradient = CGGradient(colorsSpace: colorSpace, colors: boltColors, locations: boltLocations) {
        ctx.drawLinearGradient(boltGradient, start: CGPoint(x: 575, y: 775), end: CGPoint(x: 460, y: 245), options: [])
    }
    ctx.restoreGState()

    // 5. Electric Spark / Zest Accent
    let sparkPath = CGMutablePath()
    sparkPath.move(to: CGPoint(x: 685, y: 730))
    sparkPath.addLine(to: CGPoint(x: 700, y: 760))
    sparkPath.addLine(to: CGPoint(x: 715, y: 730))
    sparkPath.addLine(to: CGPoint(x: 745, y: 715))
    sparkPath.addLine(to: CGPoint(x: 715, y: 700))
    sparkPath.addLine(to: CGPoint(x: 700, y: 670))
    sparkPath.addLine(to: CGPoint(x: 685, y: 700))
    sparkPath.addLine(to: CGPoint(x: 655, y: 715))
    sparkPath.closeSubpath()

    ctx.saveGState()
    ctx.addPath(sparkPath)
    ctx.setFillColor(hexColor("#FEF08A"))
    ctx.fillPath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG")
    }
    try! pngData.write(to: url)
}

let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetDir = currentDir.appendingPathComponent("AppIcon.iconset")

try? fileManager.removeItem(at: iconsetDir)
try! fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
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

print("🎨 Rendering vibrant Zest Citrus + Lightning App Icon set...")
for (name, size) in sizes {
    let img = renderAppIcon(size: size)
    let dest = iconsetDir.appendingPathComponent(name)
    savePNG(image: img, to: dest)
}

print("📦 Compiling AppIcon.icns with iconutil...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", currentDir.appendingPathComponent("AppIcon.icns").path]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ Successfully generated Zest AppIcon.icns!")
} else {
    print("❌ iconutil failed with status \(task.terminationStatus)")
    exit(1)
}
