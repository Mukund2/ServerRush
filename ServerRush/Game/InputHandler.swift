import SpriteKit

// MARK: - Input State

enum InputState {
    case idle
    case selecting
    case placing
    case dragging
}

// MARK: - Input Handler

final class InputHandler {

    private weak var gameState: GameState?
    private weak var scene: GameScene?

    private(set) var state: InputState = .idle

    init(gameState: GameState, scene: GameScene) {
        self.gameState = gameState
        self.scene = scene
    }

    // MARK: - Touch Began

    func touchBegan(at scenePoint: CGPoint) {
        guard let state = gameState else { return }

        if state.buildMode != nil {
            self.state = .placing
            updateGhostPosition(at: scenePoint)
        } else {
            self.state = .selecting
        }
    }

    // MARK: - Touch Moved

    func touchMoved(at scenePoint: CGPoint) {
        guard gameState?.buildMode != nil else { return }
        if state == .placing {
            updateGhostPosition(at: scenePoint)
        }
    }

    // MARK: - Touch Ended

    func touchEnded(at scenePoint: CGPoint) {
        guard let gs = gameState else { return }

        switch state {
        case .placing:
            attemptPlacement(at: scenePoint)

        case .selecting, .idle:
            let gridPos = IsometricUtils.screenToGridPosition(point: scenePoint)

            // Check if tapping an incident rack
            if let incident = gs.activeIncidents.first(where: {
                $0.affectedPosition == gridPos && !$0.resolved && !$0.failed
            }) {
                scene?.resolveIncident(at: incident.affectedPosition)
                self.state = .idle
                return
            }

            // Select/deselect tile
            if gridPos.col >= 0 && gridPos.col < gs.gridWidth &&
               gridPos.row >= 0 && gridPos.row < gs.gridHeight {
                if gs.selectedTile == gridPos {
                    gs.selectedTile = nil
                } else {
                    gs.selectedTile = gridPos
                }
            } else {
                gs.selectedTile = nil
            }

        case .dragging:
            break
        }

        self.state = .idle
    }

    // MARK: - Touch Cancelled

    func touchCancelled() {
        guard let gs = gameState else { return }
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
        }

        gs.ghostPosition = nil
    }
}
