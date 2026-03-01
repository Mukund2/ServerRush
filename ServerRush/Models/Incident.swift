import Foundation
import QuartzCore

// MARK: - Incident Type
enum IncidentType: String, CaseIterable {
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
        case .overheating: return "Server temperature critical! Tap to activate emergency cooling."
        case .ddosAttack: return "Bandwidth overwhelmed! Tap to enable firewall filters."
        case .powerOutage: return "Power grid failing! Tap to switch to backup generator."
        case .cableFailure: return "Network cable disconnected! Tap to reconnect."
        }
    }

    var timeToResolve: TimeInterval { 10 } // seconds before auto-fail

    var damagePerTick: Double {
        switch self {
        case .overheating: return 5
        case .ddosAttack: return 2
        case .powerOutage: return 8
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

    var availableInLevel: Int {
        switch self {
        case .overheating: return 1
        case .cableFailure: return 1
        case .ddosAttack: return 2
        case .powerOutage: return 2
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
}

// MARK: - Active Incident
struct ActiveIncident: Identifiable {
    let id = UUID()
    let type: IncidentType
    let affectedPosition: GridPosition
    let startTime: TimeInterval
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
