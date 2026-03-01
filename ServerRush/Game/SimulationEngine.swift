import Foundation
import QuartzCore

// MARK: - Simulation Engine

final class SimulationEngine {

    private weak var gameState: GameState?
    private var level: LevelDefinition?

    // Tick accumulator
    private let tickInterval: TimeInterval = 1.0
    private var tickAccumulator: TimeInterval = 0

    // Sustain timer for level completion
    private var sustainTimer: TimeInterval = 0

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func setLevel(_ level: LevelDefinition) {
        self.level = level
        tickAccumulator = 0
        sustainTimer = 0
    }

    // MARK: - Main Update

    /// Called every frame from GameScene.update(_:). Accumulates time and fires ticks at 1-second intervals.
    func update(deltaTime dt: TimeInterval) {
        guard let state = gameState, state.phase == .playing else { return }

        state.levelElapsedTime += dt
        tickAccumulator += dt

        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            performTick()
        }
    }

    // MARK: - Tick

    private func performTick() {
        guard let state = gameState, let level = level else { return }

        state.totalTicks += 1

        // Revenue
        applyRevenue(state)

        // Resource balance
        checkResourceBalance(state)

        // Temperature simulation
        simulateTemperature(state)

        // Uptime tracking
        trackUptime(state)

        // Level completion check
        checkLevelCompletion(state, level: level)

        // Game-over check
        checkGameOver(state)

        // Recalculate derived values
        state.recalculateResources()
    }

    // MARK: - Revenue

    private func applyRevenue(_ state: GameState) {
        // Reduce revenue if there are active incidents
        var multiplier: Double = 1.0
        for incident in state.activeIncidents where !incident.resolved && !incident.failed {
            multiplier *= incident.type.revenueLossMultiplier
        }
        state.money += state.revenuePerSecond * multiplier
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
                // Heat up proportional to deficit
                eq.temperature += coolingDeficit * 0.05
            } else {
                // Cool down toward baseline (30 C)
                eq.temperature = max(30, eq.temperature - 2)
            }

            // Overheating damage
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

    // MARK: - Level Completion

    private func checkLevelCompletion(_ state: GameState, level: LevelDefinition) {
        let revenueGoalMet = state.revenuePerSecond >= level.revenueGoal
        let uptimeGoalMet = state.uptimePercent >= level.uptimeGoal

        if revenueGoalMet && uptimeGoalMet {
            sustainTimer += tickInterval
            if sustainTimer >= level.sustainDuration {
                let stars = level.starsForTime(state.levelElapsedTime)
                state.phase = .levelComplete(stars: stars)
            }
        } else {
            // Reset sustain timer if goals drop below threshold
            sustainTimer = max(0, sustainTimer - tickInterval * 0.5)
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
