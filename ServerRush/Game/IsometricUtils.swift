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

            // Bold edge outlines (darker, more defined)
            gc.setStrokeColor(UIColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 0.45).cgColor)
            gc.setLineWidth(1.0)
            gc.addPath(top); gc.strokePath()
            gc.addPath(left); gc.strokePath()
            gc.addPath(right); gc.strokePath()

            // Inner highlight on top face (specular gloss)
            gc.setStrokeColor(UIColor(white: 1.0, alpha: 0.15).cgColor)
            gc.setLineWidth(0.5)
            gc.addPath(top); gc.strokePath()
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

    /// Cozy green "buy land" diamond with coin icon and price text (Hay Day-style).
    static func expansionTileTexture(cost: Double) -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight + 14 // extra height for price label
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Grassy diamond
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w / 2, y: 4))
            path.addLine(to: CGPoint(x: w, y: 4 + IsometricConstants.tileHeight / 2))
            path.addLine(to: CGPoint(x: w / 2, y: 4 + IsometricConstants.tileHeight))
            path.addLine(to: CGPoint(x: 0, y: 4 + IsometricConstants.tileHeight / 2))
            path.closeSubpath()

            // Soft green grass fill (inviting, not locked-looking)
            gc.setFillColor(UIColor(red: 0.49, green: 0.68, blue: 0.38, alpha: 0.25).cgColor)
            gc.addPath(path); gc.fillPath()

            // Subtle grass texture strokes inside
            gc.saveGState()
            gc.addPath(path); gc.clip()
            gc.setStrokeColor(UIColor(red: 0.45, green: 0.62, blue: 0.35, alpha: 0.15).cgColor)
            gc.setLineWidth(0.8)
            let step: CGFloat = 5
            var y: CGFloat = 0
            while y < h {
                gc.move(to: CGPoint(x: 0, y: y))
                gc.addLine(to: CGPoint(x: w, y: y + CGFloat.random(in: -0.5...0.5)))
                y += step
            }
            gc.strokePath()
            gc.restoreGState()

            // Warm dashed border (inviting "expand here" feel)
            gc.setStrokeColor(UIColor(red: 0.49, green: 0.68, blue: 0.38, alpha: 0.55).cgColor)
            gc.setLineWidth(1.2)
            gc.setLineDash(phase: 0, lengths: [4, 3])
            gc.addPath(path); gc.strokePath()

            // Coin icon (warm gold circle with border)
            let coinSize: CGFloat = 9
            let coinX = w / 2 - coinSize - 1
            let coinY = 4 + IsometricConstants.tileHeight / 2 - coinSize / 2
            gc.setLineDash(phase: 0, lengths: [])
            gc.setFillColor(Theme.skAccentGold.cgColor)
            gc.fillEllipse(in: CGRect(x: coinX, y: coinY, width: coinSize, height: coinSize))
            // Coin dollar sign highlight
            gc.setFillColor(UIColor(red: 0.95, green: 0.85, blue: 0.60, alpha: 0.6).cgColor)
            gc.fillEllipse(in: CGRect(x: coinX + 2, y: coinY + 1.5, width: 3, height: 3))
            gc.setStrokeColor(Theme.skWoodTone.cgColor)
            gc.setLineWidth(0.8)
            gc.strokeEllipse(in: CGRect(x: coinX, y: coinY, width: coinSize, height: coinSize))

            // Price text
            let priceStr: String
            if cost >= 1000 {
                priceStr = String(format: "%.0fk", cost / 1000)
            } else {
                priceStr = String(format: "%.0f", cost)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Theme.headlineUIFont(size: 9),
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

        // Left face: accent stripe at top edge
        let stripeColor = UIColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 0.7)
        let sTopL = leftFacePoint(f: 0.0, t: 0.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let sTopR = leftFacePoint(f: 0.0, t: 1.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let sBotR = leftFacePoint(f: 0.08, t: 1.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let sBotL = leftFacePoint(f: 0.08, t: 0.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(stripeColor.cgColor)
        gc.move(to: sTopL); gc.addLine(to: sTopR); gc.addLine(to: sBotR); gc.addLine(to: sBotL)
        gc.closePath(); gc.fillPath()

        // Left face: filled server bay panels (alternating colors)
        let shelfCount = tier + 1
        let bayColors: [UIColor] = [
            UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 0.45),
            UIColor(red: 0.25, green: 0.22, blue: 0.30, alpha: 0.35)
        ]
        for i in 0..<shelfCount {
            let fTop = 0.1 + CGFloat(i) * (0.85 / CGFloat(shelfCount))
            let fBot = fTop + (0.78 / CGFloat(shelfCount))
            let pTL = leftFacePoint(f: fTop, t: 0.08, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let pTR = leftFacePoint(f: fTop, t: 0.92, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let pBR = leftFacePoint(f: fBot, t: 0.92, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let pBL = leftFacePoint(f: fBot, t: 0.08, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.setFillColor(bayColors[i % 2].cgColor)
            gc.move(to: pTL); gc.addLine(to: pTR); gc.addLine(to: pBR); gc.addLine(to: pBL)
            gc.closePath(); gc.fillPath()
        }

        // Left face: shelf divider lines (bold)
        gc.setStrokeColor(UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 0.5).cgColor)
        gc.setLineWidth(1.0)
        for i in 1...shelfCount {
            let f = 0.1 + CGFloat(i) * (0.85 / CGFloat(shelfCount + 1))
            let p0 = leftFacePoint(f: f, t: 0.05, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = leftFacePoint(f: f, t: 0.95, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0); gc.addLine(to: p1)
        }
        gc.strokePath()

        // Left face: LED dots with glow rings
        let ledColor: UIColor
        switch status {
        case .normal: ledColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
        case .warning: ledColor = UIColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1)
        case .critical, .offline: ledColor = UIColor(red: 1.0, green: 0.2, blue: 0.15, alpha: 1)
        }
        let ledSize: CGFloat = 3.0
        for i in 0..<shelfCount {
            let f = 0.1 + (CGFloat(i) + 0.5) * (0.85 / CGFloat(shelfCount))
            let p = leftFacePoint(f: f, t: 0.18, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            // Glow ring
            gc.setFillColor(ledColor.withAlphaComponent(0.25).cgColor)
            gc.fillEllipse(in: CGRect(x: p.x - ledSize, y: p.y - ledSize,
                                      width: ledSize * 2, height: ledSize * 2))
            // Core LED
            gc.setFillColor(ledColor.cgColor)
            gc.fillEllipse(in: CGRect(x: p.x - ledSize / 2, y: p.y - ledSize / 2,
                                      width: ledSize, height: ledSize))
            // Second LED (activity) — amber
            if tier >= 2 {
                let p2 = leftFacePoint(f: f, t: 0.30, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                gc.setFillColor(UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.8).cgColor)
                gc.fillEllipse(in: CGRect(x: p2.x - 1.5, y: p2.y - 1.5, width: 3, height: 3))
            }
        }

        // Right face: bold colored ventilation grille
        let ventCount = 2 + tier
        gc.setStrokeColor(UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.35).cgColor)
        gc.setLineWidth(0.8)
        for i in 1...ventCount {
            let f = CGFloat(i) / CGFloat(ventCount + 1)
            let p0 = rightFacePoint(f: f, t: 0.15, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = rightFacePoint(f: f, t: 0.90, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0); gc.addLine(to: p1)
        }
        gc.strokePath()

        // Right face: accent stripe at top
        let rsTopL = rightFacePoint(f: 0.0, t: 0.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let rsTopR = rightFacePoint(f: 0.0, t: 1.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let rsBotR = rightFacePoint(f: 0.08, t: 1.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let rsBotL = rightFacePoint(f: 0.08, t: 0.0, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(stripeColor.withAlphaComponent(0.5).cgColor)
        gc.move(to: rsTopL); gc.addLine(to: rsTopR); gc.addLine(to: rsBotR); gc.addLine(to: rsBotL)
        gc.closePath(); gc.fillPath()

        // Top face: colored brand plate
        if tier >= 2 {
            let plateTL = topFacePoint(fx: 0.3, fy: 0.3, baseY: baseY, hh: hh, hw: hw)
            let plateTR = topFacePoint(fx: 0.3, fy: 0.7, baseY: baseY, hh: hh, hw: hw)
            let plateBR = topFacePoint(fx: 0.7, fy: 0.7, baseY: baseY, hh: hh, hw: hw)
            let plateBL = topFacePoint(fx: 0.7, fy: 0.3, baseY: baseY, hh: hh, hw: hw)
            gc.setFillColor(UIColor(red: 0.90, green: 0.35, blue: 0.30, alpha: 0.35).cgColor)
            gc.move(to: plateTL); gc.addLine(to: plateTR); gc.addLine(to: plateBR); gc.addLine(to: plateBL)
            gc.closePath(); gc.fillPath()
        }
    }

    // MARK: Cooling Details

    private static func drawCoolingDetails(gc: CGContext, type: EquipmentType,
                                           baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                           totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier

        // Top face: filled fan background circle(s) with colored blades
        let fanCount = tier >= 2 ? 2 : 1
        for fi in 0..<fanCount {
            let cx: CGFloat
            let cy: CGFloat
            if fanCount == 1 {
                let center = topFacePoint(fx: 0.5, fy: 0.5, baseY: baseY, hh: hh, hw: hw)
                cx = center.x; cy = center.y
            } else {
                let offset: CGFloat = fi == 0 ? 0.35 : 0.65
                let center = topFacePoint(fx: 0.5, fy: offset, baseY: baseY, hh: hh, hw: hw)
                cx = center.x; cy = center.y
            }
            let fanRadius: CGFloat = fanCount == 1 ? min(hh * 0.55, hw * 0.22) : min(hh * 0.4, hw * 0.16)

            // Fan housing fill (dark)
            let ellipseRect = CGRect(x: cx - fanRadius, y: cy - fanRadius * 0.55,
                                     width: fanRadius * 2, height: fanRadius * 1.1)
            gc.setFillColor(UIColor(red: 0.15, green: 0.25, blue: 0.30, alpha: 0.5).cgColor)
            gc.fillEllipse(in: ellipseRect)

            // Fan rim (bright teal)
            gc.setStrokeColor(UIColor(red: 0.2, green: 0.85, blue: 0.90, alpha: 0.7).cgColor)
            gc.setLineWidth(1.2)
            gc.strokeEllipse(in: ellipseRect)

            // Colored blade cross (4 blades)
            gc.setStrokeColor(UIColor(red: 0.55, green: 0.88, blue: 0.92, alpha: 0.8).cgColor)
            gc.setLineWidth(1.0)
            gc.move(to: CGPoint(x: cx - fanRadius * 0.65, y: cy))
            gc.addLine(to: CGPoint(x: cx + fanRadius * 0.65, y: cy))
            gc.move(to: CGPoint(x: cx, y: cy - fanRadius * 0.4))
            gc.addLine(to: CGPoint(x: cx, y: cy + fanRadius * 0.4))
            // Diagonal blades
            gc.move(to: CGPoint(x: cx - fanRadius * 0.45, y: cy - fanRadius * 0.28))
            gc.addLine(to: CGPoint(x: cx + fanRadius * 0.45, y: cy + fanRadius * 0.28))
            gc.move(to: CGPoint(x: cx - fanRadius * 0.45, y: cy + fanRadius * 0.28))
            gc.addLine(to: CGPoint(x: cx + fanRadius * 0.45, y: cy - fanRadius * 0.28))
            gc.strokePath()

            // Hub dot (bright center)
            gc.setFillColor(UIColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 0.9).cgColor)
            let hubR: CGFloat = 2.0
            gc.fillEllipse(in: CGRect(x: cx - hubR, y: cy - hubR, width: hubR * 2, height: hubR * 2))
        }

        // Left face: colored horizontal grille bars (filled, not just lines)
        let grilleCount = 3 + tier
        for i in 1...grilleCount {
            let f = CGFloat(i) / CGFloat(grilleCount + 1)
            let p0 = leftFacePoint(f: f, t: 0.08, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = leftFacePoint(f: f, t: 0.92, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p0b = leftFacePoint(f: f + 0.035, t: 0.08, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1b = leftFacePoint(f: f + 0.035, t: 0.92, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            // Alternating teal/dark grille bars
            let barColor = i % 2 == 0
                ? UIColor(red: 0.20, green: 0.50, blue: 0.55, alpha: 0.45)
                : UIColor(red: 0.15, green: 0.35, blue: 0.40, alpha: 0.35)
            gc.setFillColor(barColor.cgColor)
            gc.move(to: p0); gc.addLine(to: p1); gc.addLine(to: p1b); gc.addLine(to: p0b)
            gc.closePath(); gc.fillPath()
        }

        // Left face: frost/ice accent dots (maximalist decorative)
        if tier >= 2 {
            let dotPositions: [(CGFloat, CGFloat)] = [(0.2, 0.15), (0.5, 0.80), (0.75, 0.50)]
            gc.setFillColor(UIColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 0.5).cgColor)
            for (df, dt) in dotPositions {
                let dp = leftFacePoint(f: df, t: dt, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                gc.fillEllipse(in: CGRect(x: dp.x - 1.5, y: dp.y - 1.5, width: 3, height: 3))
            }
        }

        // Right face: colored vent slits
        let ventCount = 2 + tier
        gc.setStrokeColor(UIColor(red: 0.18, green: 0.42, blue: 0.48, alpha: 0.4).cgColor)
        gc.setLineWidth(0.8)
        for i in 1...ventCount {
            let f = CGFloat(i) / CGFloat(ventCount + 1)
            let p0 = rightFacePoint(f: f, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let p1 = rightFacePoint(f: f, t: 0.85, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: p0); gc.addLine(to: p1)
        }
        gc.strokePath()
    }

    // MARK: Power Details

    private static func drawPowerDetails(gc: CGContext, type: EquipmentType,
                                         baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                         totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier

        // Top face: filled lightning bolt (bright yellow)
        let boltPath = CGMutablePath()
        let b0 = topFacePoint(fx: 0.25, fy: 0.30, baseY: baseY, hh: hh, hw: hw)
        let b1 = topFacePoint(fx: 0.50, fy: 0.38, baseY: baseY, hh: hh, hw: hw)
        let b2 = topFacePoint(fx: 0.42, fy: 0.48, baseY: baseY, hh: hh, hw: hw)
        let b3 = topFacePoint(fx: 0.68, fy: 0.58, baseY: baseY, hh: hh, hw: hw)
        let b4 = topFacePoint(fx: 0.45, fy: 0.52, baseY: baseY, hh: hh, hw: hw)
        let b5 = topFacePoint(fx: 0.55, fy: 0.65, baseY: baseY, hh: hh, hw: hw)
        let b6 = topFacePoint(fx: 0.75, fy: 0.72, baseY: baseY, hh: hh, hw: hw)
        boltPath.move(to: b0); boltPath.addLine(to: b1); boltPath.addLine(to: b2)
        boltPath.addLine(to: b3); boltPath.addLine(to: b4); boltPath.addLine(to: b5)
        boltPath.addLine(to: b6)
        // Glow
        gc.setStrokeColor(UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 0.4).cgColor)
        gc.setLineWidth(3.0)
        gc.addPath(boltPath); gc.strokePath()
        // Bolt
        gc.setStrokeColor(UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.9).cgColor)
        gc.setLineWidth(1.5)
        gc.addPath(boltPath); gc.strokePath()

        // Top face: hazard stripe border (yellow/dark chevrons)
        if tier >= 2 {
            let chevronColor = UIColor(red: 0.15, green: 0.12, blue: 0.05, alpha: 0.3)
            gc.setFillColor(chevronColor.cgColor)
            for i in 0..<4 {
                let fx0: CGFloat = CGFloat(i) * 0.25 + 0.05
                let fx1 = fx0 + 0.12
                let pA = topFacePoint(fx: fx0, fy: 0.05, baseY: baseY, hh: hh, hw: hw)
                let pB = topFacePoint(fx: fx1, fy: 0.05, baseY: baseY, hh: hh, hw: hw)
                let pC = topFacePoint(fx: fx1, fy: 0.15, baseY: baseY, hh: hh, hw: hw)
                let pD = topFacePoint(fx: fx0, fy: 0.15, baseY: baseY, hh: hh, hw: hw)
                gc.move(to: pA); gc.addLine(to: pB); gc.addLine(to: pC); gc.addLine(to: pD)
                gc.closePath(); gc.fillPath()
            }
        }

        // Left face: filled recessed panel
        let panelTL = leftFacePoint(f: 0.10, t: 0.10, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelTR = leftFacePoint(f: 0.10, t: 0.90, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBR = leftFacePoint(f: 0.60, t: 0.90, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBL = leftFacePoint(f: 0.60, t: 0.10, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(UIColor(red: 0.20, green: 0.18, blue: 0.10, alpha: 0.35).cgColor)
        gc.move(to: panelTL); gc.addLine(to: panelTR); gc.addLine(to: panelBR); gc.addLine(to: panelBL)
        gc.closePath(); gc.fillPath()
        // Panel border
        gc.setStrokeColor(UIColor(red: 0.70, green: 0.55, blue: 0.10, alpha: 0.5).cgColor)
        gc.setLineWidth(0.8)
        gc.move(to: panelTL); gc.addLine(to: panelTR); gc.addLine(to: panelBR); gc.addLine(to: panelBL)
        gc.closePath(); gc.strokePath()

        // Left face: filled gauge with colored dial
        let gaugeCenter = leftFacePoint(f: 0.30, t: 0.50, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let gaugeR: CGFloat = 3.5
        // Gauge background
        gc.setFillColor(UIColor(red: 0.95, green: 0.92, blue: 0.80, alpha: 0.7).cgColor)
        gc.fillEllipse(in: CGRect(x: gaugeCenter.x - gaugeR, y: gaugeCenter.y - gaugeR,
                                  width: gaugeR * 2, height: gaugeR * 2))
        // Gauge rim
        gc.setStrokeColor(UIColor(red: 0.65, green: 0.50, blue: 0.15, alpha: 0.8).cgColor)
        gc.setLineWidth(1.0)
        gc.strokeEllipse(in: CGRect(x: gaugeCenter.x - gaugeR, y: gaugeCenter.y - gaugeR,
                                    width: gaugeR * 2, height: gaugeR * 2))
        // Red needle
        gc.setStrokeColor(UIColor(red: 0.85, green: 0.15, blue: 0.10, alpha: 0.9).cgColor)
        gc.setLineWidth(0.8)
        gc.move(to: gaugeCenter)
        gc.addLine(to: CGPoint(x: gaugeCenter.x + gaugeR * 0.75, y: gaugeCenter.y - gaugeR * 0.5))
        gc.strokePath()

        // Battery bars (bold, colorful)
        let barColors: [(UIColor, CGFloat)] = [
            (UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 0.7), 0.80),  // green, 80%
            (UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.7), 0.55),  // amber, 55%
            (UIColor(red: 0.9, green: 0.25, blue: 0.2, alpha: 0.7), 0.30),  // red, 30%
        ]
        let barCount = min(tier, barColors.count)
        for bi in 0..<barCount {
            let barF = 0.45 + CGFloat(bi) * 0.12
            let barLeft  = leftFacePoint(f: barF, t: 0.18, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let barRight = leftFacePoint(f: barF, t: 0.82, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let barH: CGFloat = 3.0
            // Background
            gc.setFillColor(UIColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 0.3).cgColor)
            gc.fill(CGRect(x: barLeft.x, y: barLeft.y, width: barRight.x - barLeft.x, height: barH))
            // Fill
            gc.setFillColor(barColors[bi].0.cgColor)
            gc.fill(CGRect(x: barLeft.x + 0.5, y: barLeft.y + 0.5,
                           width: (barRight.x - barLeft.x - 1) * barColors[bi].1, height: barH - 1))
            // Border
            gc.setStrokeColor(UIColor(red: 0.50, green: 0.40, blue: 0.10, alpha: 0.4).cgColor)
            gc.setLineWidth(0.5)
            gc.stroke(CGRect(x: barLeft.x, y: barLeft.y, width: barRight.x - barLeft.x, height: barH))
        }

        // Right face: warning stripe pattern
        gc.setFillColor(UIColor(red: 0.15, green: 0.12, blue: 0.05, alpha: 0.2).cgColor)
        for i in 0..<3 {
            let f0 = 0.15 + CGFloat(i) * 0.28
            let f1 = f0 + 0.14
            let rTL = rightFacePoint(f: f0, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let rTR = rightFacePoint(f: f0, t: 0.8, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let rBR = rightFacePoint(f: f1, t: 0.8, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let rBL = rightFacePoint(f: f1, t: 0.2, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            gc.move(to: rTL); gc.addLine(to: rTR); gc.addLine(to: rBR); gc.addLine(to: rBL)
            gc.closePath(); gc.fillPath()
        }
    }

    // MARK: Network Details

    private static func drawNetworkDetails(gc: CGContext, type: EquipmentType,
                                           baseY: CGFloat, hh: CGFloat, hw: CGFloat,
                                           totalH: CGFloat, blockHeight: CGFloat) {
        let tier = type.tier

        // Left face: filled dark panel background
        let panelTL = leftFacePoint(f: 0.06, t: 0.06, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelTR = leftFacePoint(f: 0.06, t: 0.94, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBR = leftFacePoint(f: 0.80, t: 0.94, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        let panelBL = leftFacePoint(f: 0.80, t: 0.06, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
        gc.setFillColor(UIColor(red: 0.18, green: 0.12, blue: 0.22, alpha: 0.35).cgColor)
        gc.move(to: panelTL); gc.addLine(to: panelTR); gc.addLine(to: panelBR); gc.addLine(to: panelBL)
        gc.closePath(); gc.fillPath()

        // Left face: colorful port grid
        let rows = tier + 1
        let cols = 3
        let portW: CGFloat = 2.5
        let portH: CGFloat = 2.0
        let portColors: [UIColor] = [
            UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 0.8),   // green (active)
            UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 0.7),    // amber (standby)
            UIColor(red: 0.5, green: 0.35, blue: 0.65, alpha: 0.5),  // purple (idle)
        ]
        for r in 0..<rows {
            let fY = 0.12 + CGFloat(r) * (0.60 / CGFloat(rows))
            for c in 0..<cols {
                let fX = 0.18 + CGFloat(c) * 0.26
                let p = leftFacePoint(f: fY, t: fX, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
                // Port background
                gc.setFillColor(UIColor(red: 0.10, green: 0.08, blue: 0.15, alpha: 0.5).cgColor)
                gc.fill(CGRect(x: p.x - portW / 2 - 0.5, y: p.y - portH / 2 - 0.5,
                               width: portW + 1, height: portH + 1))
                // Port color
                let colorIdx = (r + c) % portColors.count
                gc.setFillColor(portColors[colorIdx].cgColor)
                gc.fill(CGRect(x: p.x - portW / 2, y: p.y - portH / 2, width: portW, height: portH))
            }
        }

        // Left face: status LEDs row (multiple colored dots)
        let ledColors: [UIColor] = [
            UIColor(red: 0.1, green: 0.9, blue: 0.2, alpha: 0.9),
            UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.9),
            UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.9),
        ]
        let ledCount = min(tier + 1, ledColors.count)
        for li in 0..<ledCount {
            let fX = 0.2 + CGFloat(li) * 0.25
            let p = leftFacePoint(f: 0.78, t: fX, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            // Glow
            gc.setFillColor(ledColors[li].withAlphaComponent(0.25).cgColor)
            gc.fillEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            // Dot
            gc.setFillColor(ledColors[li].cgColor)
            gc.fillEllipse(in: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
        }

        // Right face: signal wave arcs (decorative)
        let waveColor = UIColor(red: 0.55, green: 0.40, blue: 0.80, alpha: 0.35)
        gc.setStrokeColor(waveColor.cgColor)
        gc.setLineWidth(0.7)
        for i in 1...3 {
            let cx = rightFacePoint(f: 0.4, t: 0.5, baseY: baseY, hh: hh, totalH: totalH, hw: hw)
            let r = CGFloat(i) * 3.0
            gc.strokeEllipse(in: CGRect(x: cx.x - r, y: cx.y - r * 0.55,
                                        width: r * 2, height: r * 1.1))
        }

        // Top face: antenna stub(s) with colored tips
        let antennaCount = max(1, tier)
        for ai in 0..<antennaCount {
            let fy: CGFloat = antennaCount == 1 ? 0.5 : (ai == 0 ? 0.30 : (ai == 1 ? 0.60 : 0.50))
            let antennaBase = topFacePoint(fx: 0.25, fy: fy, baseY: baseY, hh: hh, hw: hw)
            let antennaTop = CGPoint(x: antennaBase.x, y: antennaBase.y - 6)
            // Antenna pole (bright)
            gc.setStrokeColor(UIColor(red: 0.65, green: 0.50, blue: 0.80, alpha: 0.8).cgColor)
            gc.setLineWidth(1.2)
            gc.move(to: antennaBase); gc.addLine(to: antennaTop); gc.strokePath()
            // Glowing tip
            let tipColor: UIColor = ai == 0
                ? UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.9)
                : UIColor(red: 0.9, green: 0.4, blue: 0.8, alpha: 0.9)
            gc.setFillColor(tipColor.withAlphaComponent(0.3).cgColor)
            gc.fillEllipse(in: CGRect(x: antennaTop.x - 3, y: antennaTop.y - 3, width: 6, height: 6))
            gc.setFillColor(tipColor.cgColor)
            gc.fillEllipse(in: CGRect(x: antennaTop.x - 1.8, y: antennaTop.y - 1.8, width: 3.6, height: 3.6))
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
