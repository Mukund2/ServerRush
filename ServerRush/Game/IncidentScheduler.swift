import Foundation
import QuartzCore

// MARK: - Incident Scheduler

final class IncidentScheduler {

    private weak var gameState: GameState?

    // Per-type cooldown tracking (time remaining before this type can fire again)
    private var cooldowns: [IncidentType: TimeInterval] = [:]

    // Time until next incident attempt
    private var nextIncidentTimer: TimeInterval = 0

    init(gameState: GameState) {
        self.gameState = gameState
        // Generous initial grace period — let the player build without pressure
        nextIncidentTimer = 30
    }

    // MARK: - Frequency Scaling

    /// Returns the spawn interval range based on how many racks the player has.
    /// More racks = more frequent incidents. Early game is gentler.
    private func incidentInterval(rackCount: Int) -> ClosedRange<TimeInterval> {
        switch rackCount {
        case 0: return 30...45
        case 1: return 25...40
        case 2...3: return 18...30
        case 4...6: return 12...22
        case 7...10: return 8...16
        default: return max(5, 15 - Double(rackCount))...max(10, 22 - Double(rackCount))
        }
    }

    /// Returns which incident types are available based on the player's rack count.
    /// Gradually introduces harder incidents so new players aren't overwhelmed.
    private func availableIncidentTypes(rackCount: Int) -> [IncidentType] {
        var types: [IncidentType] = [.overheating]  // always available
        if rackCount >= 3 { types.append(.cableFailure) }
        if rackCount >= 5 { types.append(.ddosAttack) }
        if rackCount >= 7 { types.append(.powerOutage) }
        return types
    }

    // MARK: - Tick (called once per second from GameScene)

    func tick() {
        guard let state = gameState else { return }
        guard state.phase == .playing else { return }

        // Decrement cooldowns
        for type in cooldowns.keys {
            cooldowns[type] = max(0, (cooldowns[type] ?? 0) - 1)
        }

        // Process telegraphed incidents (count down and convert to real incidents)
        processTelegraphs(state)

        // Monitor active incidents: expire unresolved ones
        processActiveIncidents(state)

        // Spawn new incidents (as telegraphs first)
        nextIncidentTimer -= 1
        if nextIncidentTimer <= 0 {
            attemptSpawnTelegraph(state)
            let range = incidentInterval(rackCount: state.rackCount)
            nextIncidentTimer = TimeInterval.random(in: range)
        }
    }

    // MARK: - Telegraph Processing

    private func processTelegraphs(_ state: GameState) {
        var remaining: [TelegraphedIncident] = []

        for var telegraph in state.telegraphedIncidents {
            telegraph.countdown -= 1
            if telegraph.countdown <= 0 {
                // Convert to real incident
                let incident = ActiveIncident(
                    type: telegraph.type,
                    affectedPosition: telegraph.position,
                    startTime: CACurrentMediaTime(),
                    requiredTool: telegraph.type.requiredTool
                )
                state.activeIncidents.append(incident)
            } else {
                remaining.append(telegraph)
            }
        }

        state.telegraphedIncidents = remaining
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

        // Remove resolved/failed incidents
        state.activeIncidents = updatedIncidents.filter { incident in
            !incident.resolved && !incident.failed
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

    // MARK: - Spawn (Telegraph)

    private func attemptSpawnTelegraph(_ state: GameState) {
        // Gate incident types by rack count so difficulty ramps gradually
        let available = availableIncidentTypes(rackCount: state.rackCount)
        let eligible = available.filter { type in
            (cooldowns[type] ?? 0) <= 0
        }
        guard !eligible.isEmpty else { return }

        // Find online racks to target
        let onlineRacks = state.placedEquipment.filter {
            $0.value.type.category == .rack && $0.value.status != .offline
        }
        guard !onlineRacks.isEmpty else { return }

        // Already has incident or telegraph on this position?
        let incidentPositions = Set(state.activeIncidents.map(\.affectedPosition))
        let telegraphPositions = Set(state.telegraphedIncidents.map(\.position))
        let occupiedPositions = incidentPositions.union(telegraphPositions)
        let targetable = onlineRacks.filter { !occupiedPositions.contains($0.key) }
        guard !targetable.isEmpty else { return }

        // Pick random type and target
        let type = eligible.randomElement()!
        let target = targetable.randomElement()!

        // Create telegraph instead of immediate incident
        let telegraph = TelegraphedIncident(
            type: type,
            position: target.key
        )
        state.telegraphedIncidents.append(telegraph)

        // Set cooldown
        cooldowns[type] = type.baseCooldown
    }

    // MARK: - Escalation

    private func escalatePowerOutage(from position: GridPosition, state: GameState) {
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
            state.totalIncidentsResolved += 1

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
