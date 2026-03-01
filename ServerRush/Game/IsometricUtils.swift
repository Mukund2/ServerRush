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

    /// Compute z-position for depth sorting. Tiles further from camera (higher col+row) render behind.
    static func depthForPosition(col: Int, row: Int, layer: CGFloat = 0) -> CGFloat {
        // Higher col+row means further back, so lower z. Layer offsets separate floor/objects/effects.
        return layer - CGFloat(col + row)
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

    // MARK: Floor Tile

    static func floorTileTexture() -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Diamond path
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w / 2, y: 0))           // top
            path.addLine(to: CGPoint(x: w, y: h / 2))        // right
            path.addLine(to: CGPoint(x: w / 2, y: h))        // bottom
            path.addLine(to: CGPoint(x: 0, y: h / 2))        // left
            path.closeSubpath()

            // Fill dark blue-gray
            gc.setFillColor(UIColor(red: 0.106, green: 0.157, blue: 0.220, alpha: 1).cgColor)
            gc.addPath(path)
            gc.fillPath()

            // Subtle grid border
            gc.setStrokeColor(UIColor(red: 0.18, green: 0.24, blue: 0.32, alpha: 1).cgColor)
            gc.setLineWidth(1)
            gc.addPath(path)
            gc.strokePath()
        }
        return SKTexture(image: image)
    }

    // MARK: Equipment Texture

    /// Generate an isometric block texture for equipment.
    /// Height varies by tier (1=short, 2=medium, 3=tall).
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

            // Vertical offset so base aligns with tile center
            let baseY = blockHeight

            // --- Top face (lighter) ---
            let top = CGMutablePath()
            top.move(to: CGPoint(x: hw, y: baseY - hh))
            top.addLine(to: CGPoint(x: w, y: baseY))
            top.addLine(to: CGPoint(x: hw, y: baseY + hh))
            top.addLine(to: CGPoint(x: 0, y: baseY))
            top.closeSubpath()

            gc.setFillColor(baseColor.lighter(by: 0.2).cgColor)
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

            gc.setFillColor(baseColor.darker(by: 0.25).cgColor)
            gc.addPath(right)
            gc.fillPath()

            // --- LED dots for racks ---
            if type.category == .rack {
                let ledColor: UIColor
                switch status {
                case .normal: ledColor = UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1)
                case .warning: ledColor = UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1)
                case .critical, .offline: ledColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1)
                }
                gc.setFillColor(ledColor.cgColor)
                let ledSize: CGFloat = 3
                // Draw 2 LED dots on left face
                for i in 0..<2 {
                    let ly = baseY + hh * 0.4 + CGFloat(i) * (blockHeight * 0.35)
                    let lx: CGFloat = hw * 0.35
                    gc.fillEllipse(in: CGRect(x: lx, y: ly, width: ledSize, height: ledSize))
                }
            }

            // Edge outlines
            gc.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            gc.setLineWidth(0.5)
            gc.addPath(top); gc.strokePath()
            gc.addPath(left); gc.strokePath()
            gc.addPath(right); gc.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Ghost (semi-transparent) equipment texture for build preview.
    static func ghostTexture(for type: EquipmentType, valid: Bool) -> SKTexture {
        let w = IsometricConstants.tileWidth
        let blockHeight: CGFloat = CGFloat(8 + type.tier * 8)
        let totalH = IsometricConstants.tileHeight + blockHeight
        let tint: UIColor = valid
            ? UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.4)
            : UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.4)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: totalH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let hw = w / 2
            let hh = IsometricConstants.tileHeight / 2
            let baseY = blockHeight

            // Top face
            let top = CGMutablePath()
            top.move(to: CGPoint(x: hw, y: baseY - hh))
            top.addLine(to: CGPoint(x: w, y: baseY))
            top.addLine(to: CGPoint(x: hw, y: baseY + hh))
            top.addLine(to: CGPoint(x: 0, y: baseY))
            top.closeSubpath()
            gc.setFillColor(tint.cgColor)
            gc.addPath(top); gc.fillPath()

            // Left face
            let left = CGMutablePath()
            left.move(to: CGPoint(x: 0, y: baseY))
            left.addLine(to: CGPoint(x: hw, y: baseY + hh))
            left.addLine(to: CGPoint(x: hw, y: totalH))
            left.addLine(to: CGPoint(x: 0, y: totalH - hh))
            left.closeSubpath()
            gc.setFillColor(tint.withAlphaComponent(0.3).cgColor)
            gc.addPath(left); gc.fillPath()

            // Right face
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

    /// Highlight tile overlay (selection indicator).
    static func selectionTileTexture() -> SKTexture {
        let w = IsometricConstants.tileWidth
        let h = IsometricConstants.tileHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w / 2, y: 0))
            path.addLine(to: CGPoint(x: w, y: h / 2))
            path.addLine(to: CGPoint(x: w / 2, y: h))
            path.addLine(to: CGPoint(x: 0, y: h / 2))
            path.closeSubpath()

            gc.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            gc.addPath(path); gc.fillPath()

            gc.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            gc.setLineWidth(2)
            gc.addPath(path); gc.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Incident indicator texture (pulsing red exclamation circle).
    static func incidentIndicatorTexture() -> SKTexture {
        let size: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Red circle
            gc.setFillColor(UIColor(red: 1, green: 0.15, blue: 0.15, alpha: 0.9).cgColor)
            gc.fillEllipse(in: CGRect(x: 1, y: 1, width: size - 2, height: size - 2))
            // White exclamation mark
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
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
