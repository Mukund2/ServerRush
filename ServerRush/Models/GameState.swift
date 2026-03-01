import Foundation
import Observation

// MARK: - Game Phase
enum GamePhase: Equatable {
    case mainMenu
    case playing
    case paused
    case levelComplete(stars: Int)
    case gameOver
}

// MARK: - Central Game State
@Observable
final class GameState {
    // Current level
    var currentLevel: Int = 1
    var phase: GamePhase = .mainMenu

    // Resources
    var money: Double = 500
    var revenuePerSecond: Double = 0
    var powerUsage: Double = 0
    var powerCapacity: Double = 100
    var coolingUsage: Double = 0
    var coolingCapacity: Double = 50
    var bandwidthUsage: Double = 0
    var bandwidthCapacity: Double = 100

    // Percentages for HUD
    var powerPercent: Double { powerCapacity > 0 ? (powerUsage / powerCapacity) * 100 : 0 }
    var coolingPercent: Double { coolingCapacity > 0 ? (coolingUsage / coolingCapacity) * 100 : 0 }
    var bandwidthPercent: Double { bandwidthCapacity > 0 ? (bandwidthUsage / bandwidthCapacity) * 100 : 0 }

    // Grid state
    var gridWidth: Int = 8
    var gridHeight: Int = 8
    var placedEquipment: [GridPosition: PlacedEquipment] = [:]

    // Incidents
    var activeIncidents: [ActiveIncident] = []
    var resolvedIncidentCount: Int = 0
    var failedIncidentCount: Int = 0

    // Uptime tracking
    var totalTicks: Int = 0
    var downtimeTicks: Int = 0
    var uptimePercent: Double {
        totalTicks > 0 ? Double(totalTicks - downtimeTicks) / Double(totalTicks) * 100 : 100
    }

    // Selection state
    var selectedTile: GridPosition? = nil
    var buildMode: EquipmentType? = nil
    var ghostPosition: GridPosition? = nil
    var ghostValid: Bool = false

    // AI Guide
    var guideMessage: String? = nil
    var guideVisible: Bool = false
    var showingGuideChat: Bool = false

    // Level timers
    var levelElapsedTime: TimeInterval = 0
    var revenueGoalMetTime: TimeInterval = 0
    var uptimeGoalMetTime: TimeInterval = 0

    // Unlocked equipment for current level
    var unlockedEquipment: [EquipmentType] = [.basicRack, .basicCooling, .basicPower]

    // MARK: - Computed

    var canBuild: Bool { buildMode != nil }

    func canAfford(_ type: EquipmentType) -> Bool {
        money >= type.cost
    }

    func isOccupied(_ pos: GridPosition) -> Bool {
        placedEquipment[pos] != nil
    }

    func isValidPlacement(_ pos: GridPosition) -> Bool {
        pos.col >= 0 && pos.col < gridWidth &&
        pos.row >= 0 && pos.row < gridHeight &&
        !isOccupied(pos)
    }

    // MARK: - Actions

    func placeEquipment(_ type: EquipmentType, at pos: GridPosition) {
        guard canAfford(type), isValidPlacement(pos) else { return }
        money -= type.cost
        let equipment = PlacedEquipment(type: type, position: pos)
        placedEquipment[pos] = equipment
        recalculateResources()
    }

    func sellEquipment(at pos: GridPosition) {
        guard let equipment = placedEquipment[pos] else { return }
        money += equipment.type.cost * 0.5
        placedEquipment.removeValue(forKey: pos)
        recalculateResources()
    }

    func upgradeEquipment(at pos: GridPosition) {
        guard let equipment = placedEquipment[pos],
              let upgrade = equipment.type.upgradesTo,
              canAfford(upgrade) else { return }
        money -= upgrade.cost
        placedEquipment[pos] = PlacedEquipment(type: upgrade, position: pos)
        recalculateResources()
    }

    func recalculateResources() {
        var power: Double = 0
        var powerCap: Double = 0
        var cooling: Double = 0
        var coolingCap: Double = 0
        var bandwidth: Double = 0
        var bandwidthCap: Double = 0
        var revenue: Double = 0

        for (_, eq) in placedEquipment {
            guard eq.status != .offline else { continue }
            let spec = eq.type.spec
            power += spec.powerDraw
            powerCap += spec.powerProvide
            cooling += spec.heatGenerate
            coolingCap += spec.coolingProvide
            bandwidth += spec.bandwidthUse
            bandwidthCap += spec.bandwidthProvide
            revenue += spec.revenuePerSec
        }

        powerUsage = power
        powerCapacity = max(powerCap, 1)
        coolingUsage = cooling
        coolingCapacity = max(coolingCap, 1)
        bandwidthUsage = bandwidth
        bandwidthCapacity = max(bandwidthCap, 1)
        revenuePerSecond = revenue
    }

    func resetForLevel(_ level: LevelDefinition) {
        currentLevel = level.id
        gridWidth = level.gridWidth
        gridHeight = level.gridHeight
        money = level.startingMoney
        placedEquipment.removeAll()
        activeIncidents.removeAll()
        resolvedIncidentCount = 0
        failedIncidentCount = 0
        totalTicks = 0
        downtimeTicks = 0
        levelElapsedTime = 0
        revenueGoalMetTime = 0
        uptimeGoalMetTime = 0
        selectedTile = nil
        buildMode = nil
        ghostPosition = nil
        unlockedEquipment = level.availableEquipment
        phase = .playing
        recalculateResources()
    }
}

// MARK: - Grid Position
struct GridPosition: Hashable, Codable {
    let col: Int
    let row: Int
}

// MARK: - Placed Equipment
struct PlacedEquipment: Identifiable {
    let id = UUID()
    let type: EquipmentType
    let position: GridPosition
    var status: EquipmentStatus = .normal
    var health: Double = 100
    var temperature: Double = 30 // Celsius

    var isOverheating: Bool { temperature > 80 }
    var isCritical: Bool { health < 25 }
}

enum EquipmentStatus: String {
    case normal
    case warning
    case critical
    case offline
}
