import Foundation
import SpriteKit

// MARK: - Isometric Constants

enum IsometricConstants {
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32
    static let halfTileWidth: CGFloat = 32
    static let halfTileHeight: CGFloat = 16

    // Z-ordering layers
    static let floorLayer: CGFloat = 0
    static let decorationLayer: CGFloat = 1000
    static let objectLayer: CGFloat = 2000
    static let effectLayer: CGFloat = 3000
    static let uiLayer: CGFloat = 4000
}

// MARK: - Coordinate Conversion

enum IsometricUtils {

    /// Convert grid coordinates (col, row) to screen position (CGPoint).
    /// Origin is top-center of the grid diamond.
    static func gridToScreen(col: Int, row: Int) -> CGPoint {
        let x = CGFloat(col - row) * IsometricConstants.halfTileWidth
        let y = -CGFloat(col + row) * IsometricConstants.halfTileHeight
        return CGPoint(x: x, y: y)
    }

    /// Convert a screen point back to fractional grid coordinates.
    static func screenToGrid(point: CGPoint) -> (col: Double, row: Double) {
        let col = (point.x / IsometricConstants.halfTileWidth - point.y / IsometricConstants.halfTileHeight) / 2.0
        let row = (-point.x / IsometricConstants.halfTileWidth - point.y / IsometricConstants.halfTileHeight) / 2.0
        return (Double(col), Double(row))
    }

    /// Convert a screen point to the nearest integer grid position.
    static func screenToGridPosition(point: CGPoint) -> GridPosition {
        let (col, row) = screenToGrid(point: point)
        return GridPosition(col: Int(round(col)), row: Int(round(row)))
    }

    /// Compute z-position for depth sorting. Tiles closer to camera (higher col+row, lower on screen) render in front.
    static func depthForPosition(col: Int, row: Int, layer: CGFloat = 0) -> CGFloat {
        // Higher col+row = closer to camera = drawn later = higher z-position.
        return layer + CGFloat(col + row)
    }

    /// Center of the grid in screen coordinates.
    static func gridCenter(width: Int, height: Int) -> CGPoint {
        let topLeft = gridToScreen(col: 0, row: 0)
        let topRight = gridToScreen(col: width - 1, row: 0)
        let bottomLeft = gridToScreen(col: 0, row: height - 1)
        let bottomRight = gridToScreen(col: width - 1, row: height - 1)
        let minX = min(topLeft.x, bottomLeft.x)
        let maxX = max(topRight.x, bottomRight.x)
        let minY = min(bottomRight.y, bottomLeft.y)
        let maxY = max(topLeft.y, topRight.y)
        return CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
    }

    /// Bounding rectangle of the full grid in screen coordinates.
    static func gridBounds(width: Int, height: Int) -> CGRect {
        let topLeft = gridToScreen(col: 0, row: 0)
        let topRight = gridToScreen(col: width - 1, row: 0)
        let bottomLeft = gridToScreen(col: 0, row: height - 1)
        let bottomRight = gridToScreen(col: width - 1, row: height - 1)
        let minX = min(topLeft.x, bottomLeft.x) - IsometricConstants.halfTileWidth
        let maxX = max(topRight.x, bottomRight.x) + IsometricConstants.halfTileWidth
        let minY = min(bottomRight.y, bottomLeft.y) - IsometricConstants.halfTileHeight
        let maxY = max(topLeft.y, topRight.y) + IsometricConstants.halfTileHeight
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Programmatic Texture Generation

enum TextureFactory {

    // MARK: - Diamond Path Helper

    private static func diamondPath(width w: CGFloat, height h: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h / 2))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: 0, y: h / 2))
        path.closeSubpath()
        return path
    }

    // MARK: Floor Tile

    /// Warm beige diamond with subtle wood-grain lines, inner glow, and cozy depth.
    static func floorTileTexture() -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let path = diamondPath(width: w, height: h)

            // Base warm beige fill
            gc.setFillColor(UIColor(red: 0.90, green: 0.84, blue: 0.75, alpha: 1).cgColor)
            gc.addPath(path)
            gc.fillPath()

            // Subtle warm gradient: lighter in center for depth
            gc.saveGState()
            gc.addPath(path)
            gc.clip()
            let centerX = w / 2
            let centerY = h / 2
            let radialColors: [CGFloat] = [
                0.94, 0.88, 0.80, 1.0,    // center: slightly lighter warm
                0.87, 0.80, 0.71, 0.4     // edge: fade to transparent
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: radialColors, locations: [0, 1], count: 2) {
                gc.drawRadialGradient(gradient, startCenter: CGPoint(x: centerX, y: centerY), startRadius: 0,
                                      endCenter: CGPoint(x: centerX, y: centerY), endRadius: w * 0.45,
                                      options: .drawsAfterEndLocation)
            }
            gc.restoreGState()

            // Subtle wood-grain lines
            gc.saveGState()
            gc.addPath(path)
            gc.clip()
            gc.setStrokeColor(UIColor(red: 0.82, green: 0.75, blue: 0.65, alpha: 0.35).cgColor)
            gc.setLineWidth(0.5)
            let grainSpacing: CGFloat = 5
            var y: CGFloat = 0
            while y < h {
                // Slightly wavy grain lines for natural look
                gc.move(to: CGPoint(x: 0, y: y))
                gc.addLine(to: CGPoint(x: w, y: y + CGFloat.random(in: -0.5...0.5)))
                y += grainSpacing
            }
            gc.strokePath()

            // Random knot/spot for texture variation (~20% of tiles)
            if Int.random(in: 0..<5) == 0 {
                let knotX = CGFloat.random(in: w * 0.25...w * 0.75)
                let knotY = CGFloat.random(in: h * 0.25...h * 0.75)
                gc.setFillColor(UIColor(red: 0.80, green: 0.72, blue: 0.60, alpha: 0.3).cgColor)
                gc.fillEllipse(in: CGRect(x: knotX - 2, y: knotY - 1.5, width: 4, height: 3))
            }
            gc.restoreGState()

            // Warm brown border with slight depth
            gc.setStrokeColor(UIColor(red: 0.70, green: 0.60, blue: 0.48, alpha: 0.7).cgColor)
            gc.setLineWidth(1.2)
            gc.addPath(path)
            gc.strokePath()

            // Inner highlight on top-left edges for 3D depth
            gc.saveGState()
            gc.addPath(path)
            gc.clip()
            gc.setStrokeColor(UIColor(red: 0.96, green: 0.92, blue: 0.86, alpha: 0.5).cgColor)
            gc.setLineWidth(0.8)
            gc.move(to: CGPoint(x: w / 2 + 1, y: 1))
            gc.addLine(to: CGPoint(x: 1, y: h / 2))
            gc.strokePath()
            gc.restoreGState()
        }
        return SKTexture(image: image)
    }

    // MARK: Equipment Texture

    /// Warm-toned isometric block per category with wood base accent.
    static func equipmentTexture(for type: EquipmentType, status: EquipmentStatus = .normal) -> SKTexture {
        let w = IsometricConstants.tileWidth
        let blockHeight: CGFloat = CGFloat(8 + type.tier * 8)
        let totalH = IsometricConstants.tileHeight + blockHeight
        let baseColor = type.baseColor

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: totalH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let hw = w / 2
            let hh = IsometricConstants.tileHeight / 2
            let baseY = blockHeight

            // --- Top face (lighter) ---
            let top = CGMutablePath()
            top.move(to: CGPoint(x: hw, y: baseY - hh))
            top.addLine(to: CGPoint(x: w, y: baseY))
            top.addLine(to: CGPoint(x: hw, y: baseY + hh))
            top.addLine(to: CGPoint(x: 0, y: baseY))
            top.closeSubpath()

            gc.setFillColor(baseColor.lighter(by: 0.15).cgColor)
            gc.addPath(top)
            gc.fillPath()

            // --- Left face (base color) ---
            let left = CGMutablePath()
            left.move(to: CGPoint(x: 0, y: baseY))
            left.addLine(to: CGPoint(x: hw, y: baseY + hh))
            left.addLine(to: CGPoint(x: hw, y: totalH))
            left.addLine(to: CGPoint(x: 0, y: totalH - hh))
            left.closeSubpath()

            gc.setFillColor(baseColor.cgColor)
            gc.addPath(left)
            gc.fillPath()

            // --- Right face (darker) ---
            let right = CGMutablePath()
            right.move(to: CGPoint(x: w, y: baseY))
            right.addLine(to: CGPoint(x: hw, y: baseY + hh))
            right.addLine(to: CGPoint(x: hw, y: totalH))
            right.addLine(to: CGPoint(x: w, y: totalH - hh))
            right.closeSubpath()

            gc.setFillColor(baseColor.darker(by: 0.18).cgColor)
            gc.addPath(right)
            gc.fillPath()

            // --- Wood base strip (bottom 3px of each face) ---
            let woodColor = Theme.skWoodTone
            let stripH: CGFloat = 3

            // Left wood strip
            let woodLeft = CGMutablePath()
            woodLeft.move(to: CGPoint(x: 0, y: totalH - hh))
            woodLeft.addLine(to: CGPoint(x: hw, y: totalH))
            woodLeft.addLine(to: CGPoint(x: hw, y: totalH - stripH))
            woodLeft.addLine(to: CGPoint(x: 0, y: totalH - hh - stripH + hh * stripH / (totalH - baseY)))
            woodLeft.closeSubpath()
            gc.setFillColor(woodColor.cgColor)
            gc.addPath(woodLeft); gc.fillPath()

            // Right wood strip
            let woodRight = CGMutablePath()
            woodRight.move(to: CGPoint(x: w, y: totalH - hh))
            woodRight.addLine(to: CGPoint(x: hw, y: totalH))
            woodRight.addLine(to: CGPoint(x: hw, y: totalH - stripH))
            woodRight.addLine(to: CGPoint(x: w, y: totalH - hh - stripH + hh * stripH / (totalH - baseY)))
            woodRight.closeSubpath()
            gc.setFillColor(woodColor.darker(by: 0.1).cgColor)
            gc.addPath(woodRight); gc.fillPath()

            // --- Category-specific details ---
            switch type.category {
            case .rack:
                drawRackDetails(gc: gc, type: type, status: status,
                                baseY: baseY, hh: hh, hw: hw, totalH: totalH, blockHeight: blockHeight)
            case .cooling:
                drawCoolingDetails(gc: gc, type: type,
                                   baseY: baseY, hh: hh, hw: hw, totalH: totalH, blockHeight: blockHeight)
            case .power:
                drawPowerDetails(gc: gc, type: type,
                                 baseY: baseY, hh: hh, hw: hw, totalH: totalH, blockHeight: blockHeight)
            case .network:
                drawNetworkDetails(gc: gc, type: type,
                                   baseY: baseY, hh: hh, hw: hw, totalH: totalH, blockHeight: blockHeight)
            }

            // Soft edge outlines (warm brown, not black)
            gc.setStrokeColor(UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.25).cgColor)
            gc.setLineWidth(0.5)
            gc.addPath(top); gc.strokePath()
            gc.addPath(left); gc.strokePath()
            gc.addPath(right); gc.strokePath()
        }
        return SKTexture(image: image)
    }

    // MARK: Ghost Texture

    /// Warm green/warm red translucent build preview.
    static func ghostTexture(for type: EquipmentType, valid: Bool) -> SKTexture {
        let w = IsometricConstants.tileWidth
        let blockHeight: CGFloat = CGFloat(8 + type.tier * 8)
        let totalH = IsometricConstants.tileHeight + blockHeight
        let tint: UIColor = valid
            ? Theme.skPositive.withAlphaComponent(0.45)   // warm sage green
            : Theme.skCritical.withAlphaComponent(0.45)    // warm rust

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: totalH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let hw = w / 2
            let hh = IsometricConstants.tileHeight / 2
            let baseY = blockHeight

            let top = CGMutablePath()
            top.move(to: CGPoint(x: hw, y: baseY - hh))
            top.addLine(to: CGPoint(x: w, y: baseY))
            top.addLine(to: CGPoint(x: hw, y: baseY + hh))
            top.addLine(to: CGPoint(x: 0, y: baseY))
            top.closeSubpath()
            gc.setFillColor(tint.cgColor)
            gc.addPath(top); gc.fillPath()

            let left = CGMutablePath()
            left.move(to: CGPoint(x: 0, y: baseY))
            left.addLine(to: CGPoint(x: hw, y: baseY + hh))
            left.addLine(to: CGPoint(x: hw, y: totalH))
            left.addLine(to: CGPoint(x: 0, y: totalH - hh))
            left.closeSubpath()
            gc.setFillColor(tint.withAlphaComponent(0.3).cgColor)
            gc.addPath(left); gc.fillPath()

            let right = CGMutablePath()
            right.move(to: CGPoint(x: w, y: baseY))
            right.addLine(to: CGPoint(x: hw, y: baseY + hh))
            right.addLine(to: CGPoint(x: hw, y: totalH))
            right.addLine(to: CGPoint(x: w, y: totalH - hh))
            right.closeSubpath()
            gc.setFillColor(tint.withAlphaComponent(0.2).cgColor)
            gc.addPath(right); gc.fillPath()

            // Dashed outline
            gc.setStrokeColor(tint.withAlphaComponent(0.8).cgColor)
            gc.setLineWidth(1)
            gc.setLineDash(phase: 0, lengths: [4, 3])
            gc.addPath(top); gc.strokePath()
        }
        return SKTexture(image: image)
    }

    // MARK: Selection Tile

    /// Warm orange highlight diamond.
    static func selectionTileTexture() -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let path = diamondPath(width: w, height: h)

            gc.setFillColor(Theme.skAccent.withAlphaComponent(0.2).cgColor)
            gc.addPath(path); gc.fillPath()

            gc.setStrokeColor(Theme.skAccent.withAlphaComponent(0.7).cgColor)
            gc.setLineWidth(2)
            gc.addPath(path); gc.strokePath()
        }
        return SKTexture(image: image)
    }

    // MARK: Incident Indicator

    /// Warm rust circle with white exclamation mark.
    static func incidentIndicatorTexture() -> SKTexture {
        let size: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setFillColor(Theme.skCritical.withAlphaComponent(0.9).cgColor)
            gc.fillEllipse(in: CGRect(x: 1, y: 1, width: size - 2, height: size - 2))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Theme.headlineUIFont(size: 16),
                .foregroundColor: UIColor.white
            ]
            let text = "!" as NSString
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size - textSize.width) / 2,
                y: (size - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
        return SKTexture(image: image)
    }

    // MARK: Expansion Tile

    /// Locked area diamond with coin icon and price text.
    static func expansionTileTexture(cost: Double) -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight + 14 // extra height for price label
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Hatched locked diamond
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w / 2, y: 4))
            path.addLine(to: CGPoint(x: w, y: 4 + IsometricConstants.tileHeight / 2))
            path.addLine(to: CGPoint(x: w / 2, y: 4 + IsometricConstants.tileHeight))
            path.addLine(to: CGPoint(x: 0, y: 4 + IsometricConstants.tileHeight / 2))
            path.closeSubpath()

            // Dim warm fill
            gc.setFillColor(Theme.skAccentGold.withAlphaComponent(0.15).cgColor)
            gc.addPath(path); gc.fillPath()

            // Cross-hatch pattern inside diamond
            gc.saveGState()
            gc.addPath(path); gc.clip()
            gc.setStrokeColor(Theme.skAccentGold.withAlphaComponent(0.2).cgColor)
            gc.setLineWidth(0.5)
            let step: CGFloat = 8
            var x: CGFloat = -w
            while x < w * 2 {
                gc.move(to: CGPoint(x: x, y: 0))
                gc.addLine(to: CGPoint(x: x + h, y: h))
                gc.move(to: CGPoint(x: x + h, y: 0))
                gc.addLine(to: CGPoint(x: x, y: h))
                x += step
            }
            gc.strokePath()
            gc.restoreGState()

            // Border
            gc.setStrokeColor(Theme.skAccentGold.withAlphaComponent(0.5).cgColor)
            gc.setLineWidth(1)
            gc.setLineDash(phase: 0, lengths: [3, 3])
            gc.addPath(path); gc.strokePath()

            // Coin icon (small gold circle)
            let coinSize: CGFloat = 8
            let coinX = w / 2 - coinSize - 2
            let coinY = 4 + IsometricConstants.tileHeight / 2 - coinSize / 2
            gc.setLineDash(phase: 0, lengths: [])
            gc.setFillColor(Theme.skAccentGold.cgColor)
            gc.fillEllipse(in: CGRect(x: coinX, y: coinY, width: coinSize, height: coinSize))
            gc.setStrokeColor(Theme.skWoodTone.cgColor)
            gc.setLineWidth(0.5)
            gc.strokeEllipse(in: CGRect(x: coinX, y: coinY, width: coinSize, height: coinSize))

            // Price text
            let priceStr: String
            if cost >= 1000 {
                priceStr = String(format: "%.0fk", cost / 1000)
            } else {
                priceStr = String(format: "%.0f", cost)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Theme.headlineUIFont(size: 8),
                .foregroundColor: Theme.skTextPrimary
            ]
            let nsStr = priceStr as NSString
            let textSize = nsStr.size(withAttributes: attrs)
            let textX = w / 2 + 2
            let textY = 4 + IsometricConstants.tileHeight / 2 - textSize.height / 2
            nsStr.draw(at: CGPoint(x: textX, y: textY), withAttributes: attrs)
        }
        return SKTexture(image: image)
    }

    // MARK: - Equipment Detail Helpers

    /// Interpolate a point on the left face at vertical fraction `f` (0=top, 1=bottom)
    /// and horizontal fraction `t` (0=left edge, 1=center spine).
    private static func leftFacePoint(f: CGFloat, t: CGFloat,
                                      baseY: CGFloat, hh: CGFloat,
                                      totalH: CGFloat, hw: CGFloat) -> CGPoint {
        // Left face corners: topLeft(0, baseY), topRight(hw, baseY+hh),
        //                    bottomRight(hw, totalH), bottomLeft(0, totalH-hh)
        let leftTop  = CGPoint(x: 0, y: baseY)
        let rightTop = CGPoint(x: hw, y: baseY + hh)
        let rightBot = CGPoint(x: hw, y: totalH)
        let leftBot  = CGPoint(x: 0, y: totalH - hh)
        // Lerp left edge and right edge vertically, then lerp horizontally
        let le = CGPoint(x: leftTop.x + (leftBot.x - leftTop.x) * f,
                         y: leftTop.y + (leftBot.y - leftTop.y) * f)
        let re = CGPoint(x: rightTop.x + (rightBot.x - rightTop.x) * f,
                         y: rightTop.y + (rightBot.y - rightTop.y) * f)
        return CGPoint(x: le.x + (re.x - le.x) * t,
                       y: le.y + (re.y - le.y) * t)
    }

    /// Interpolate a point on the right face at vertical fraction `f` (0=top, 1=bottom)
    /// and horizontal fraction `t` (0=center spine, 1=right edge).
    private static func rightFacePoint(f: CGFloat, t: CGFloat,
                                       baseY: CGFloat, hh: CGFloat,
                                       totalH: CGFloat, hw: CGFloat) -> CGPoint {
        let leftTop  = CGPoint(x: hw, y: baseY + hh)
        let rightTop = CGPoint(x: hw * 2, y: baseY)
        let rightBot = CGPoint(x: hw * 2, y: totalH - hh)
        let leftBot  = CGPoint(x: hw, y: totalH)
        let le = CGPoint(x: leftTop.x + (leftBot.x - leftTop.x) * f,
                         y: leftTop.y + (leftBot.y - leftTop.y) * f)
        let re = CGPoint(x: rightTop.x + (rightBot.x - rightTop.x) * f,
                         y: rightTop.y + (rightBot.y - rightTop.y) * f)
        return CGPoint(x: le.x + (re.x - le.x) * t,
                       y: le.y + (re.y - le.y) * t)
    }

    /// Interpolate a point on the top face at fractions `fx` (left-to-right) and `fy` (back-to-front).
    private static func topFacePoint(fx: CGFloat, fy: CGFloat,
                                     baseY: CGFloat, hh: CGFloat, hw: CGFloat) -> CGPoint {
        // Top face: top(hw, baseY-hh), right(2*hw, baseY), bottom(hw, baseY+hh), left(0, baseY)
        let topPt    = CGPoint(x: hw, y: baseY - hh)
        let rightPt  = CGPoint(x: hw * 2, y: baseY)
        let bottomPt = CGPoint(x: hw, y: baseY + hh)
        let leftPt   = CGPoint(x: 0, y: baseY)
        // Bilinear interpolation on the diamond
        let leftEdge  = CGPoint(x: topPt.x + (leftPt.x - topPt.x) * fx,
                                y: topPt.y + (leftPt.y - topPt.y) * fx)
        let rightEdge = CGPoint(x: topPt.x + (rightPt.x - topPt.x) * fx,
                                y: topPt.y + (rightPt.y - topPt.y) * fx)
        // Wait — diamond interpolation needs proper bilinear. Use parametric approach:
        // Point = (1-fx)*(1-fy)*top + fx*(1-fy)*left + (1-fx)*fy*right + fx*fy*bottom
        let x = (1 - fx) * (1 - fy) * topPt.x + fx * (1 - fy) * leftPt.x +
                (1 - fx) * fy * rightPt.x + fx * fy * bottomPt.x
        let y = (1 - fx) * (1 - fy) * topPt.y + fx * (1 - fy) * leftPt.y +
                (1 - fx) * fy * rightPt.y + fx * fy * bottomPt.y
        return CGPoint(x: x, y: y)
    }

    // MARK: Rack Details

    private static func drawRackDetails(gc: CGContext, type: EquipmentType, status: EquipmentStatus,
                                        baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                        totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier
        let lineColor = UIColor(red: 0.35, green: 0.30, blue: 0.25, alpha: 0.3)

        // Left face: horizontal shelf dividers
        let shelfCount = tier  // 1, 2, or 3 shelves
        gc.setStrokeColor(lineColor.cgColor)
        gc.setLineWidth(0.75)
        for i in 1...shelfCount {
            let f = CGFloat(i) / CGFloat(shelfCount + 1)
            let p0 = leftFacePoint(f: f, t: 0.05, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = leftFacePoint(f: f, t: 0.95, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0)
            gc.addLine(to: p1)
        }
        gc.strokePath()

        // Left face: LED dots in each bay
        let ledColor: UIColor
        switch status {
        case .normal: ledColor = Theme.skPositive
        case .warning: ledColor = Theme.skWarning
        case .critical, .offline: ledColor = Theme.skCritical
        }
        gc.setFillColor(ledColor.cgColor)
        let ledSize: CGFloat = 2.5
        for i in 0...shelfCount {
            let f = (CGFloat(i) + 0.5) / CGFloat(shelfCount + 1)
            let p = leftFacePoint(f: f, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.fillEllipse(in: CGRect(x: p.x - ledSize / 2, y: p.y - ledSize / 2,
                                      width: ledSize, height: ledSize))
        }

        // Right face: ventilation slit lines
        let ventCount = 1 + tier  // 2, 3, or 4 vents
        gc.setStrokeColor(UIColor(red: 0.30, green: 0.28, blue: 0.22, alpha: 0.2).cgColor)
        gc.setLineWidth(0.5)
        for i in 1...ventCount {
            let f = CGFloat(i) / CGFloat(ventCount + 1)
            let p0 = rightFacePoint(f: f, t: 0.3, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = rightFacePoint(f: f, t: 0.85, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0)
            gc.addLine(to: p1)
        }
        gc.strokePath()
    }

    // MARK: Cooling Details

    private static func drawCoolingDetails(gc: CGContext, type: EquipmentType,
                                           baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                           totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier
        let detailColor = UIColor(red: 0.35, green: 0.45, blue: 0.40, alpha: 0.4)

        // Top face: fan circle(s)
        let fanCount = tier == 3 ? 2 : 1
        for fi in 0..<fanCount {
            let cx: CGFloat
            let cy: CGFloat
            if fanCount == 1 {
                let center = topFacePoint(fx: 0.5, fy: 0.5, baseY: baseY, hh: hh, hw: hw)
                cx = center.x; cy = center.y
            } else {
                // Two fans: left and right of center
                let offset: CGFloat = fi == 0 ? 0.35 : 0.65
                let center = topFacePoint(fx: 0.5, fy: offset, baseY: baseY, hh: hh, hw: hw)
                cx = center.x; cy = center.y
            }
            let fanRadius: CGFloat = fanCount == 1 ? min(hh * 0.5, hw * 0.2) : min(hh * 0.35, hw * 0.15)

            // Fan circle (isometric — draw as ellipse squashed vertically)
            gc.setStrokeColor(detailColor.cgColor)
            gc.setLineWidth(0.75)
            let ellipseRect = CGRect(x: cx - fanRadius, y: cy - fanRadius * 0.55,
                                     width: fanRadius * 2, height: fanRadius * 1.1)
            gc.strokeEllipse(in: ellipseRect)

            // Hub dot
            gc.setFillColor(detailColor.cgColor)
            let hubR: CGFloat = 1.5
            gc.fillEllipse(in: CGRect(x: cx - hubR, y: cy - hubR, width: hubR * 2, height: hubR * 2))

            // Blade cross
            gc.setLineWidth(0.5)
            gc.move(to: CGPoint(x: cx - fanRadius * 0.6, y: cy))
            gc.addLine(to: CGPoint(x: cx + fanRadius * 0.6, y: cy))
            gc.move(to: CGPoint(x: cx, y: cy - fanRadius * 0.35))
            gc.addLine(to: CGPoint(x: cx, y: cy + fanRadius * 0.35))
            gc.strokePath()
        }

        // Left face: grille lines
        let grilleCount = 2 + tier  // 3, 4, or 5
        gc.setStrokeColor(detailColor.cgColor)
        gc.setLineWidth(0.5)
        for i in 1...grilleCount {
            let f = CGFloat(i) / CGFloat(grilleCount + 1)
            let p0 = leftFacePoint(f: f, t: 0.1, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = leftFacePoint(f: f, t: 0.9, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0)
            gc.addLine(to: p1)
        }
        gc.strokePath()
    }

    // MARK: Power Details

    private static func drawPowerDetails(gc: CGContext, type: EquipmentType,
                                         baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                         totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier
        let detailColor = UIColor(red: 0.55, green: 0.42, blue: 0.20, alpha: 0.5)

        // Top face: lightning bolt zigzag
        let boltStart = topFacePoint(fx: 0.35, fy: 0.35, baseY: baseY, hh: hh, hw: hw)
        let boltMid1  = topFacePoint(fx: 0.55, fy: 0.50, baseY: baseY, hh: hh, hw: hw)
        let boltMid2  = topFacePoint(fx: 0.40, fy: 0.55, baseY: baseY, hh: hh, hw: hw)
        let boltEnd   = topFacePoint(fx: 0.65, fy: 0.70, baseY: baseY, hh: hh, hw: hw)
        gc.setStrokeColor(detailColor.cgColor)
        gc.setLineWidth(1.0)
        gc.move(to: boltStart)
        gc.addLine(to: boltMid1)
        gc.addLine(to: boltMid2)
        gc.addLine(to: boltEnd)
        gc.strokePath()

        // Left face: recessed panel rectangle
        let panelTL = leftFacePoint(f: 0.15, t: 0.15, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelTR = leftFacePoint(f: 0.15, t: 0.85, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBR = leftFacePoint(f: 0.65, t: 0.85, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBL = leftFacePoint(f: 0.65, t: 0.15, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setStrokeColor(detailColor.cgColor)
        gc.setLineWidth(0.5)
        gc.move(to: panelTL)
        gc.addLine(to: panelTR)
        gc.addLine(to: panelBR)
        gc.addLine(to: panelBL)
        gc.closePath()
        gc.strokePath()

        // Left face: gauge circle inside panel
        let gaugeCenter = leftFacePoint(f: 0.35, t: 0.5, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let gaugeR: CGFloat = 3.0
        gc.strokeEllipse(in: CGRect(x: gaugeCenter.x - gaugeR, y: gaugeCenter.y - gaugeR,
                                    width: gaugeR * 2, height: gaugeR * 2))
        // Needle
        gc.move(to: gaugeCenter)
        gc.addLine(to: CGPoint(x: gaugeCenter.x + gaugeR * 0.7, y: gaugeCenter.y - gaugeR * 0.5))
        gc.strokePath()

        // Tier 2+: battery indicator bar below gauge
        if tier >= 2 {
            let barLeft  = leftFacePoint(f: 0.52, t: 0.25, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let barRight = leftFacePoint(f: 0.52, t: 0.75, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            // Bar outline
            gc.setStrokeColor(detailColor.cgColor)
            gc.setLineWidth(0.5)
            let barH: CGFloat = 2.5
            gc.stroke(CGRect(x: barLeft.x, y: barLeft.y, width: barRight.x - barLeft.x, height: barH))
            // Fill ~70%
            gc.setFillColor(Theme.skPositive.withAlphaComponent(0.5).cgColor)
            gc.fill(CGRect(x: barLeft.x + 0.5, y: barLeft.y + 0.5,
                           width: (barRight.x - barLeft.x - 1) * 0.7, height: barH - 1))
        }

        // Tier 3: second indicator + right-face vent lines
        if tier >= 3 {
            let bar2Left  = leftFacePoint(f: 0.58, t: 0.25, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let bar2Right = leftFacePoint(f: 0.58, t: 0.75, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.setStrokeColor(detailColor.cgColor)
            gc.stroke(CGRect(x: bar2Left.x, y: bar2Left.y,
                             width: bar2Right.x - bar2Left.x, height: 2.5))
            gc.setFillColor(Theme.skWarning.withAlphaComponent(0.5).cgColor)
            gc.fill(CGRect(x: bar2Left.x + 0.5, y: bar2Left.y + 0.5,
                           width: (bar2Right.x - bar2Left.x - 1) * 0.5, height: 1.5))

            // Right face vents
            gc.setStrokeColor(UIColor(red: 0.50, green: 0.38, blue: 0.18, alpha: 0.25).cgColor)
            gc.setLineWidth(0.5)
            for i in 1...3 {
                let f = CGFloat(i) / 4.0
                let p0 = rightFacePoint(f: f, t: 0.25, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                let p1 = rightFacePoint(f: f, t: 0.80, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                gc.move(to: p0)
                gc.addLine(to: p1)
            }
            gc.strokePath()
        }
    }

    // MARK: Network Details

    private static func drawNetworkDetails(gc: CGContext, type: EquipmentType,
                                           baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                           totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier
        let detailColor = UIColor(red: 0.45, green: 0.35, blue: 0.28, alpha: 0.4)

        // Left face: port grid (small rectangles)
        let rows = tier  // 1, 2, or 3 rows
        let cols = 3
        let portW: CGFloat = 2.0
        let portH: CGFloat = 1.5
        gc.setFillColor(detailColor.cgColor)
        for r in 0..<rows {
            let fY = 0.25 + CGFloat(r) * 0.22
            for c in 0..<cols {
                let fX = 0.2 + CGFloat(c) * 0.25
                let p = leftFacePoint(f: fY, t: fX, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                gc.fill(CGRect(x: p.x - portW / 2, y: p.y - portH / 2, width: portW, height: portH))
            }
        }

        // One port highlighted green (active link)
        let activePort = leftFacePoint(f: 0.25, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(Theme.skPositive.withAlphaComponent(0.7).cgColor)
        gc.fill(CGRect(x: activePort.x - portW / 2, y: activePort.y - portH / 2,
                       width: portW, height: portH))

        // Status LED dot
        let ledPos = leftFacePoint(f: 0.7, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(Theme.skPositive.cgColor)
        gc.fillEllipse(in: CGRect(x: ledPos.x - 1.5, y: ledPos.y - 1.5, width: 3, height: 3))

        // Top face: antenna stub(s) for tier 2+
        if tier >= 2 {
            let antennaCount = tier == 3 ? 2 : 1
            for ai in 0..<antennaCount {
                let fy: CGFloat = antennaCount == 1 ? 0.5 : (ai == 0 ? 0.35 : 0.65)
                let antennaBase = topFacePoint(fx: 0.3, fy: fy, baseY: baseY, hh: hh, hw: hw)
                let antennaTop = CGPoint(x: antennaBase.x, y: antennaBase.y - 5)
                gc.setStrokeColor(detailColor.cgColor)
                gc.setLineWidth(1.0)
                gc.move(to: antennaBase)
                gc.addLine(to: antennaTop)
                gc.strokePath()
                // Ball tip
                gc.setFillColor(detailColor.cgColor)
                gc.fillEllipse(in: CGRect(x: antennaTop.x - 1.5, y: antennaTop.y - 1.5,
                                          width: 3, height: 3))
            }
        }
    }

    // MARK: Tool Icon

    /// 48x48 tool icon texture for drag-to-fix mechanic.
    static func toolIconTexture(tool: IncidentTool) -> SKTexture {
        let size: CGFloat = 48
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Warm rounded background circle
            gc.setFillColor(Theme.skCardBackground.withAlphaComponent(0.9).cgColor)
            gc.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
            gc.setStrokeColor(Theme.skAccent.withAlphaComponent(0.6).cgColor)
            gc.setLineWidth(2)
            gc.strokeEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))

            // Draw tool symbol using SF Symbol-like rendering
            let toolColor: UIColor
            let symbol: String
            switch tool {
            case .fireExtinguisher:
                toolColor = Theme.skCritical
                symbol = "\u{1F9EF}"  // fire extinguisher emoji fallback
            case .shield:
                toolColor = UIColor(red: 0.4, green: 0.5, blue: 0.75, alpha: 1)
                symbol = "\u{1F6E1}"
            case .wrench:
                toolColor = Theme.skAccentGold
                symbol = "\u{1F527}"
            case .cablePlug:
                toolColor = Theme.skAccent
                symbol = "\u{1F50C}"
            }

            // Use SF Symbol image if available
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            if let sfImage = UIImage(systemName: tool.icon, withConfiguration: config) {
                let tinted = sfImage.withTintColor(toolColor, renderingMode: .alwaysOriginal)
                let imgSize = tinted.size
                let imgRect = CGRect(
                    x: (size - imgSize.width) / 2,
                    y: (size - imgSize.height) / 2,
                    width: imgSize.width,
                    height: imgSize.height
                )
                tinted.draw(in: imgRect)
            } else {
                // Fallback: draw emoji
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20)
                ]
                let ns = symbol as NSString
                let ts = ns.size(withAttributes: attrs)
                ns.draw(at: CGPoint(x: (size - ts.width) / 2, y: (size - ts.height) / 2), withAttributes: attrs)
            }
        }
        return SKTexture(image: image)
    }
}

// MARK: - UIColor Helpers

extension UIColor {
    func lighter(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: min(r + amount, 1),
            green: min(g + amount, 1),
            blue: min(b + amount, 1),
            alpha: a
        )
    }

    func darker(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: max(r - amount, 0),
            green: max(g - amount, 0),
            blue: max(b - amount, 0),
            alpha: a
        )
    }
}
