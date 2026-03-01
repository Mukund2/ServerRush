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
    private var inputHandler: InputHandler!

    // Layers
    private let floorLayer = SKNode()
    private let equipmentLayer = SKNode()
    private let effectLayer = SKNode()

    // Sprite tracking
    private var equipmentSprites: [GridPosition: SKSpriteNode] = [:]
    private var incidentIndicators: [GridPosition: SKSpriteNode] = [:]
    private var selectionSprite: SKSpriteNode?
    private var ghostSprite: SKSpriteNode?

    // Cached textures
    private var floorTexture: SKTexture!
    private var selectionTexture: SKTexture!
    private var incidentTexture: SKTexture!
    private var equipmentTextures: [String: SKTexture] = [:]

    // Timing
    private var lastUpdateTime: TimeInterval = 0
    private var tickAccumulator: TimeInterval = 0
    private let tickInterval: TimeInterval = 1.0

    // LED blink timer
    private var ledBlinkPhase: Bool = false
    private var ledBlinkTimer: TimeInterval = 0
    private let ledBlinkInterval: TimeInterval = 0.5

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Initialize subsystems
        simulationEngine = SimulationEngine(gameState: gameState)
        incidentScheduler = IncidentScheduler(gameState: gameState)
        inputHandler = InputHandler(gameState: gameState, scene: self)

        // Cache textures
        floorTexture = TextureFactory.floorTileTexture()
        selectionTexture = TextureFactory.selectionTileTexture()
        incidentTexture = TextureFactory.incidentIndicatorTexture()

        // Layer hierarchy
        floorLayer.zPosition = IsometricConstants.floorLayer
        equipmentLayer.zPosition = IsometricConstants.objectLayer
        effectLayer.zPosition = IsometricConstants.effectLayer
        addChild(floorLayer)
        addChild(equipmentLayer)
        addChild(effectLayer)

        // Camera
        cameraController.attach(to: self)
        cameraController.configure(
            gridWidth: gameState.gridWidth,
            gridHeight: gameState.gridHeight,
            sceneSize: size
        )
        cameraController.installGestures(on: view)

        // Build floor grid
        buildFloorGrid()

        // Place any pre-existing equipment (for loaded games)
        for (pos, eq) in gameState.placedEquipment {
            addEquipmentSprite(for: eq.type, at: pos, status: eq.status)
        }

        // Set level on subsystems
        let level = LevelDefinition.forLevel(gameState.currentLevel)
        simulationEngine.setLevel(level)
        incidentScheduler.setLevel(level)
    }

    override func willMove(from view: SKView) {
        cameraController.removeGestures(from: view)
    }

    // MARK: - Floor Grid

    private func buildFloorGrid() {
        for col in 0..<gameState.gridWidth {
            for row in 0..<gameState.gridHeight {
                let screenPos = IsometricUtils.gridToScreen(col: col, row: row)
                let tile = SKSpriteNode(texture: floorTexture)
                tile.position = screenPos
                tile.zPosition = IsometricUtils.depthForPosition(col: col, row: row, layer: IsometricConstants.floorLayer)
                floorLayer.addChild(tile)
            }
        }
    }

    // MARK: - Equipment Sprites

    func addEquipmentSprite(for type: EquipmentType, at pos: GridPosition, status: EquipmentStatus = .normal) {
        // Remove old sprite if any
        equipmentSprites[pos]?.removeFromParent()

        let texture = cachedEquipmentTexture(type: type, status: status)
        let sprite = SKSpriteNode(texture: texture)
        let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)

        // Offset upward so block base sits on tile center
        let blockHeight = CGFloat(8 + type.tier * 8)
        sprite.position = CGPoint(x: screenPos.x, y: screenPos.y + blockHeight / 2)
        sprite.zPosition = IsometricUtils.depthForPosition(col: pos.col, row: pos.row, layer: IsometricConstants.objectLayer)

        equipmentLayer.addChild(sprite)
        equipmentSprites[pos] = sprite

        // Pop-in animation
        sprite.setScale(0)
        sprite.run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.08)
        ]))
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

        // Sync visual state
        syncEquipmentVisuals()
        syncIncidentIndicators()
        syncSelectionHighlight()
        syncGhostPreview()
    }

    // MARK: - Visual Sync

    private func syncEquipmentVisuals() {
        // Update textures for status changes and LED blinking
        for (pos, eq) in gameState.placedEquipment {
            guard let sprite = equipmentSprites[pos] else {
                // Equipment was placed but no sprite yet
                addEquipmentSprite(for: eq.type, at: pos, status: eq.status)
                continue
            }
            let tex = cachedEquipmentTexture(type: eq.type, status: eq.status)
            if sprite.texture !== tex {
                sprite.texture = tex
            }
            // LED blink: toggle alpha for rack LED effect
            if eq.type.category == .rack {
                sprite.alpha = ledBlinkPhase ? 1.0 : 0.85
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
        // Current incident positions
        let activePositions = Set(
            gameState.activeIncidents
                .filter { !$0.resolved && !$0.failed }
                .map(\.affectedPosition)
        )

        // Add missing indicators
        for pos in activePositions {
            if incidentIndicators[pos] == nil {
                let indicator = SKSpriteNode(texture: incidentTexture)
                let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
                indicator.position = CGPoint(x: screenPos.x, y: screenPos.y + 30)
                indicator.zPosition = IsometricConstants.effectLayer + 100
                effectLayer.addChild(indicator)

                // Pulsing animation
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.4),
                    SKAction.scale(to: 0.9, duration: 0.4)
                ]))
                indicator.run(pulse)

                incidentIndicators[pos] = indicator
            }
        }

        // Remove resolved indicators
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

    func resolveIncident(at position: GridPosition) {
        incidentScheduler.resolveIncident(at: position)

        // Flash effect on resolved rack
        if let sprite = equipmentSprites[position] {
            sprite.run(SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.3)
            ]))
        }
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

    // MARK: - Critical Incident Trigger (called from IncidentScheduler indirectly via sync)

    /// Called externally when a critical incident spawns to trigger screen shake.
    func onCriticalIncident() {
        screenShake(intensity: 12, duration: 0.5)
    }
}
