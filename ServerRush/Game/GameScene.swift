import SpriteKit
import QuartzCore

// MARK: - GameScene

final class GameScene: SKScene {

    // External state (set before presenting)
    var gameState: GameState!

    // Sub-systems
    private var cameraController = CameraController()
    private var simulationEngine: SimulationEngine!
    private var incidentScheduler: IncidentScheduler!
    private(set) var inputHandler: InputHandler!

    // Layers
    private let sceneryLayer = SKNode()
    private let floorLayer = SKNode()
    private let equipmentLayer = SKNode()
    private let effectLayer = SKNode()
    private let guideLayer = SKNode()

    // Sprite tracking
    private var equipmentSprites: [GridPosition: SKSpriteNode] = [:]
    private var incidentIndicators: [GridPosition: SKSpriteNode] = [:]
    private var toolIconSprites: [GridPosition: SKSpriteNode] = [:]
    private var expansionTileSprites: [Int: SKSpriteNode] = [:]
    private var selectionSprite: SKSpriteNode?
    private var ghostSprite: SKSpriteNode?

    // Guide character
    private var guideSprite: SKSpriteNode?
    private var guideTargetPosition: CGPoint?
    private var guideWanderTimer: TimeInterval = 0
    private let guideWanderInterval: TimeInterval = 10.0

    // Dragged tool sprite (for drag-to-fix)
    var draggedToolSprite: SKSpriteNode?

    // Coin particle timer
    private var coinTimer: TimeInterval = 0
    private let coinInterval: TimeInterval = 3.0

    // Ambient: Steam wisps
    private var steamTimer: TimeInterval = 0
    private let steamInterval: TimeInterval = 1.0

    // Ambient: Dust motes
    private let dustMoteLayer = SKNode()
    private var dustMotes: [SKNode] = []

    // Ambient: Equipment breathing phase tracking
    private var breathingPhases: [GridPosition: TimeInterval] = [:]

    // Cached textures
    private var floorTexture: SKTexture!
    private var selectionTexture: SKTexture!
    private var incidentTexture: SKTexture!
    private var equipmentTextures: [String: SKTexture] = [:]
    private var toolTextures: [IncidentTool: SKTexture] = [:]

    // Timing
    private var lastUpdateTime: TimeInterval = 0
    private var tickAccumulator: TimeInterval = 0
    private let tickInterval: TimeInterval = 1.0

    // LED blink timer
    private var ledBlinkPhase: Bool = false
    private var ledBlinkTimer: TimeInterval = 0
    private let ledBlinkInterval: TimeInterval = 0.5

    // Telegraph tracking
    private var telegraphNodes: [GridPosition: SKNode] = [:]

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Theme.skBackground
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Initialize subsystems
        simulationEngine = SimulationEngine(gameState: gameState)
        incidentScheduler = IncidentScheduler(gameState: gameState)
        inputHandler = InputHandler(gameState: gameState, scene: self)

        // Cache textures
        floorTexture = TextureFactory.floorTileTexture()
        selectionTexture = TextureFactory.selectionTileTexture()
        incidentTexture = TextureFactory.incidentIndicatorTexture()
        for tool in IncidentTool.allCases {
            toolTextures[tool] = TextureFactory.toolIconTexture(tool: tool)
        }

        // Layer hierarchy
        sceneryLayer.zPosition = IsometricConstants.floorLayer - 10
        floorLayer.zPosition = IsometricConstants.floorLayer
        dustMoteLayer.zPosition = 500
        equipmentLayer.zPosition = IsometricConstants.objectLayer
        effectLayer.zPosition = IsometricConstants.effectLayer
        guideLayer.zPosition = IsometricConstants.effectLayer + 50
        addChild(sceneryLayer)
        addChild(floorLayer)
        addChild(dustMoteLayer)
        addChild(equipmentLayer)
        addChild(effectLayer)
        addChild(guideLayer)

        // Camera - focus on the playable area center, not the full grid
        cameraController.attach(to: self)
        cameraController.configure(
            gridWidth: gameState.gridWidth,
            gridHeight: gameState.gridHeight,
            sceneSize: size
        )
        // Center camera on the starting area (cols 5-10, rows 5-10)
        let center = IsometricUtils.gridToScreen(col: 7, row: 7)
        cameraController.cameraNode.position = center
        cameraController.installGestures(on: view)

        // Background scenery (trees, bushes, etc.)
        buildBackgroundScenery()

        // Build floor grid (6x6 initial)
        buildFloorGrid()

        // Place any pre-existing equipment (for loaded games)
        for (pos, eq) in gameState.placedEquipment {
            addEquipmentSprite(for: eq.type, at: pos, status: eq.status)
        }

        // Spawn guide character
        spawnGuideCharacter()

        // Ambient: floor decorations (leaves on ~20% of tiles)
        addFloorDecorations()

        // Ambient: dust motes
        spawnDustMotes()

        // Ambient: fireflies
        spawnFireflies()
    }

    override func willMove(from view: SKView) {
        cameraController.removeGestures(from: view)
    }

    // MARK: - Floor Grid

    private func buildFloorGrid() {
        floorLayer.removeAllChildren()
        selectionSprite = nil

        for col in 0..<gameState.gridWidth {
            for row in 0..<gameState.gridHeight {
                let isPlayable = gameState.isUnlockedTile(col: col, row: row)
                let isBorder = gameState.isExpansionBorderTile(col: col, row: row)

                // Only render playable tiles and expansion border tiles
                guard isPlayable || isBorder else { continue }

                let screenPos = IsometricUtils.gridToScreen(col: col, row: row)

                if isPlayable {
                    let tile = SKSpriteNode(texture: floorTexture)
                    tile.position = screenPos
                    tile.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer)
                    floorLayer.addChild(tile)
                } else if isBorder {
                    // Expansion border tiles: dimmer with "buy" hint
                    let tile = SKSpriteNode(texture: floorTexture)
                    tile.position = screenPos
                    tile.alpha = 0.35
                    tile.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer)
                    floorLayer.addChild(tile)
                }
            }
        }
    }

    /// Rebuild the floor grid after an expansion.
    func rebuildFloorGrid() {
        buildFloorGrid()
        buildBackgroundScenery()
        addFloorDecorations()
        cameraController.configure(
            gridWidth: gameState.gridWidth,
            gridHeight: gameState.gridHeight,
            sceneSize: size
        )
    }

    // MARK: - Background Scenery

    /// Adds trees, bushes, flowers, and rocks on ALL non-unlocked tiles inside the grid
    /// plus a surrounding ring outside for depth. Scenery clears when expansions are purchased.
    private func buildBackgroundScenery() {
        sceneryLayer.removeAllChildren()

        let gridW = gameState.gridWidth
        let gridH = gameState.gridHeight

        var sceneryPositions: [(col: Int, row: Int)] = []

        // Inside the grid: fill non-unlocked, non-expansion-border tiles (~55% density)
        for col in 0..<gridW {
            for row in 0..<gridH {
                if gameState.isUnlockedTile(col: col, row: row) { continue }
                if gameState.isExpansionBorderTile(col: col, row: row) { continue }
                // ~55% density inside grid
                if Int.random(in: 0..<20) < 11 {
                    sceneryPositions.append((col, row))
                }
            }
        }

        // Surrounding ring: -3 to gridW+2 (skip anything already covered above)
        for col in -3...(gridW + 2) {
            for row in -3...(gridH + 2) {
                // Skip positions inside the grid (handled above)
                if col >= 0 && col < gridW && row >= 0 && row < gridH { continue }
                // ~35% density outside
                if Int.random(in: 0..<20) < 7 {
                    sceneryPositions.append((col, row))
                }
            }
        }

        // Outer scatter: -6 to gridW+5 for far depth
        for col in stride(from: -6, to: gridW + 6, by: 2) {
            for row in stride(from: -6, to: gridH + 6, by: 2) {
                if col >= -3 && col <= gridW + 2 && row >= -3 && row <= gridH + 2 { continue }
                if Int.random(in: 0..<3) == 0 {
                    sceneryPositions.append((col, row))
                }
            }
        }

        for pos in sceneryPositions {
            let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
            let kind = Int.random(in: 0..<10)

            if kind < 4 {
                // Tree (40%)
                addTree(at: screenPos, col: pos.col, row: pos.row)
            } else if kind < 7 {
                // Bush (30%)
                addBush(at: screenPos, col: pos.col, row: pos.row)
            } else if kind < 9 {
                // Flower cluster (20%)
                addFlowerCluster(at: screenPos, col: pos.col, row: pos.row)
            } else {
                // Rock (10%)
                addRock(at: screenPos, col: pos.col, row: pos.row)
            }
        }
    }

    private func addTree(at position: CGPoint, col: Int, row: Int) {
        let treeW: CGFloat = 28
        let treeH: CGFloat = 40
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: treeW, height: treeH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Trunk (warm brown)
            gc.setFillColor(UIColor(red: 0.55, green: 0.40, blue: 0.28, alpha: 1).cgColor)
            gc.fill(CGRect(x: treeW / 2 - 3, y: treeH - 14, width: 6, height: 14))

            // Canopy layers (overlapping circles for rounded look)
            // Fixed warm palette: sage, olive, forest
            let palettes: [[UIColor]] = [
                [UIColor(red: 0.55, green: 0.68, blue: 0.52, alpha: 1),   // sage light
                 UIColor(red: 0.45, green: 0.58, blue: 0.42, alpha: 1),   // sage mid
                 UIColor(red: 0.62, green: 0.74, blue: 0.58, alpha: 1)],  // sage bright
                [UIColor(red: 0.50, green: 0.56, blue: 0.36, alpha: 1),   // olive light
                 UIColor(red: 0.42, green: 0.48, blue: 0.30, alpha: 1),   // olive mid
                 UIColor(red: 0.56, green: 0.62, blue: 0.42, alpha: 1)],  // olive bright
                [UIColor(red: 0.35, green: 0.52, blue: 0.38, alpha: 1),   // forest light
                 UIColor(red: 0.28, green: 0.44, blue: 0.32, alpha: 1),   // forest mid
                 UIColor(red: 0.42, green: 0.58, blue: 0.44, alpha: 1)],  // forest bright
            ]
            let greens = palettes[Int.random(in: 0..<palettes.count)]
            gc.setFillColor(greens[1].cgColor)
            gc.fillEllipse(in: CGRect(x: 1, y: 2, width: treeW - 2, height: 24))
            gc.setFillColor(greens[0].cgColor)
            gc.fillEllipse(in: CGRect(x: 4, y: 0, width: treeW - 8, height: 20))
            gc.setFillColor(greens[2].cgColor)
            gc.fillEllipse(in: CGRect(x: 7, y: 4, width: treeW - 14, height: 16))

            // Highlight spot
            gc.setFillColor(UIColor(red: 0.65, green: 0.78, blue: 0.55, alpha: 0.4).cgColor)
            gc.fillEllipse(in: CGRect(x: 8, y: 3, width: 8, height: 6))
        }

        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.position = CGPoint(x: position.x + CGFloat.random(in: -8...8), y: position.y + 12)
        sprite.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer - 5)
        // Vary size slightly
        let scale = CGFloat.random(in: 0.7...1.1)
        sprite.setScale(scale)
        sceneryLayer.addChild(sprite)

        // Gentle sway
        let sway = SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: CGFloat.random(in: 0.01...0.03), duration: CGFloat.random(in: 2.0...3.5)),
            SKAction.rotate(toAngle: CGFloat.random(in: -0.03 ... -0.01), duration: CGFloat.random(in: 2.0...3.5)),
        ]))
        sprite.run(sway)
    }

    private func addBush(at position: CGPoint, col: Int, row: Int) {
        let bushW: CGFloat = 18
        let bushH: CGFloat = 14
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: bushW, height: bushH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Fixed warm bush hues
            let bushHues: [CGFloat] = [0.30, 0.33, 0.28]
            let hue = bushHues[Int.random(in: 0..<bushHues.count)]
            // Main bush body
            gc.setFillColor(UIColor(hue: hue, saturation: 0.40, brightness: 0.60, alpha: 1).cgColor)
            gc.fillEllipse(in: CGRect(x: 0, y: 2, width: bushW, height: bushH - 2))
            // Lighter highlight
            gc.setFillColor(UIColor(hue: hue, saturation: 0.30, brightness: 0.72, alpha: 0.6).cgColor)
            gc.fillEllipse(in: CGRect(x: 3, y: 1, width: bushW - 6, height: bushH - 6))
            // Optional berry dots (red or warm orange — no purple)
            if Bool.random() {
                let berryColor = Bool.random()
                    ? UIColor(red: 0.85, green: 0.35, blue: 0.35, alpha: 0.8) // red berries
                    : UIColor(red: 0.90, green: 0.60, blue: 0.30, alpha: 0.8) // warm orange berries
                gc.setFillColor(berryColor.cgColor)
                for _ in 0..<3 {
                    let bx = CGFloat.random(in: 4...(bushW - 4))
                    let by = CGFloat.random(in: 3...(bushH - 4))
                    gc.fillEllipse(in: CGRect(x: bx, y: by, width: 2.5, height: 2.5))
                }
            }
        }

        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.position = CGPoint(x: position.x + CGFloat.random(in: -6...6), y: position.y + 4)
        sprite.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer - 5)
        sprite.setScale(CGFloat.random(in: 0.8...1.2))
        sceneryLayer.addChild(sprite)
    }

    private func addFlowerCluster(at position: CGPoint, col: Int, row: Int) {
        let flowerColors: [UIColor] = [
            UIColor(red: 0.90, green: 0.55, blue: 0.60, alpha: 1),  // soft pink
            UIColor(red: 0.95, green: 0.80, blue: 0.45, alpha: 1),  // warm yellow
            UIColor(red: 0.70, green: 0.60, blue: 0.85, alpha: 1),  // soft lavender
            UIColor(red: 0.95, green: 0.70, blue: 0.50, alpha: 1),  // peach
        ]

        for i in 0..<Int.random(in: 2...4) {
            let fSize: CGFloat = CGFloat.random(in: 4...6)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: fSize + 2, height: fSize + 2))
            let image = renderer.image { ctx in
                let gc = ctx.cgContext
                // Stem dot (green)
                gc.setFillColor(UIColor(hue: 0.30, saturation: 0.40, brightness: 0.55, alpha: 0.7).cgColor)
                gc.fillEllipse(in: CGRect(x: fSize / 2 - 0.5, y: fSize, width: 2, height: 2))
                // Petal
                let color = flowerColors[Int.random(in: 0..<flowerColors.count)]
                gc.setFillColor(color.cgColor)
                gc.fillEllipse(in: CGRect(x: 1, y: 1, width: fSize, height: fSize))
                // Center
                gc.setFillColor(UIColor(red: 0.95, green: 0.90, blue: 0.60, alpha: 1).cgColor)
                gc.fillEllipse(in: CGRect(x: fSize / 2 - 1, y: fSize / 2 - 1, width: 3, height: 3))
            }

            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            let offsetX = CGFloat(i) * 5 - 5 + CGFloat.random(in: -3...3)
            let offsetY = CGFloat.random(in: -3...3)
            sprite.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
            sprite.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer - 5)
            sceneryLayer.addChild(sprite)

            // Gentle bob
            let bob = SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 0, y: CGFloat.random(in: 1...2), duration: CGFloat.random(in: 1.5...2.5)),
                SKAction.moveBy(x: 0, y: CGFloat.random(in: -2 ... -1), duration: CGFloat.random(in: 1.5...2.5))
            ]))
            sprite.run(bob)
        }
    }

    private func addRock(at position: CGPoint, col: Int, row: Int) {
        let rockW: CGFloat = CGFloat.random(in: 10...16)
        let rockH: CGFloat = rockW * CGFloat.random(in: 0.55...0.75)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: rockW, height: rockH))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Warm sandstone/gray palette
            let rockColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
                (0.68, 0.62, 0.54),  // warm sandstone
                (0.62, 0.58, 0.52),  // warm gray
                (0.72, 0.66, 0.58),  // light sandstone
            ]
            let rc = rockColors[Int.random(in: 0..<rockColors.count)]
            gc.setFillColor(UIColor(red: rc.r, green: rc.g, blue: rc.b, alpha: 1).cgColor)
            gc.fillEllipse(in: CGRect(x: 0, y: 0, width: rockW, height: rockH))
            // Highlight
            gc.setFillColor(UIColor(red: rc.r + 0.1, green: rc.g + 0.08, blue: rc.b + 0.05, alpha: 0.5).cgColor)
            gc.fillEllipse(in: CGRect(x: 2, y: 1, width: rockW * 0.5, height: rockH * 0.4))
        }

        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.position = CGPoint(x: position.x + CGFloat.random(in: -5...5), y: position.y)
        sprite.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer - 5)
        sceneryLayer.addChild(sprite)
    }

    // MARK: - Equipment Sprites

    func addEquipmentSprite(for type: EquipmentType, at pos: GridPosition, status: EquipmentStatus = .normal) {
        equipmentSprites[pos]?.removeFromParent()

        let texture = cachedEquipmentTexture(type: type, status: status)
        let sprite = SKSpriteNode(texture: texture)
        let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
        let blockHeight = CGFloat(8 + type.tier * 8)
        sprite.position = CGPoint(x: screenPos.x, y: screenPos.y + blockHeight / 2)
        sprite.zPosition = IsometricUtils.depthForPosition(col: pos.col, row: pos.row, layer: IsometricConstants.objectLayer)

        equipmentLayer.addChild(sprite)
        equipmentSprites[pos] = sprite

        // Bounce-in animation (bigger)
        sprite.setScale(0)
        sprite.run(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.12),
            SKAction.scale(to: 0.95, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.06)
        ]))

        // Dust puff particle on placement
        spawnDustPuff(at: screenPos)
    }

    func removeEquipmentSprite(at pos: GridPosition) {
        equipmentSprites[pos]?.removeFromParent()
        equipmentSprites.removeValue(forKey: pos)
    }

    private func cachedEquipmentTexture(type: EquipmentType, status: EquipmentStatus) -> SKTexture {
        let key = "\(type.rawValue)_\(status.rawValue)"
        if let cached = equipmentTextures[key] { return cached }
        let tex = TextureFactory.equipmentTexture(for: type, status: status)
        equipmentTextures[key] = tex
        return tex
    }

    // MARK: - Guide Character

    private func spawnGuideCharacter() {
        let guideSize: CGFloat = 48
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: guideSize, height: guideSize))
        let guideImage = renderer.image { ctx in
            let gc = ctx.cgContext

            // Shadow
            gc.setFillColor(UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor)
            gc.fillEllipse(in: CGRect(x: 6, y: 36, width: guideSize - 12, height: 8))

            // Round warm body
            gc.setFillColor(Theme.skAccent.cgColor)
            gc.fillEllipse(in: CGRect(x: 4, y: 6, width: guideSize - 8, height: guideSize - 14))

            // Lighter belly
            gc.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.55, alpha: 0.6).cgColor)
            gc.fillEllipse(in: CGRect(x: 12, y: 16, width: guideSize - 24, height: guideSize - 28))

            // Eyes (white)
            gc.setFillColor(UIColor.white.cgColor)
            gc.fillEllipse(in: CGRect(x: 12, y: 12, width: 10, height: 10))
            gc.fillEllipse(in: CGRect(x: 26, y: 12, width: 10, height: 10))

            // Pupils
            gc.setFillColor(Theme.skTextPrimary.cgColor)
            gc.fillEllipse(in: CGRect(x: 15, y: 14, width: 5, height: 5))
            gc.fillEllipse(in: CGRect(x: 29, y: 14, width: 5, height: 5))

            // Eye highlights
            gc.setFillColor(UIColor.white.cgColor)
            gc.fillEllipse(in: CGRect(x: 16, y: 14, width: 2, height: 2))
            gc.fillEllipse(in: CGRect(x: 30, y: 14, width: 2, height: 2))

            // Smile
            gc.setStrokeColor(Theme.skTextPrimary.cgColor)
            gc.setLineWidth(1.5)
            gc.addArc(center: CGPoint(x: guideSize / 2, y: 24), radius: 6, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: false)
            gc.strokePath()

            // Hard hat (warm gold)
            gc.setFillColor(Theme.skAccentGold.cgColor)
            gc.fill(CGRect(x: 8, y: 2, width: guideSize - 16, height: 10))
            gc.fill(CGRect(x: 4, y: 8, width: guideSize - 8, height: 4))
        }

        let sprite = SKSpriteNode(texture: SKTexture(image: guideImage))
        // Start in the middle of the starting area
        let startPos = IsometricUtils.gridToScreen(col: 7, row: 7)
        sprite.position = CGPoint(x: startPos.x, y: startPos.y + 20)
        sprite.zPosition = IsometricConstants.effectLayer + 200

        // Gentle idle bob animation
        let bob = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 4, duration: 1.0),
            SKAction.moveBy(x: 0, y: -4, duration: 1.0)
        ]))
        bob.timingMode = .easeInEaseOut
        sprite.run(bob, withKey: "idle")

        guideLayer.addChild(sprite)
        guideSprite = sprite

        // Personality animations: periodic head tilt + happy bounce
        let personalityLoop = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 6.0, withRange: 4.0),
            // Head tilt
            SKAction.rotate(toAngle: .pi / 36, duration: 0.3),  // +5 degrees
            SKAction.wait(forDuration: 0.5),
            SKAction.rotate(toAngle: -.pi / 36, duration: 0.3), // -5 degrees
            SKAction.wait(forDuration: 0.5),
            SKAction.rotate(toAngle: 0, duration: 0.2),
            SKAction.wait(forDuration: 4.0, withRange: 6.0),
            // Happy squash-stretch bounce
            SKAction.scaleX(to: 1.1, y: 0.9, duration: 0.1),
            SKAction.scaleX(to: 0.95, y: 1.05, duration: 0.1),
            SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.15),
        ]))
        sprite.run(personalityLoop, withKey: "personality")

        // Show contextual welcome message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showContextualGuideMessage()
        }
    }

    // MARK: - Guide Messages

    /// Tracks what the guide last said to avoid repeating
    private var lastGuideKey: String = ""
    private var guideMessageTimer: TimeInterval = 0
    private var lastMistralCallTime: TimeInterval = -60  // allow first call immediately
    private var mistralCallInFlight = false

    /// Shows a contextual guide message based on current game state.
    private func showContextualGuideMessage() {
        let (key, fallback) = contextualGuideMessage()
        guard key != lastGuideKey else { return }
        lastGuideKey = key

        // Throttle: max 1 Mistral call per 45 seconds
        let now = gameState.playTime
        if !mistralCallInFlight && (now - lastMistralCallTime) >= 45 {
            mistralCallInFlight = true
            lastMistralCallTime = now
            let context = buildMistralContext(key: key, fallback: fallback)
            Task { [weak self] in
                let response = await MistralService.shared.getGuideMessage(context: context)
                await MainActor.run {
                    guard let self else { return }
                    self.mistralCallInFlight = false
                    self.gameState.guideMessage = response
                    self.gameState.guideVisible = true
                    self.autoDismissGuide()
                    // Voice the Mistral response through ElevenLabs
                    ElevenLabsService.shared.speak(response)
                }
            }
        } else {
            // Use fallback immediately (no API call)
            gameState.guideMessage = fallback
            gameState.guideVisible = true
            autoDismissGuide()
        }
    }

    private func autoDismissGuide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.gameState.guideVisible = false
        }
    }

    /// Build a rich context string for Mistral describing the current game state.
    private func buildMistralContext(key: String, fallback: String) -> String {
        let eq = gameState.totalEquipmentPlaced
        let racks = gameState.rackCount
        let money = Int(gameState.money)
        let rev = String(format: "%.1f", gameState.revenuePerSecond)
        let incidents = gameState.totalIncidentsResolved
        let activeInc = gameState.activeIncidents.count
        let expansions = gameState.unlockedExpansions.count
        let power = Int(gameState.powerPercent)
        let cooling = Int(gameState.coolingPercent)
        let uptime = String(format: "%.1f", gameState.uptimePercent)

        return """
            Situation: \(key). \
            Player stats — money: $\(money), revenue/sec: $\(rev), \
            equipment placed: \(eq) (\(racks) racks), \
            incidents resolved: \(incidents), active incidents: \(activeInc), \
            expansions: \(expansions), power: \(power)%, cooling: \(cooling)%, uptime: \(uptime)%. \
            Give a short, personalized comment.
            """
    }

    /// Returns (key, fallback message) based on game state. Key prevents repeat showing.
    private func contextualGuideMessage() -> (String, String) {
        let eq = gameState.totalEquipmentPlaced
        let racks = gameState.rackCount
        let money = gameState.money
        let incidents = gameState.totalIncidentsResolved
        let expansions = gameState.unlockedExpansions.count

        // First time — no equipment at all
        if eq == 0 {
            return ("welcome", "Welcome! Tap BUILD below to place your first server rack.")
        }

        // Has rack but no cooling/power yet
        if racks > 0 && eq < 3 {
            let hasCooling = gameState.placedEquipment.values.contains { $0.type.category == .cooling }
            let hasPower = gameState.placedEquipment.values.contains { $0.type.category == .power }
            if !hasCooling && !hasPower {
                return ("needSupport", "Nice rack! Now add cooling and power to keep it running.")
            }
            if !hasCooling {
                return ("needCooling", "Don't forget cooling — your servers will overheat without it!")
            }
            if !hasPower {
                return ("needPower", "Add a power supply to keep everything running smoothly.")
            }
        }

        // Active incidents — urgent
        if gameState.activeIncidents.count >= 2 {
            return ("multiIncident_\(gameState.activeIncidents.count)", "Multiple incidents! Prioritize the critical ones first!")
        }

        // Just hit 3 equipment — encourage them
        if eq >= 3 && incidents == 0 && expansions == 0 {
            return ("goodSetup", "Great setup! Keep earning money. Watch out for incidents!")
        }

        // First incident resolved
        if incidents == 1 {
            return ("firstFix", "You fixed your first incident! Drag tools onto racks to resolve them fast.")
        }

        // Resource warnings
        if gameState.powerPercent > 85 {
            return ("powerWarn_\(Int(gameState.powerPercent / 5) * 5)", "Power usage is getting high! Add more generators.")
        }
        if gameState.coolingPercent > 85 {
            return ("coolingWarn_\(Int(gameState.coolingPercent / 5) * 5)", "Temperatures rising! Your servers need more cooling.")
        }

        // Enough money for expansion
        if expansions == 0 && money >= 600 {
            return ("expandHint", "You're saving up nicely! Tap the dim tiles at the edge to expand.")
        }

        // After first expansion
        if expansions == 1 {
            return ("expanded", "Your data center is growing! New equipment types are now available.")
        }

        // Periodic revenue milestone
        if gameState.revenuePerSecond >= 10 && eq >= 6 {
            return ("revenue_\(Int(gameState.revenuePerSecond / 5) * 5)", "Revenue is rolling in! You're a real server mogul.")
        }

        // Fallback: no new message
        return (lastGuideKey, gameState.guideMessage ?? "")
    }

    /// Periodically check if there's a new contextual message to show (every 20 seconds).
    private func updateGuideMessages(dt: TimeInterval) {
        guideMessageTimer += dt
        guard guideMessageTimer >= 20 else { return }
        guideMessageTimer = 0

        // Don't interrupt if guide is currently visible
        guard !gameState.guideVisible else { return }
        showContextualGuideMessage()
    }

    private func updateGuideWander(dt: TimeInterval) {
        guideWanderTimer += dt
        guard guideWanderTimer >= guideWanderInterval else { return }
        guideWanderTimer = 0

        // Only wander within the starting area (cols 5-10, rows 5-10) to stay on screen
        var candidates: [GridPosition] = []
        for col in 5...10 {
            for row in 5...10 {
                let pos = GridPosition(col: col, row: row)
                if gameState.placedEquipment[pos] == nil {
                    candidates.append(pos)
                }
            }
        }
        guard let chosen = candidates.randomElement() else { return }

        let target = IsometricUtils.gridToScreen(col: chosen.col, row: chosen.row)
        let dest = CGPoint(x: target.x, y: target.y + 20)

        let moveAction = SKAction.move(to: dest, duration: 3.0)
        moveAction.timingMode = .easeInEaseOut
        guideSprite?.run(moveAction, withKey: "wander")
    }

    // MARK: - Particle Effects

    /// Dust puff on equipment placement.
    private func spawnDustPuff(at position: CGPoint) {
        let puffCount = 6
        for _ in 0..<puffCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = Theme.skCardBackground
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = IsometricConstants.effectLayer + 10
            particle.alpha = 0.7
            effectLayer.addChild(particle)

            let dx = CGFloat.random(in: -15...15)
            let dy = CGFloat.random(in: 5...20)
            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.4),
                    SKAction.fadeAlpha(to: 0, duration: 0.4),
                    SKAction.scale(to: 0.3, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Green sparkle burst on incident resolution.
    func spawnResolutionParticles(at position: GridPosition) {
        let screenPos = IsometricUtils.gridToScreen(col: position.col, row: position.row)
        let sparkleCount = 10
        for _ in 0..<sparkleCount {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
            spark.fillColor = Theme.skPositive
            spark.strokeColor = .clear
            spark.position = CGPoint(x: screenPos.x, y: screenPos.y + 15)
            spark.zPosition = IsometricConstants.effectLayer + 20
            spark.alpha = 1.0
            effectLayer.addChild(spark)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 15...30)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                    SKAction.fadeAlpha(to: 0, duration: 0.5),
                    SKAction.scale(to: 0.2, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Smoke particles on incident failure.
    func spawnFailureSmoke(at position: GridPosition) {
        let screenPos = IsometricUtils.gridToScreen(col: position.col, row: position.row)
        for _ in 0..<8 {
            let smoke = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            smoke.fillColor = UIColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 0.6)
            smoke.strokeColor = .clear
            smoke.position = CGPoint(x: screenPos.x, y: screenPos.y + 10)
            smoke.zPosition = IsometricConstants.effectLayer + 15
            effectLayer.addChild(smoke)

            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: 15...35)
            smoke.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 1.0),
                    SKAction.fadeAlpha(to: 0, duration: 1.0),
                    SKAction.scale(to: 1.5, duration: 1.0)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Gold coin floats upward from a rack.
    private func spawnCoinParticle(from position: CGPoint) {
        let coinSize: CGFloat = 6
        let coin = SKShapeNode(ellipseOf: CGSize(width: coinSize, height: coinSize))
        coin.fillColor = Theme.skAccentGold
        coin.strokeColor = Theme.skWoodTone
        coin.lineWidth = 0.5
        coin.position = position
        coin.zPosition = IsometricConstants.effectLayer + 5
        effectLayer.addChild(coin)

        coin.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 30, duration: 1.2),
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 1, duration: 0.3),
                    SKAction.wait(forDuration: 0.5),
                    SKAction.fadeAlpha(to: 0, duration: 0.4)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    /// Spawn coin particles from revenue-generating racks periodically.
    private func updateCoinParticles(dt: TimeInterval) {
        coinTimer += dt
        guard coinTimer >= coinInterval else { return }
        coinTimer = 0

        let racks = gameState.placedEquipment.filter {
            $0.value.type.category == .rack && $0.value.status != .offline
        }
        // Randomly pick one rack to emit a coin
        if let rack = racks.randomElement() {
            let screenPos = IsometricUtils.gridToScreen(col: rack.key.col, row: rack.key.row)
            spawnCoinParticle(from: CGPoint(x: screenPos.x, y: screenPos.y + 10))
        }
    }

    // MARK: - Incident Telegraph

    /// Yellow/orange pulse on a tile 2 seconds before incident spawns.
    func telegraphIncident(at position: GridPosition) {
        let screenPos = IsometricUtils.gridToScreen(col: position.col, row: position.row)

        let pulse = SKShapeNode(ellipseOf: CGSize(width: IsometricConstants.tileWidth * 0.8,
                                                   height: IsometricConstants.tileHeight * 0.8))
        pulse.fillColor = Theme.skWarning.withAlphaComponent(0.3)
        pulse.strokeColor = Theme.skAccent.withAlphaComponent(0.6)
        pulse.lineWidth = 1.5
        pulse.position = screenPos
        pulse.zPosition = IsometricConstants.decorationLayer + 100
        floorLayer.addChild(pulse)
        telegraphNodes[position] = pulse

        // Pulsing animation for 2 seconds, then remove
        let pulsate = SKAction.repeat(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.25),
            SKAction.fadeAlpha(to: 0.2, duration: 0.25)
        ]), count: 4)

        pulse.run(SKAction.sequence([
            pulsate,
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ])) { [weak self] in
            self?.telegraphNodes.removeValue(forKey: position)
        }
    }

    // MARK: - Tool Icons for Active Incidents

    private func syncToolIcons() {
        let activePositions = Set(
            gameState.activeIncidents
                .filter { !$0.resolved && !$0.failed }
                .map(\.affectedPosition)
        )

        // Add tool icons near incident racks
        for incident in gameState.activeIncidents where !incident.resolved && !incident.failed {
            let pos = incident.affectedPosition
            if toolIconSprites[pos] == nil {
                let tool = incident.requiredTool
                guard let texture = toolTextures[tool] else { continue }
                let icon = SKSpriteNode(texture: texture)
                icon.setScale(1.0)
                let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
                icon.position = CGPoint(x: screenPos.x + 30, y: screenPos.y + 35)
                icon.zPosition = IsometricConstants.effectLayer + 80
                icon.name = "toolIcon_\(pos.col)_\(pos.row)"

                // Attention-grabbing bounce
                let bounce = SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 5, duration: 0.4),
                    SKAction.moveBy(x: 0, y: -5, duration: 0.4)
                ]))
                bounce.timingMode = .easeInEaseOut
                icon.run(bounce)

                effectLayer.addChild(icon)
                toolIconSprites[pos] = icon
            }
        }

        // Remove icons for resolved/absent incidents
        for (pos, sprite) in toolIconSprites {
            if !activePositions.contains(pos) {
                sprite.removeFromParent()
                toolIconSprites.removeValue(forKey: pos)
            }
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        guard gameState.phase == .playing else { return }

        // Camera
        cameraController.update(dt: dt)

        // Simulation
        simulationEngine.update(deltaTime: dt)

        // Incident scheduler tick (1/sec)
        tickAccumulator += dt
        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            incidentScheduler.tick()
        }

        // LED blink
        ledBlinkTimer += dt
        if ledBlinkTimer >= ledBlinkInterval {
            ledBlinkTimer -= ledBlinkInterval
            ledBlinkPhase.toggle()
        }

        // Particles
        updateCoinParticles(dt: dt)

        // Ambient effects
        updateSteamWisps(dt: dt)
        updateDustMotes(dt: dt)

        // Guide wander + contextual messages
        updateGuideWander(dt: dt)
        updateGuideMessages(dt: dt)

        // Sync visual state
        syncEquipmentVisuals()
        syncIncidentIndicators()
        syncToolIcons()
        syncSelectionHighlight()
        syncGhostPreview()
    }

    // MARK: - Visual Sync

    private func syncEquipmentVisuals() {
        for (pos, eq) in gameState.placedEquipment {
            guard let sprite = equipmentSprites[pos] else {
                addEquipmentSprite(for: eq.type, at: pos, status: eq.status)
                continue
            }
            let tex = cachedEquipmentTexture(type: eq.type, status: eq.status)
            if sprite.texture !== tex {
                sprite.texture = tex
            }
            // LED blink for racks
            if eq.type.category == .rack {
                sprite.alpha = ledBlinkPhase ? 1.0 : 0.88
            }
            // Dim offline equipment
            if eq.status == .offline {
                sprite.alpha = 0.5
            }
            // Ambient: subtle breathing for normal-status racks
            if eq.status == .normal && eq.type.category == .rack {
                if sprite.action(forKey: "breathing") == nil {
                    // Stagger phase per rack so they don't pulse in sync
                    if breathingPhases[pos] == nil {
                        breathingPhases[pos] = TimeInterval.random(in: 0...2.0)
                    }
                    let delay = SKAction.wait(forDuration: breathingPhases[pos] ?? 0)
                    let breathe = SKAction.repeatForever(SKAction.sequence([
                        SKAction.scale(to: 1.02, duration: 1.5),
                        SKAction.scale(to: 1.0, duration: 1.5)
                    ]))
                    breathe.timingMode = .easeInEaseOut
                    sprite.run(SKAction.sequence([delay, breathe]), withKey: "breathing")
                }
            } else {
                if sprite.action(forKey: "breathing") != nil {
                    sprite.removeAction(forKey: "breathing")
                    sprite.setScale(1.0)
                }
            }
        }

        // Remove sprites for equipment that no longer exists
        for pos in equipmentSprites.keys {
            if gameState.placedEquipment[pos] == nil {
                removeEquipmentSprite(at: pos)
            }
        }
    }

    private func syncIncidentIndicators() {
        let activePositions = Set(
            gameState.activeIncidents
                .filter { !$0.resolved && !$0.failed }
                .map(\.affectedPosition)
        )

        for pos in activePositions {
            if incidentIndicators[pos] == nil {
                let indicator = SKSpriteNode(texture: incidentTexture)
                let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
                indicator.position = CGPoint(x: screenPos.x, y: screenPos.y + 30)
                indicator.zPosition = IsometricConstants.effectLayer + 100

                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.4),
                    SKAction.scale(to: 0.9, duration: 0.4)
                ]))
                indicator.run(pulse)
                effectLayer.addChild(indicator)
                incidentIndicators[pos] = indicator
            }
        }

        for (pos, indicator) in incidentIndicators {
            if !activePositions.contains(pos) {
                indicator.removeFromParent()
                incidentIndicators.removeValue(forKey: pos)
            }
        }
    }

    private func syncSelectionHighlight() {
        if let selectedPos = gameState.selectedTile {
            if selectionSprite == nil {
                selectionSprite = SKSpriteNode(texture: selectionTexture)
                selectionSprite!.zPosition = IsometricConstants.decorationLayer + 500
                floorLayer.addChild(selectionSprite!)

                let breathe = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.6),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.6)
                ]))
                selectionSprite!.run(breathe)
            }
            selectionSprite!.position = IsometricUtils.gridToScreen(col: selectedPos.col, row: selectedPos.row)
        } else {
            selectionSprite?.removeFromParent()
            selectionSprite = nil
        }
    }

    private func syncGhostPreview() {
        guard let buildType = gameState.buildMode, let ghostPos = gameState.ghostPosition else {
            ghostSprite?.removeFromParent()
            ghostSprite = nil
            return
        }

        let texture = TextureFactory.ghostTexture(for: buildType, valid: gameState.ghostValid)
        if ghostSprite == nil {
            ghostSprite = SKSpriteNode(texture: texture)
            ghostSprite!.zPosition = IsometricConstants.effectLayer + 50
            effectLayer.addChild(ghostSprite!)
        } else {
            ghostSprite!.texture = texture
        }

        let screenPos = IsometricUtils.gridToScreen(col: ghostPos.col, row: ghostPos.row)
        let blockHeight = CGFloat(8 + buildType.tier * 8)
        ghostSprite!.position = CGPoint(x: screenPos.x, y: screenPos.y + blockHeight / 2)
    }

    // MARK: - Ambient: Steam Wisps

    private func updateSteamWisps(dt: TimeInterval) {
        steamTimer += dt
        guard steamTimer >= steamInterval else { return }
        steamTimer = 0

        // Pick a random active (non-offline) rack
        let activeRacks = gameState.placedEquipment.filter {
            $0.value.type.category == .rack && $0.value.status != .offline
        }
        guard let rack = activeRacks.randomElement() else { return }

        let screenPos = IsometricUtils.gridToScreen(col: rack.key.col, row: rack.key.row)
        let temp = rack.value.temperature
        let wispCount = temp > 60 ? Int.random(in: 3...4) : Int.random(in: 2...3)

        for _ in 0..<wispCount {
            let radius = temp > 60 ? CGFloat.random(in: 4...5) : CGFloat.random(in: 3...5)
            let wisp = SKShapeNode(circleOfRadius: radius)
            wisp.fillColor = UIColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1)
            wisp.strokeColor = .clear
            wisp.alpha = CGFloat.random(in: 0.35...0.55)
            wisp.position = CGPoint(
                x: screenPos.x + CGFloat.random(in: -8...8),
                y: screenPos.y + 15
            )
            wisp.zPosition = IsometricConstants.objectLayer + 50
            effectLayer.addChild(wisp)

            let floatHeight = CGFloat.random(in: 20...35)
            let drift = CGFloat.random(in: -6...6)
            wisp.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: drift, y: floatHeight, duration: 1.2),
                    SKAction.fadeAlpha(to: 0, duration: 1.2),
                    SKAction.scale(to: 0.4, duration: 1.2)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Ambient: Dust Motes

    private func spawnDustMotes() {
        let center = IsometricUtils.gridToScreen(col: 7, row: 7)
        for _ in 0..<16 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
            // Warm tan/gold color
            mote.fillColor = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1)
            mote.strokeColor = .clear
            mote.alpha = CGFloat.random(in: 0.2...0.35)
            mote.position = CGPoint(
                x: center.x + CGFloat.random(in: -200...200),
                y: center.y + CGFloat.random(in: -150...150)
            )
            dustMoteLayer.addChild(mote)
            dustMotes.append(mote)

            // Store initial phase offset in name for sine wobble
            mote.name = "mote_\(CGFloat.random(in: 0...(2 * .pi)))"
        }
    }

    private func updateDustMotes(dt: TimeInterval) {
        let cameraPos = cameraController.cameraNode.position
        let viewHalf: CGFloat = 250

        for mote in dustMotes {
            // Parse phase from name
            let phase = Double(mote.name?.replacingOccurrences(of: "mote_", with: "") ?? "0") ?? 0

            // Slow upward drift + gentle sine wobble
            let time = CACurrentMediaTime() + phase
            let wobbleX = CGFloat(sin(time * 0.5)) * 0.3
            mote.position.x += wobbleX * CGFloat(dt) * 10
            mote.position.y += CGFloat(dt) * 10  // ~10px/sec upward

            // Reposition if too far from camera
            let dx = mote.position.x - cameraPos.x
            let dy = mote.position.y - cameraPos.y
            if abs(dx) > viewHalf || abs(dy) > viewHalf {
                mote.position = CGPoint(
                    x: cameraPos.x + CGFloat.random(in: -viewHalf...viewHalf),
                    y: cameraPos.y - viewHalf + CGFloat.random(in: -20...20)
                )
            }
        }
    }

    // MARK: - Ambient: Floor Decorations (Leaves)

    private func addFloorDecorations() {
        for col in 0..<gameState.gridWidth {
            for row in 0..<gameState.gridHeight {
                guard gameState.isUnlockedTile(col: col, row: row) else { continue }
                guard gameState.placedEquipment[GridPosition(col: col, row: row)] == nil else { continue }
                // ~20% chance
                guard Int.random(in: 0..<5) == 0 else { continue }

                let screenPos = IsometricUtils.gridToScreen(col: col, row: row)

                // Draw a tiny leaf via CGContext
                let leafSize: CGFloat = 8
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: leafSize, height: leafSize))
                let leafImage = renderer.image { ctx in
                    let gc = ctx.cgContext
                    // Warm green leaf shape (teardrop)
                    let hue = CGFloat.random(in: 0.25...0.35) // green to yellow-green
                    gc.setFillColor(UIColor(hue: hue, saturation: 0.45, brightness: 0.7, alpha: 0.8).cgColor)
                    gc.move(to: CGPoint(x: leafSize / 2, y: 0))
                    gc.addQuadCurve(to: CGPoint(x: leafSize / 2, y: leafSize), control: CGPoint(x: leafSize, y: leafSize * 0.5))
                    gc.addQuadCurve(to: CGPoint(x: leafSize / 2, y: 0), control: CGPoint(x: 0, y: leafSize * 0.5))
                    gc.fillPath()
                    // Tiny vein line
                    gc.setStrokeColor(UIColor(hue: hue, saturation: 0.3, brightness: 0.5, alpha: 0.5).cgColor)
                    gc.setLineWidth(0.5)
                    gc.move(to: CGPoint(x: leafSize / 2, y: 1))
                    gc.addLine(to: CGPoint(x: leafSize / 2, y: leafSize - 1))
                    gc.strokePath()
                }

                let leaf = SKSpriteNode(texture: SKTexture(image: leafImage))
                // Place near tile edge so equipment isn't obscured
                let offsetX = CGFloat.random(in: -12...12)
                let offsetY = CGFloat.random(in: -6...6)
                leaf.position = CGPoint(x: screenPos.x + offsetX, y: screenPos.y + offsetY)
                leaf.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.decorationLayer)

                // Gentle slow sway: rotate ±3 degrees over 2.5s
                let sway = SKAction.repeatForever(SKAction.sequence([
                    SKAction.rotate(toAngle: .pi / 60, duration: 1.25),
                    SKAction.rotate(toAngle: -.pi / 60, duration: 1.25)
                ]))
                sway.timingMode = .easeInEaseOut
                leaf.run(sway)

                floorLayer.addChild(leaf)
            }
        }
    }

    // MARK: - Ambient: Fireflies / Sparkles

    private func spawnFireflies() {
        let center = IsometricUtils.gridToScreen(col: 7, row: 7)

        for _ in 0..<6 {
            let firefly = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...4))
            firefly.fillColor = Theme.skAccentGold
            firefly.strokeColor = .clear
            firefly.alpha = 0.4
            firefly.position = CGPoint(
                x: center.x + CGFloat.random(in: -150...150),
                y: center.y + CGFloat.random(in: -100...100)
            )
            firefly.zPosition = IsometricConstants.effectLayer + 2
            firefly.glowWidth = 4
            effectLayer.addChild(firefly)

            // Alpha pulse for twinkling
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.8), duration: CGFloat.random(in: 0.8...1.5)),
                SKAction.fadeAlpha(to: 0.4, duration: CGFloat.random(in: 0.8...1.5))
            ]))
            firefly.run(pulse, withKey: "pulse")

            // Start wandering
            fireflyWander(firefly, center: center)
        }
    }

    private func fireflyWander(_ firefly: SKNode, center: CGPoint) {
        let target = CGPoint(
            x: center.x + CGFloat.random(in: -180...180),
            y: center.y + CGFloat.random(in: -120...120)
        )
        let duration = TimeInterval.random(in: 3...5)
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        firefly.run(SKAction.sequence([
            move,
            SKAction.run { [weak self] in
                self?.fireflyWander(firefly, center: center)
            }
        ]))
    }

    // MARK: - Screen Shake

    func screenShake(intensity: CGFloat = 8, duration: TimeInterval = 0.4) {
        let shakeCount = Int(duration / 0.04)
        var actions: [SKAction] = []
        for _ in 0..<shakeCount {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.02))
            actions.append(SKAction.moveBy(x: -dx, y: -dy, duration: 0.02))
        }
        cameraController.cameraNode.run(SKAction.sequence(actions))
    }

    // MARK: - Incident Resolution

    func resolveIncident(at position: GridPosition, withTool tool: IncidentTool) {
        // Check if the right tool was used
        guard let incident = gameState.activeIncidents.first(where: {
            $0.affectedPosition == position && !$0.resolved && !$0.failed
        }) else { return }

        guard incident.requiredTool == tool else { return }

        incidentScheduler.resolveIncident(at: position)

        // Flash effect on resolved rack
        if let sprite = equipmentSprites[position] {
            sprite.run(SKAction.sequence([
                SKAction.colorize(with: Theme.skPositive, colorBlendFactor: 0.6, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.3)
            ]))
        }

        // Resolution particles
        spawnResolutionParticles(at: position)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        inputHandler.touchBegan(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        inputHandler.touchMoved(at: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        inputHandler.touchEnded(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.touchCancelled()
    }

    // MARK: - Critical Incident Trigger

    func onCriticalIncident() {
        screenShake(intensity: 12, duration: 0.5)
    }

    // MARK: - Helpers for InputHandler

    /// Find which active incident (if any) has a tool icon at the given scene point.
    func incidentForToolIcon(at scenePoint: CGPoint) -> ActiveIncident? {
        for incident in gameState.activeIncidents where !incident.resolved && !incident.failed {
            let pos = incident.affectedPosition
            if let icon = toolIconSprites[pos] {
                // Convert icon position to scene coordinates for accurate hit-testing
                let iconInScene = effectLayer.convert(icon.position, to: self)
                let dist = hypot(scenePoint.x - iconInScene.x, scenePoint.y - iconInScene.y)
                if dist < 36 {
                    return incident
                }
            }
        }
        return nil
    }
}
