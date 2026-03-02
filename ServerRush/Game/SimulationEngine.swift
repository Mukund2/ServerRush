import Foundation
import QuartzCore

// MARK: - Simulation Engine

final class SimulationEngine {

    private weak var gameState: GameState?

    // Tick accumulator
    private let tickInterval: TimeInterval = 1.0
    private var tickAccumulator: TimeInterval = 0

    init(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Main Update

    /// Called every frame from GameScene.update(_:). Accumulates time and fires ticks at 1-second intervals.
    func update(deltaTime dt: TimeInterval) {
        guard let state = gameState, state.phase == .playing else { return }

        state.playTime += dt
        tickAccumulator += dt

        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            performTick()
        }
    }

    // MARK: - Tick

    private func performTick() {
        guard let state = gameState else { return }

        state.totalTicks += 1

        // Revenue
        let revenue = applyRevenue(state)

        // Track lifetime earnings
        state.totalMoneyEarned += revenue

        // Resource balance
        checkResourceBalance(state)

        // Temperature simulation
        simulateTemperature(state)

        // Uptime tracking
        trackUptime(state)

        // Milestone check
        checkMilestones(state)

        // Update current objective
        state.currentObjective = ExpansionDefinition.nextObjective(state: state)

        // Game-over check
        checkGameOver(state)

        // Recalculate derived values
        state.recalculateResources()
    }

    // MARK: - Revenue

    /// Applies revenue for this tick and returns the amount earned.
    @discardableResult
    private func applyRevenue(_ state: GameState) -> Double {
        // Reduce revenue if there are active incidents
        var multiplier: Double = 1.0
        for incident in state.activeIncidents where !incident.resolved && !incident.failed {
            multiplier *= incident.type.revenueLossMultiplier
        }
        let earned = state.revenuePerSecond * multiplier
        state.money += earned
        return earned
    }

    // MARK: - Resource Balance

    private func checkResourceBalance(_ state: GameState) {
        let powerOverloaded = state.powerUsage > state.powerCapacity
        let coolingOverloaded = state.coolingUsage > state.coolingCapacity
        let bandwidthOverloaded = state.bandwidthUsage > state.bandwidthCapacity

        for pos in state.placedEquipment.keys {
            guard var eq = state.placedEquipment[pos] else { continue }
            guard eq.status != .offline else { continue }

            if eq.type.category == .rack {
                var damage: Double = 0
                if powerOverloaded { damage += 2 }
                if coolingOverloaded { damage += 3 }
                if bandwidthOverloaded { damage += 1 }

                if damage > 0 {
                    eq.health = max(0, eq.health - damage)
                    if eq.health <= 0 {
                        eq.status = .offline
                    } else if eq.health < 25 {
                        eq.status = .critical
                    } else if eq.health < 60 {
                        eq.status = .warning
                    }
                    state.placedEquipment[pos] = eq
                }
            }
        }
    }

    // MARK: - Temperature

    private func simulateTemperature(_ state: GameState) {
        let coolingDeficit = state.coolingUsage - state.coolingCapacity

        for pos in state.placedEquipment.keys {
            guard var eq = state.placedEquipment[pos] else { continue }
            guard eq.status != .offline else { continue }
            guard eq.type.category == .rack else { continue }

            if coolingDeficit > 0 {
                eq.temperature += coolingDeficit * 0.05
            } else {
                eq.temperature = max(30, eq.temperature - 2)
            }

            if eq.isOverheating {
                eq.health = max(0, eq.health - 3)
                if eq.health <= 0 {
                    eq.status = .offline
                } else {
                    eq.status = .critical
                }
            }

            state.placedEquipment[pos] = eq
        }
    }

    // MARK: - Uptime

    private func trackUptime(_ state: GameState) {
        let offlineRacks = state.placedEquipment.values.filter {
            $0.type.category == .rack && $0.status == .offline
        }
        if !offlineRacks.isEmpty {
            state.downtimeTicks += 1
        }
    }

    // MARK: - Milestones

    private func checkMilestones(_ state: GameState) {
        // 30-second cooldown between milestones to prevent rapid-fire popups
        guard state.playTime - state.lastMilestoneTime >= 30 else { return }

        if let milestone = ExpansionDefinition.checkMilestones(state: state),
           let key = ExpansionDefinition.key(for: milestone) {
            state.achievedMilestones.insert(key)
            state.lastMilestoneTime = state.playTime
            state.phase = .milestone(milestone)
        }
    }

    // MARK: - Game Over

    private func checkGameOver(_ state: GameState) {
        // All racks offline
        let racks = state.placedEquipment.values.filter { $0.type.category == .rack }
        if !racks.isEmpty && racks.allSatisfy({ $0.status == .offline }) {
            state.phase = .gameOver
            return
        }

        // Negative money with no revenue
        if state.money < -100 && state.revenuePerSecond <= 0 {
            state.phase = .gameOver
        }
    }
}
