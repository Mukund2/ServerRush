import SpriteKit

// MARK: - Input State

enum InputState {
    case idle
    case selecting
    case placing
    case draggingTool(IncidentTool, ActiveIncident)
}

// MARK: - Input Handler

final class InputHandler {

    private weak var gameState: GameState?
    private weak var scene: GameScene?

    private(set) var state: InputState = .idle

    // Drag tracking
    private var dragStartPoint: CGPoint = .zero

    init(gameState: GameState, scene: GameScene) {
        self.gameState = gameState
        self.scene = scene
    }

    // MARK: - Touch Began

    func touchBegan(at scenePoint: CGPoint) {
        guard let state = gameState, let scene = scene else { return }

        // Check if tapping a tool icon (start drag)
        if let incident = scene.incidentForToolIcon(at: scenePoint) {
            let tool = incident.requiredTool
            self.state = .draggingTool(tool, incident)
            dragStartPoint = scenePoint

            // Create dragged tool sprite
            let texture = TextureFactory.toolIconTexture(tool: tool)
            let dragSprite = SKSpriteNode(texture: texture)
            dragSprite.position = scenePoint
            dragSprite.zPosition = IsometricConstants.uiLayer + 100
            dragSprite.setScale(0.9)
            scene.addChild(dragSprite)
            scene.draggedToolSprite = dragSprite

            AudioManager.shared.playToolDrag()
            return
        }

        if state.buildMode != nil {
            self.state = .placing
            updateGhostPosition(at: scenePoint)
        } else {
            self.state = .selecting
        }
    }

    // MARK: - Touch Moved

    func touchMoved(at scenePoint: CGPoint) {
        switch state {
        case .placing:
            updateGhostPosition(at: scenePoint)

        case .draggingTool:
            // Move the dragged tool sprite
            scene?.draggedToolSprite?.position = scenePoint

        default:
            break
        }
    }

    // MARK: - Touch Ended

    func touchEnded(at scenePoint: CGPoint) {
        guard let gs = gameState, let scene = scene else { return }

        switch state {
        case .placing:
            attemptPlacement(at: scenePoint)

        case .draggingTool(let tool, let incident):
            // Check if dropped on the correct incident rack
            let gridPos = IsometricUtils.screenToGridPosition(point: scenePoint)

            if gridPos == incident.affectedPosition {
                // Correct drop: resolve incident
                scene.resolveIncident(at: incident.affectedPosition, withTool: tool)
                AudioManager.shared.playToolDrop()
            } else {
                // Wrong drop: bounce back and error haptic
                AudioManager.shared.playToolMiss()
                if let dragSprite = scene.draggedToolSprite {
                    dragSprite.run(SKAction.sequence([
                        SKAction.scale(to: 0.5, duration: 0.15),
                        SKAction.fadeOut(withDuration: 0.15),
                        SKAction.removeFromParent()
                    ]))
                    scene.draggedToolSprite = nil
                }
            }

            // Clean up drag sprite
            if let dragSprite = scene.draggedToolSprite {
                dragSprite.removeFromParent()
                scene.draggedToolSprite = nil
            }

        case .selecting, .idle:
            let gridPos = IsometricUtils.screenToGridPosition(point: scenePoint)

            // Check if tapping an expansion zone border tile
            if let zone = findExpansionZone(at: gridPos) {
                if gs.money >= zone.cost {
                    gs.purchaseExpansion(zone)
                    scene.rebuildFloorGrid()
                    AudioManager.shared.playExpansionUnlock()
                }
                self.state = .idle
                return
            }

            // Select/deselect tile (only within unlocked area)
            if gs.isUnlockedTile(col: gridPos.col, row: gridPos.row) {
                if gs.selectedTile == gridPos {
                    gs.selectedTile = nil
                } else {
                    gs.selectedTile = gridPos
                }
            } else {
                gs.selectedTile = nil
            }
        }

        self.state = .idle
    }

    // MARK: - Touch Cancelled

    func touchCancelled() {
        guard let gs = gameState else { return }

        // Clean up drag sprite
        if let dragSprite = scene?.draggedToolSprite {
            dragSprite.removeFromParent()
            scene?.draggedToolSprite = nil
        }

        gs.ghostPosition = nil
        state = .idle
    }

    // MARK: - Ghost Preview

    private func updateGhostPosition(at scenePoint: CGPoint) {
        guard let gs = gameState else { return }
        let gridPos = IsometricUtils.screenToGridPosition(point: scenePoint)
        gs.ghostPosition = gridPos
        gs.ghostValid = gs.isValidPlacement(gridPos) && gs.canAfford(gs.buildMode!)
    }

    // MARK: - Placement

    private func attemptPlacement(at scenePoint: CGPoint) {
        guard let gs = gameState, let buildType = gs.buildMode else { return }

        let gridPos = IsometricUtils.screenToGridPosition(point: scenePoint)

        if gs.isValidPlacement(gridPos) && gs.canAfford(buildType) {
            gs.placeEquipment(buildType, at: gridPos)
            scene?.addEquipmentSprite(for: buildType, at: gridPos)
            AudioManager.shared.playBuildSound()
        }

        gs.ghostPosition = nil
    }

    // MARK: - Expansion Zone Lookup

    /// Find an unlockable expansion zone at the given grid position.
    private func findExpansionZone(at pos: GridPosition) -> ExpansionZone? {
        guard let gs = gameState else { return nil }

        // Only trigger on border tiles (not already unlocked)
        guard gs.isExpansionBorderTile(col: pos.col, row: pos.row) else { return nil }

        // Find the smallest locked zone containing this position
        return gs.expansionZones
            .filter { !$0.unlocked && $0.contains(col: pos.col, row: pos.row) }
            .sorted { ($0.maxCol - $0.minCol) < ($1.maxCol - $1.minCol) }
            .first
    }
}
