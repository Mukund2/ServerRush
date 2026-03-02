import Foundation
import Observation

// MARK: - Game Phase
enum GamePhase: Equatable {
    case mainMenu
    case playing
    case paused
    case milestone(MilestoneType)
    case gameOver
}

// MARK: - Milestone Type
enum MilestoneType: Equatable {
    case firstBuild
    case firstExpansion
    case expansionUnlocked(Int)
    case revenueTarget(Double)
    case incidentsMastered(Int)
}

// MARK: - Objective
struct Objective {
    let description: String
    let targetValue: Double
    let currentValue: Double
    var progress: Double { min(currentValue / max(targetValue, 1), 1.0) }
}

// MARK: - Expansion Zone
struct ExpansionZone: Codable, Identifiable {
    let id: Int
    let minCol: Int
    let minRow: Int
    let maxCol: Int
    let maxRow: Int
    let cost: Double
    var unlocked: Bool
    let unlocksEquipment: [EquipmentType]

    func contains(col: Int, row: Int) -> Bool {
        col >= minCol && col <= maxCol && row >= minRow && row <= maxRow
    }
}

// MARK: - Central Game State
@Observable
final class GameState {
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

    // Grid state (full potential size; only unlocked zones are playable)
    var gridWidth: Int = 16
    var gridHeight: Int = 16
    var placedEquipment: [GridPosition: PlacedEquipment] = [:]

    // Incidents
    var activeIncidents: [ActiveIncident] = []
    var telegraphedIncidents: [TelegraphedIncident] = []
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

    // Unlocked equipment (grows with expansions)
    var unlockedEquipment: [EquipmentType] = [.basicRack, .basicCooling, .basicPower]

    // MARK: - Expansion System

    var expansionZones: [ExpansionZone] = ExpansionZone.defaultZones

    var unlockedExpansions: Set<Int> = []

    // MARK: - Progression Tracking

    var totalMoneyEarned: Double = 0
    var totalIncidentsResolved: Int = 0
    var playTime: TimeInterval = 0
    var currentObjective: Objective? = nil
    var achievedMilestones: Set<String> = []

    // MARK: - Computed

    var canBuild: Bool { buildMode != nil }

    /// Number of racks currently placed (used by IncidentScheduler for frequency scaling)
    var rackCount: Int {
        placedEquipment.values.filter { $0.type.category == .rack }.count
    }

    func canAfford(_ type: EquipmentType) -> Bool {
        money >= type.cost
    }

    func isOccupied(_ pos: GridPosition) -> Bool {
        placedEquipment[pos] != nil
    }

    /// A position is valid if it falls within the starting 6x6 area or any unlocked expansion zone, and is not occupied.
    func isValidPlacement(_ pos: GridPosition) -> Bool {
        guard !isOccupied(pos) else { return false }
        return isUnlockedTile(col: pos.col, row: pos.row)
    }

    /// Check if a grid tile is within the playable (unlocked) area.
    func isUnlockedTile(col: Int, row: Int) -> Bool {
        // Starting area: cols 5-10, rows 5-10
        if col >= 5 && col <= 10 && row >= 5 && row <= 10 {
            return true
        }
        // Check unlocked expansion zones
        for zone in expansionZones where zone.unlocked {
            if zone.contains(col: col, row: row) {
                return true
            }
        }
        return false
    }

    /// Whether a tile is at the edge of an unlocked area, adjacent to a locked expansion zone.
    func isExpansionBorderTile(col: Int, row: Int) -> Bool {
        for zone in expansionZones where !zone.unlocked {
            if zone.contains(col: col, row: row) {
                // Check if adjacent to any unlocked tile
                let neighbors = [
                    (col - 1, row), (col + 1, row),
                    (col, row - 1), (col, row + 1)
                ]
                for (nc, nr) in neighbors {
                    if isUnlockedTile(col: nc, row: nr) {
                        return true
                    }
                }
            }
        }
        return false
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

    // MARK: - Expansion Purchasing

    func purchaseExpansion(_ zone: ExpansionZone) {
        guard money >= zone.cost, !zone.unlocked else { return }
        money -= zone.cost

        // Mark zone as unlocked
        if let idx = expansionZones.firstIndex(where: { $0.id == zone.id }) {
            expansionZones[idx].unlocked = true
        }
        unlockedExpansions.insert(zone.id)

        // Unlock new equipment types
        for eqType in zone.unlocksEquipment {
            if !unlockedEquipment.contains(eqType) {
                unlockedEquipment.append(eqType)
            }
        }
    }

    // MARK: - New Game

    func startNewGame() {
        gridWidth = 16
        gridHeight = 16
        money = 500
        placedEquipment.removeAll()
        activeIncidents.removeAll()
        telegraphedIncidents.removeAll()
        resolvedIncidentCount = 0
        failedIncidentCount = 0
        totalTicks = 0
        downtimeTicks = 0
        selectedTile = nil
        buildMode = nil
        ghostPosition = nil
        unlockedEquipment = [.basicRack, .basicCooling, .basicPower]
        expansionZones = ExpansionZone.defaultZones
        unlockedExpansions = []
        totalMoneyEarned = 0
        totalIncidentsResolved = 0
        playTime = 0
        currentObjective = nil
        achievedMilestones = []
        phase = .playing
        recalculateResources()
    }

    // MARK: - Save / Load

    private static let saveKey = "ServerRush_SaveData"

    var hasSaveData: Bool {
        UserDefaults.standard.data(forKey: Self.saveKey) != nil
    }

    func saveGame() {
        let data = SaveData(
            money: money,
            placedEquipment: Array(placedEquipment.values),
            expansionZones: expansionZones,
            unlockedExpansions: unlockedExpansions,
            unlockedEquipment: unlockedEquipment,
            totalMoneyEarned: totalMoneyEarned,
            totalIncidentsResolved: totalIncidentsResolved,
            playTime: playTime,
            achievedMilestones: achievedMilestones,
            resolvedIncidentCount: resolvedIncidentCount,
            failedIncidentCount: failedIncidentCount,
            totalTicks: totalTicks,
            downtimeTicks: downtimeTicks
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    func loadGame() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let save = try? JSONDecoder().decode(SaveData.self, from: data) else { return }

        gridWidth = 16
        gridHeight = 16
        money = save.money
        placedEquipment = Dictionary(
            uniqueKeysWithValues: save.placedEquipment.map { ($0.position, $0) }
        )
        expansionZones = save.expansionZones
        unlockedExpansions = save.unlockedExpansions
        unlockedEquipment = save.unlockedEquipment
        totalMoneyEarned = save.totalMoneyEarned
        totalIncidentsResolved = save.totalIncidentsResolved
        playTime = save.playTime
        achievedMilestones = save.achievedMilestones
        resolvedIncidentCount = save.resolvedIncidentCount
        failedIncidentCount = save.failedIncidentCount
        totalTicks = save.totalTicks
        downtimeTicks = save.downtimeTicks

        activeIncidents = []
        telegraphedIncidents = []
        selectedTile = nil
        buildMode = nil
        ghostPosition = nil
        currentObjective = nil
        phase = .playing
        recalculateResources()
    }
}

// MARK: - Save Data (Codable wrapper)
private struct SaveData: Codable {
    let money: Double
    let placedEquipment: [PlacedEquipment]
    let expansionZones: [ExpansionZone]
    let unlockedExpansions: Set<Int>
    let unlockedEquipment: [EquipmentType]
    let totalMoneyEarned: Double
    let totalIncidentsResolved: Int
    let playTime: TimeInterval
    let achievedMilestones: Set<String>
    let resolvedIncidentCount: Int
    let failedIncidentCount: Int
    let totalTicks: Int
    let downtimeTicks: Int
}

// MARK: - Grid Position
struct GridPosition: Hashable, Codable {
    let col: Int
    let row: Int
}

// MARK: - Placed Equipment
struct PlacedEquipment: Identifiable, Codable {
    let id: UUID
    let type: EquipmentType
    let position: GridPosition
    var status: EquipmentStatus = .normal
    var health: Double = 100
    var temperature: Double = 30

    var isOverheating: Bool { temperature > 80 }
    var isCritical: Bool { health < 25 }

    init(type: EquipmentType, position: GridPosition) {
        self.id = UUID()
        self.type = type
        self.position = position
    }
}

// MARK: - Equipment Status
enum EquipmentStatus: String, Codable {
    case normal
    case warning
    case critical
    case offline
}

// MARK: - Expansion Zone Defaults
extension ExpansionZone {
    /// Default expansion zone layout within a 16x16 grid.
    /// Starting area: cols 5-10, rows 5-10 (6x6 center).
    static let defaultZones: [ExpansionZone] = [
        // Expansion 1: surrounding ring (cols 3-12, rows 3-12), cost $500
        ExpansionZone(
            id: 1,
            minCol: 3, minRow: 3, maxCol: 12, maxRow: 12,
            cost: 500,
            unlocked: false,
            unlocksEquipment: [.advancedRack, .coolingTower]
        ),
        // Expansion 2: next ring (cols 1-14, rows 1-14), cost $1500
        ExpansionZone(
            id: 2,
            minCol: 1, minRow: 1, maxCol: 14, maxRow: 14,
            cost: 1500,
            unlocked: false,
            unlocksEquipment: [.ups, .networkSwitch, .firewall]
        ),
        // Expansion 3: full 16x16 (cols 0-15, rows 0-15), cost $5000
        ExpansionZone(
            id: 3,
            minCol: 0, minRow: 0, maxCol: 15, maxRow: 15,
            cost: 5000,
            unlocked: false,
            unlocksEquipment: [.enterpriseRack, .liquidCooling, .loadBalancer]
        ),
    ]
}
