import AppKit
import Foundation

public enum MenuBarIconStyle: String, CaseIterable, Sendable {
    case citrusWithBolt = "citrusWithBolt"
    case citrusWedge = "citrusWedge"
    case boltOnly = "boltOnly"
    case clipboardWithBolt = "clipboardWithBolt"

    public var title: String {
        switch self {
        case .citrusWithBolt: return "Zest Citrus with Lightning (Default)"
        case .citrusWedge: return "Citrus Wedge"
        case .boltOnly: return "Lightning Bolt Only"
        case .clipboardWithBolt: return "Classic Clipboard with Bolt"
        }
    }
}

extension Notification.Name {
    public static let menuBarIconDidChange = Notification.Name("zest_menuBarIconDidChange")
}

@MainActor
public struct MenuBarIconProvider {
    public static let defaultsKey = "zest_menuBarIconStyle"

    public static func currentStyle() -> MenuBarIconStyle {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let style = MenuBarIconStyle(rawValue: raw) {
            return style
        }
        return .citrusWithBolt
    }

    public static func makeIcon(style: MenuBarIconStyle? = nil) -> NSImage {
        let activeStyle = style ?? currentStyle()
        switch activeStyle {
        case .citrusWithBolt:
            return makeCitrusWithBoltIcon()
        case .citrusWedge:
            return makeCitrusWedgeIcon()
        case .boltOnly:
            return makeBoltOnlyIcon()
        case .clipboardWithBolt:
            return makeClipboardWithBoltIcon()
        }
    }

    /// Primary Zest Icon: Crisp Citrus Wheel with Central Lightning Bolt
    public static func makeCitrusWithBoltIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let scale = rect.width / 36.0
            ctx.scaleBy(x: scale, y: scale)

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)

            // 1. Outer Citrus Rind Circle
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: 5.0, y: 5.0, width: 26.0, height: 26.0))

            // 2. Radial Citrus Pulp Spokes
            let center = CGPoint(x: 18.0, y: 18.0)
            let angles: [CGFloat] = [0.0, .pi / 3, 2 * .pi / 3, .pi, 4 * .pi / 3, 5 * .pi / 3]
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            for a in angles {
                let p1 = CGPoint(x: center.x + cos(a) * 7.5, y: center.y + sin(a) * 7.5)
                let p2 = CGPoint(x: center.x + cos(a) * 12.0, y: center.y + sin(a) * 12.0)
                ctx.strokeLineSegments(between: [p1, p2])
            }

            // 3. Central Solid Lightning Bolt
            let bolt = CGMutablePath()
            bolt.move(to: CGPoint(x: 19.5, y: 26.0))
            bolt.addLine(to: CGPoint(x: 13.5, y: 18.0))
            bolt.addLine(to: CGPoint(x: 17.5, y: 18.0))
            bolt.addLine(to: CGPoint(x: 15.5, y: 10.0))
            bolt.addLine(to: CGPoint(x: 22.5, y: 18.5))
            bolt.addLine(to: CGPoint(x: 18.5, y: 18.5))
            bolt.closeSubpath()

            ctx.addPath(bolt)
            ctx.fillPath()

            return true
        }
        image.isTemplate = true
        return image
    }

    /// Alternative Zest Icon: Stylized Citrus Wedge
    public static func makeCitrusWedgeIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let scale = rect.width / 36.0
            ctx.scaleBy(x: scale, y: scale)

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)

            // Semicircular Citrus Wedge
            let center = CGPoint(x: 18.0, y: 19.0)
            let radius: CGFloat = 13.5

            let rind = CGMutablePath()
            rind.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0.0, clockwise: true)
            rind.closeSubpath()

            ctx.addPath(rind)
            ctx.setLineWidth(2.0)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()

            // Pulp Dividers
            let spokes: [CGFloat] = [.pi * 0.2, .pi * 0.4, .pi * 0.6, .pi * 0.8]
            ctx.setLineWidth(1.3)
            for a in spokes {
                let p1 = CGPoint(x: center.x - cos(a) * 4.5, y: center.y - sin(a) * 4.5)
                let p2 = CGPoint(x: center.x - cos(a) * 11.5, y: center.y - sin(a) * 11.5)
                ctx.strokeLineSegments(between: [p1, p2])
            }

            // Central Bolt
            let bolt = CGMutablePath()
            bolt.move(to: CGPoint(x: 20.0, y: 31.0))
            bolt.addLine(to: CGPoint(x: 13.5, y: 19.0))
            bolt.addLine(to: CGPoint(x: 18.0, y: 19.0))
            bolt.addLine(to: CGPoint(x: 15.0, y: 9.0))
            bolt.addLine(to: CGPoint(x: 23.0, y: 20.5))
            bolt.addLine(to: CGPoint(x: 18.5, y: 20.5))
            bolt.closeSubpath()

            ctx.addPath(bolt)
            ctx.fillPath()

            return true
        }
        image.isTemplate = true
        return image
    }

    public static func makeBoltOnlyIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Zest")?.withSymbolConfiguration(config) ?? NSImage()
        img.isTemplate = true
        return img
    }

    public static func makeClipboardWithBoltIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let scale = rect.width / 36.0
            ctx.scaleBy(x: scale, y: scale)

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // 1. Board Outline
            let boardRect = CGRect(x: 6.5, y: 3.5, width: 23.0, height: 26.0)
            let boardPath = CGPath(roundedRect: boardRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            ctx.addPath(boardPath)
            ctx.strokePath()

            // 2. Clamp
            let clampRect = CGRect(x: 11.0, y: 27.5, width: 14.0, height: 4.5)
            let clampPath = CGPath(roundedRect: clampRect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
            ctx.addPath(clampPath)
            ctx.fillPath()

            // 3. Loop
            let loopPath = CGMutablePath()
            loopPath.addArc(center: CGPoint(x: 18.0, y: 32.0), radius: 2.2, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.addPath(loopPath)
            ctx.setLineWidth(1.6)
            ctx.strokePath()

            // 4. Center Lightning Bolt (Solid)
            let bolt = CGMutablePath()
            bolt.move(to: CGPoint(x: 19.5, y: 23.5))
            bolt.addLine(to: CGPoint(x: 13.0, y: 15.0))
            bolt.addLine(to: CGPoint(x: 17.5, y: 15.0))
            bolt.addLine(to: CGPoint(x: 15.2, y: 6.5))
            bolt.addLine(to: CGPoint(x: 23.0, y: 16.0))
            bolt.addLine(to: CGPoint(x: 18.5, y: 16.0))
            bolt.closeSubpath()

            ctx.addPath(bolt)
            ctx.fillPath()

            return true
        }
        image.isTemplate = true
        return image
    }
}
