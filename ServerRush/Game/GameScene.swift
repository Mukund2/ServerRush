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
        floorLayer.zPosition = IsometricConstants.floorLayer
        equipmentLayer.zPosition = IsometricConstants.objectLayer
        effectLayer.zPosition = IsometricConstants.effectLayer
        guideLayer.zPosition = IsometricConstants.effectLayer + 50
        addChild(floorLayer)
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

        // Build floor grid (6x6 initial)
        buildFloorGrid()

        // Place any pre-existing equipment (for loaded games)
        for (pos, eq) in gameState.placedEquipment {
            addEquipmentSprite(for: eq.type, at: pos, status: eq.status)
        }

        // Spawn guide character
        spawnGuideCharacter()
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
        cameraController.configure(
            gridWidth: gameState.gridWidth,
            gridHeight: gameState.gridHeight,
            sceneSize: size
        )
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

        // Show welcome message after a short delay, auto-dismiss after 6 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.gameState.guideMessage = "Welcome! Tap BUILD below to place your first server rack."
            self?.gameState.guideVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.gameState.guideVisible = false
        }
    }

    private func updateGuideWander(dt: TimeInterval) {
        guideWanderTimer += dt
        guard guideWanderTimer >= guideWanderInterval else { return }
        guideWanderTimer = 0

        // Pick a random walkable grid position within all unlocked tiles
        var candidates: [GridPosition] = []
        for col in 0..<gameState.gridWidth {
            for row in 0..<gameState.gridHeight {
                let pos = GridPosition(col: col, row: row)
                if gameState.isUnlockedTile(col: col, row: row) && gameState.placedEquipment[pos] == nil {
                    candidates.append(pos)
                }
            }
        }
        guard let chosen = candidates.randomElement() else { return }
        let col = chosen.col
        let row = chosen.row

        let target = IsometricUtils.gridToScreen(col: col, row: row)
        let dest = CGPoint(x: target.x, y: target.y + 20)

        let moveAction = SKAction.move(to: dest, duration: 3.0)
        moveAction.timingMode = .easeInEaseOut
        guideSprite?.run(moveAction)
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
                icon.setScale(0.7)
                let screenPos = IsometricUtils.gridToScreen(col: pos.col, row: pos.row)
                icon.position = CGPoint(x: screenPos.x + 20, y: screenPos.y + 25)
                icon.zPosition = IsometricConstants.effectLayer + 80
                icon.name = "toolIcon_\(pos.col)_\(pos.row)"

                // Gentle bounce
                let bounce = SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 3, duration: 0.5),
                    SKAction.moveBy(x: 0, y: -3, duration: 0.5)
                ]))
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

        // Guide wander
        updateGuideWander(dt: dt)

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
                let dist = hypot(scenePoint.x - icon.position.x, scenePoint.y - icon.position.y)
                if dist < 24 {
                    return incident
                }
            }
        }
        return nil
    }
}
