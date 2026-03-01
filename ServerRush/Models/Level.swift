import Foundation

// MARK: - Level Definition
struct LevelDefinition {
    let id: Int
    let name: String
    let subtitle: String
    let gridWidth: Int
    let gridHeight: Int
    let startingMoney: Double
    let availableEquipment: [EquipmentType]
    let availableIncidents: [IncidentType]
    let revenueGoal: Double      // $/sec needed
    let uptimeGoal: Double       // percentage needed
    let sustainDuration: TimeInterval  // how long to sustain goals
    let incidentFrequencyRange: ClosedRange<TimeInterval> // min...max seconds between incidents

    // Star thresholds
    let oneStarTime: TimeInterval    // complete within this for 1 star
    let twoStarTime: TimeInterval    // complete within this for 2 stars
    let threeStarTime: TimeInterval  // complete within this for 3 stars

    func starsForTime(_ time: TimeInterval) -> Int {
        if time <= threeStarTime { return 3 }
        if time <= twoStarTime { return 2 }
        if time <= oneStarTime { return 1 }
        return 1 // always at least 1 star for completing
    }
}

// MARK: - Level Definitions
extension LevelDefinition {
    static let allLevels: [LevelDefinition] = [level1, level2, level3]

    static let level1 = LevelDefinition(
        id: 1,
        name: "The Server Closet",
        subtitle: "Every empire starts somewhere...",
        gridWidth: 8,
        gridHeight: 8,
        startingMoney: 500,
        availableEquipment: [.basicRack, .basicCooling, .basicPower],
        availableIncidents: [.overheating, .cableFailure],
        revenueGoal: 50,
        uptimeGoal: 90,
        sustainDuration: 60,
        incidentFrequencyRange: 15...30,
        oneStarTime: 600,
        twoStarTime: 420,
        threeStarTime: 300
    )

    static let level2 = LevelDefinition(
        id: 2,
        name: "The Data Center",
        subtitle: "Time to scale up operations",
        gridWidth: 12,
        gridHeight: 10,
        startingMoney: 1000,
        availableEquipment: [.basicRack, .advancedRack, .basicCooling, .coolingTower, .basicPower, .ups, .networkSwitch],
        availableIncidents: [.overheating, .cableFailure, .ddosAttack, .powerOutage],
        revenueGoal: 200,
        uptimeGoal: 95,
        sustainDuration: 120,
        incidentFrequencyRange: 12...25,
        oneStarTime: 900,
        twoStarTime: 600,
        threeStarTime: 420
    )

    static let level3 = LevelDefinition(
        id: 3,
        name: "Enterprise Campus",
        subtitle: "Go big or go home",
        gridWidth: 16,
        gridHeight: 14,
        startingMoney: 2000,
        availableEquipment: EquipmentType.allCases,
        availableIncidents: IncidentType.allCases,
        revenueGoal: 500,
        uptimeGoal: 99,
        sustainDuration: 180,
        incidentFrequencyRange: 8...18,
        oneStarTime: 1200,
        twoStarTime: 900,
        threeStarTime: 600
    )

    static func forLevel(_ id: Int) -> LevelDefinition {
        allLevels.first { $0.id == id } ?? level1
    }
}
