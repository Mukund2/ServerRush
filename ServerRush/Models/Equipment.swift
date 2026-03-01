import Foundation
import SpriteKit

// MARK: - Equipment Type
enum EquipmentType: String, CaseIterable, Identifiable {
    // Racks
    case basicRack
    case advancedRack
    case enterpriseRack

    // Cooling
    case basicCooling
    case coolingTower
    case liquidCooling

    // Power
    case basicPower
    case ups
    case industrialPower

    // Network
    case networkSwitch
    case firewall
    case loadBalancer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basicRack: return "Basic Rack"
        case .advancedRack: return "Advanced Rack"
        case .enterpriseRack: return "Enterprise Rack"
        case .basicCooling: return "AC Unit"
        case .coolingTower: return "Cooling Tower"
        case .liquidCooling: return "Liquid Cooling"
        case .basicPower: return "Generator"
        case .ups: return "UPS"
        case .industrialPower: return "Industrial PSU"
        case .networkSwitch: return "Switch"
        case .firewall: return "Firewall"
        case .loadBalancer: return "Load Balancer"
        }
    }

    var icon: String {
        switch self {
        case .basicRack, .advancedRack, .enterpriseRack: return "server.rack"
        case .basicCooling, .coolingTower, .liquidCooling: return "snowflake"
        case .basicPower, .ups, .industrialPower: return "bolt.fill"
        case .networkSwitch, .firewall, .loadBalancer: return "network"
        }
    }

    var category: EquipmentCategory {
        switch self {
        case .basicRack, .advancedRack, .enterpriseRack: return .rack
        case .basicCooling, .coolingTower, .liquidCooling: return .cooling
        case .basicPower, .ups, .industrialPower: return .power
        case .networkSwitch, .firewall, .loadBalancer: return .network
        }
    }

    var cost: Double {
        switch self {
        case .basicRack: return 50
        case .advancedRack: return 150
        case .enterpriseRack: return 500
        case .basicCooling: return 30
        case .coolingTower: return 120
        case .liquidCooling: return 400
        case .basicPower: return 40
        case .ups: return 100
        case .industrialPower: return 350
        case .networkSwitch: return 60
        case .firewall: return 200
        case .loadBalancer: return 300
        }
    }

    var upgradesTo: EquipmentType? {
        switch self {
        case .basicRack: return .advancedRack
        case .advancedRack: return .enterpriseRack
        case .basicCooling: return .coolingTower
        case .coolingTower: return .liquidCooling
        case .basicPower: return .ups
        case .ups: return .industrialPower
        case .networkSwitch: return .firewall
        case .firewall: return .loadBalancer
        default: return nil
        }
    }

    var spec: EquipmentSpec {
        switch self {
        case .basicRack:
            return EquipmentSpec(powerDraw: 10, heatGenerate: 15, bandwidthUse: 10, revenuePerSec: 5)
        case .advancedRack:
            return EquipmentSpec(powerDraw: 20, heatGenerate: 25, bandwidthUse: 20, revenuePerSec: 15)
        case .enterpriseRack:
            return EquipmentSpec(powerDraw: 35, heatGenerate: 40, bandwidthUse: 35, revenuePerSec: 40)
        case .basicCooling:
            return EquipmentSpec(powerDraw: 5, coolingProvide: 30)
        case .coolingTower:
            return EquipmentSpec(powerDraw: 10, coolingProvide: 70)
        case .liquidCooling:
            return EquipmentSpec(powerDraw: 15, coolingProvide: 150)
        case .basicPower:
            return EquipmentSpec(powerProvide: 50)
        case .ups:
            return EquipmentSpec(powerProvide: 120)
        case .industrialPower:
            return EquipmentSpec(powerProvide: 300)
        case .networkSwitch:
            return EquipmentSpec(powerDraw: 3, bandwidthProvide: 50)
        case .firewall:
            return EquipmentSpec(powerDraw: 5, bandwidthProvide: 80)
        case .loadBalancer:
            return EquipmentSpec(powerDraw: 8, bandwidthProvide: 200)
        }
    }

    // Colors for programmatic sprite generation
    var baseColor: SKColor {
        switch category {
        case .rack: return SKColor(red: 0.2, green: 0.8, blue: 0.6, alpha: 1) // Teal
        case .cooling: return SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1) // Blue
        case .power: return SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1) // Yellow
        case .network: return SKColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 1) // Purple
        }
    }

    var tier: Int {
        switch self {
        case .basicRack, .basicCooling, .basicPower, .networkSwitch: return 1
        case .advancedRack, .coolingTower, .ups, .firewall: return 2
        case .enterpriseRack, .liquidCooling, .industrialPower, .loadBalancer: return 3
        }
    }
}

// MARK: - Equipment Category
enum EquipmentCategory: String, CaseIterable {
    case rack = "Servers"
    case cooling = "Cooling"
    case power = "Power"
    case network = "Network"

    var icon: String {
        switch self {
        case .rack: return "server.rack"
        case .cooling: return "snowflake"
        case .power: return "bolt.fill"
        case .network: return "network"
        }
    }
}

// MARK: - Equipment Spec
struct EquipmentSpec {
    var powerDraw: Double = 0
    var powerProvide: Double = 0
    var heatGenerate: Double = 0
    var coolingProvide: Double = 0
    var bandwidthUse: Double = 0
    var bandwidthProvide: Double = 0
    var revenuePerSec: Double = 0
}
