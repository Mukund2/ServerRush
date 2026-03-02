import Foundation

// MARK: - Expansion Definitions

/// Static data and milestone logic for the expansion system.
/// Replaces the old LevelDefinition system.
enum ExpansionDefinition {

    // MARK: - Milestone Definitions

    struct MilestoneDef {
        let type: MilestoneType
        let key: String
        let check: (GameState) -> Bool
    }

    /// Ordered list of all milestones. Checked in order; the first unachieved one whose condition is met fires.
    static let allMilestones: [MilestoneDef] = [
        MilestoneDef(
            type: .firstBuild,
            key: "firstBuild",
            check: { !$0.placedEquipment.isEmpty }
        ),
        MilestoneDef(
            type: .revenueTarget(500),
            key: "revenue_500",
            check: { $0.totalMoneyEarned >= 500 }
        ),
        MilestoneDef(
            type: .incidentsMastered(5),
            key: "incidents_5",
            check: { $0.totalIncidentsResolved >= 5 }
        ),
        MilestoneDef(
            type: .firstExpansion,
            key: "firstExpansion",
            check: { !$0.unlockedExpansions.isEmpty }
        ),
        MilestoneDef(
            type: .expansionUnlocked(1),
            key: "expansion_1",
            check: { $0.unlockedExpansions.contains(1) }
        ),
        MilestoneDef(
            type: .expansionUnlocked(2),
            key: "expansion_2",
            check: { $0.unlockedExpansions.contains(2) }
        ),
        MilestoneDef(
            type: .revenueTarget(5000),
            key: "revenue_5000",
            check: { $0.totalMoneyEarned >= 5000 }
        ),
        MilestoneDef(
            type: .incidentsMastered(50),
            key: "incidents_50",
            check: { $0.totalIncidentsResolved >= 50 }
        ),
        MilestoneDef(
            type: .expansionUnlocked(3),
            key: "expansion_3",
            check: { $0.unlockedExpansions.contains(3) }
        ),
    ]

    // MARK: - Check Milestones

    /// Returns the next unachieved milestone whose condition is met, or nil.
    static func checkMilestones(state: GameState) -> MilestoneType? {
        for def in allMilestones {
            guard !state.achievedMilestones.contains(def.key) else { continue }
            if def.check(state) {
                return def.type
            }
        }
        return nil
    }

    /// Returns the milestone key for a given MilestoneType, used to record it in achievedMilestones.
    static func key(for milestone: MilestoneType) -> String? {
        allMilestones.first { $0.type == milestone }?.key
    }

    // MARK: - Next Objective

    /// Returns the next unachieved milestone as an Objective for the HUD.
    static func nextObjective(state: GameState) -> Objective? {
        for def in allMilestones {
            guard !state.achievedMilestones.contains(def.key) else { continue }

            switch def.type {
            case .firstBuild:
                return Objective(
                    description: "Place your first server rack",
                    targetValue: 1,
                    currentValue: state.placedEquipment.isEmpty ? 0 : 1
                )
            case .revenueTarget(let target):
                return Objective(
                    description: "Earn $\(Int(target)) total",
                    targetValue: target,
                    currentValue: state.totalMoneyEarned
                )
            case .incidentsMastered(let target):
                return Objective(
                    description: "Resolve \(target) incidents",
                    targetValue: Double(target),
                    currentValue: Double(state.totalIncidentsResolved)
                )
            case .firstExpansion:
                return Objective(
                    description: "Purchase your first expansion",
                    targetValue: 1,
                    currentValue: state.unlockedExpansions.isEmpty ? 0 : 1
                )
            case .expansionUnlocked(let n):
                return Objective(
                    description: "Unlock expansion \(n)",
                    targetValue: 1,
                    currentValue: state.unlockedExpansions.contains(n) ? 1 : 0
                )
            }
        }
        return nil
    }
}
