import Foundation
import QuartzCore

// MARK: - Incident Tool (drag-to-fix)

enum IncidentTool: String, CaseIterable, Codable {
    case fireExtinguisher  // for overheating
    case shield            // for DDoS
    case wrench            // for power outage
    case cablePlug         // for cable failure

    var displayName: String {
        switch self {
        case .fireExtinguisher: return "Fire Extinguisher"
        case .shield: return "Shield"
        case .wrench: return "Wrench"
        case .cablePlug: return "Cable"
        }
    }

    var icon: String {
        switch self {
        case .fireExtinguisher: return "fire.extinguisher.fill"
        case .shield: return "shield.fill"
        case .wrench: return "wrench.fill"
        case .cablePlug: return "cable.connector.horizontal"
        }
    }
}

// MARK: - Incident Type
enum IncidentType: String, CaseIterable, Codable {
    case overheating
    case ddosAttack
    case powerOutage
    case cableFailure

    var displayName: String {
        switch self {
        case .overheating: return "Overheating!"
        case .ddosAttack: return "DDoS Attack!"
        case .powerOutage: return "Power Outage!"
        case .cableFailure: return "Cable Failure!"
        }
    }

    var icon: String {
        switch self {
        case .overheating: return "flame.fill"
        case .ddosAttack: return "shield.slash.fill"
        case .powerOutage: return "bolt.slash.fill"
        case .cableFailure: return "cable.connector.horizontal"
        }
    }

    var color: String {
        switch self {
        case .overheating: return "red"
        case .ddosAttack: return "purple"
        case .powerOutage: return "yellow"
        case .cableFailure: return "orange"
        }
    }

    var description: String {
        switch self {
        case .overheating: return "Server temperature critical! Drag the extinguisher to cool it down."
        case .ddosAttack: return "Bandwidth overwhelmed! Drag the shield to block the attack."
        case .powerOutage: return "Power grid failing! Drag the wrench to restore power."
        case .cableFailure: return "Network cable disconnected! Drag the cable to reconnect."
        }
    }

    /// Seconds before auto-fail — easier incidents are more forgiving
    var timeToResolve: TimeInterval {
        switch self {
        case .overheating: return 12
        case .cableFailure: return 12
        case .ddosAttack: return 10
        case .powerOutage: return 10
        }
    }

    var damagePerTick: Double {
        switch self {
        case .overheating: return 4
        case .ddosAttack: return 2
        case .powerOutage: return 5
        case .cableFailure: return 3
        }
    }

    var revenueLossMultiplier: Double {
        switch self {
        case .overheating: return 0.5
        case .ddosAttack: return 0.3
        case .powerOutage: return 0.0
        case .cableFailure: return 0.7
        }
    }

    var baseCooldown: TimeInterval {
        switch self {
        case .overheating: return 20
        case .cableFailure: return 25
        case .ddosAttack: return 30
        case .powerOutage: return 40
        }
    }

    var requiredTool: IncidentTool {
        switch self {
        case .overheating: return .fireExtinguisher
        case .ddosAttack: return .shield
        case .powerOutage: return .wrench
        case .cableFailure: return .cablePlug
        }
    }
}

// MARK: - Active Incident
struct ActiveIncident: Identifiable {
    let id = UUID()
    let type: IncidentType
    let affectedPosition: GridPosition
    let startTime: TimeInterval
    let requiredTool: IncidentTool
    var resolved: Bool = false
    var failed: Bool = false

    var timeRemaining: TimeInterval {
        max(0, type.timeToResolve - (CACurrentMediaTime() - startTime))
    }

    var progress: Double {
        1.0 - (timeRemaining / type.timeToResolve)
    }

    var isExpired: Bool {
        timeRemaining <= 0
    }
}

// MARK: - Telegraphed Incident
struct TelegraphedIncident: Identifiable {
    let id = UUID()
    let type: IncidentType
    let position: GridPosition
    var countdown: TimeInterval = 2.0
}
