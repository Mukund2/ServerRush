import Foundation
import QuartzCore

// MARK: - Incident Scheduler

final class IncidentScheduler {

    private weak var gameState: GameState?
    private var level: LevelDefinition?

    // Per-type cooldown tracking (time remaining before this type can fire again)
    private var cooldowns: [IncidentType: TimeInterval] = [:]

    // Time until next incident attempt
    private var nextIncidentTimer: TimeInterval = 0

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func setLevel(_ level: LevelDefinition) {
        self.level = level
        cooldowns.removeAll()
        // Initial delay before first incident
        nextIncidentTimer = level.incidentFrequencyRange.lowerBound
    }

    // MARK: - Tick (called once per second from GameScene)

    func tick() {
        guard let state = gameState, let level = level else { return }
        guard state.phase == .playing else { return }

        // Decrement cooldowns
        for type in cooldowns.keys {
            cooldowns[type] = max(0, (cooldowns[type] ?? 0) - 1)
        }

        // Monitor active incidents: expire unresolved ones
        processActiveIncidents(state)

        // Spawn new incidents
        nextIncidentTimer -= 1
        if nextIncidentTimer <= 0 {
            attemptSpawnIncident(state, level: level)
            // Randomize next spawn interval
            let lo = level.incidentFrequencyRange.lowerBound
            let hi = level.incidentFrequencyRange.upperBound
            nextIncidentTimer = TimeInterval.random(in: lo...hi)
        }
    }

    // MARK: - Process Active

    private func processActiveIncidents(_ state: GameState) {
        var updatedIncidents: [ActiveIncident] = []

        for var incident in state.activeIncidents {
            if incident.resolved || incident.failed {
                updatedIncidents.append(incident)
                continue
            }

            if incident.isExpired {
                // Failed to resolve in time
                incident.failed = true
                state.failedIncidentCount += 1
                applyIncidentDamage(incident, state: state)
                updatedIncidents.append(incident)
            } else {
                // Still active, apply per-tick damage
                applyTickDamage(incident, state: state)
                updatedIncidents.append(incident)
            }
        }

        // Remove resolved/failed incidents that have been around for a while
        state.activeIncidents = updatedIncidents.filter { incident in
            if incident.resolved { return false }
            if incident.failed { return false }
            return true
        }
    }

    private func applyTickDamage(_ incident: ActiveIncident, state: GameState) {
        guard var eq = state.placedEquipment[incident.affectedPosition] else { return }
        guard eq.status != .offline else { return }

        eq.health = max(0, eq.health - incident.type.damagePerTick)
        if eq.health <= 0 {
            eq.status = .offline
        } else if eq.health < 25 {
            eq.status = .critical
        } else if eq.health < 60 {
            eq.status = .warning
        }
        state.placedEquipment[incident.affectedPosition] = eq
    }

    private func applyIncidentDamage(_ incident: ActiveIncident, state: GameState) {
        // Extra damage on failure
        guard var eq = state.placedEquipment[incident.affectedPosition] else { return }
        eq.health = max(0, eq.health - 30)
        if eq.health <= 0 {
            eq.status = .offline
        } else {
            eq.status = .critical
        }
        state.placedEquipment[incident.affectedPosition] = eq

        // Power outage escalation: affect adjacent racks
        if incident.type == .powerOutage {
            escalatePowerOutage(from: incident.affectedPosition, state: state)
        }
    }

    // MARK: - Spawn

    private func attemptSpawnIncident(_ state: GameState, level: LevelDefinition) {
        // Filter to incident types available in this level and off cooldown
        let eligible = level.availableIncidents.filter { type in
            (cooldowns[type] ?? 0) <= 0
        }
        guard !eligible.isEmpty else { return }

        // Find online racks to target
        let onlineRacks = state.placedEquipment.filter {
            $0.value.type.category == .rack && $0.value.status != .offline
        }
        guard !onlineRacks.isEmpty else { return }

        // Already has incident on this position?
        let incidentPositions = Set(state.activeIncidents.map(\.affectedPosition))
        let targetable = onlineRacks.filter { !incidentPositions.contains($0.key) }
        guard !targetable.isEmpty else { return }

        // Pick random type and target
        let type = eligible.randomElement()!
        let target = targetable.randomElement()!

        let incident = ActiveIncident(
            type: type,
            affectedPosition: target.key,
            startTime: CACurrentMediaTime()
        )
        state.activeIncidents.append(incident)

        // Set cooldown
        cooldowns[type] = type.baseCooldown
    }

    // MARK: - Escalation

    private func escalatePowerOutage(from position: GridPosition, state: GameState) {
        // Affect all racks within 2-tile radius
        for pos in state.placedEquipment.keys {
            guard var eq = state.placedEquipment[pos] else { continue }
            guard eq.type.category == .rack, eq.status != .offline else { continue }
            let dist = abs(pos.col - position.col) + abs(pos.row - position.row)
            if dist <= 2 && pos != position {
                eq.health = max(0, eq.health - 15)
                if eq.health <= 0 {
                    eq.status = .offline
                } else if eq.health < 25 {
                    eq.status = .critical
                }
                state.placedEquipment[pos] = eq
            }
        }
    }

    // MARK: - Public: Resolve

    func resolveIncident(at position: GridPosition) {
        guard let state = gameState else { return }
        if let idx = state.activeIncidents.firstIndex(where: {
            $0.affectedPosition == position && !$0.resolved && !$0.failed
        }) {
            state.activeIncidents[idx].resolved = true
            state.resolvedIncidentCount += 1

            // Partial health recovery
            if var eq = state.placedEquipment[position] {
                eq.health = min(100, eq.health + 10)
                if eq.health > 60 {
                    eq.status = .normal
                } else if eq.health > 25 {
                    eq.status = .warning
                }
                state.placedEquipment[position] = eq
            }
        }
    }
}
