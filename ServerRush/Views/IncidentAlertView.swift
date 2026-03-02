import SwiftUI

struct IncidentAlertView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(gameState.activeIncidents.filter { !$0.resolved && !$0.failed }) { incident in
                WarmIncidentCard(incident: incident) {
                    resolveIncident(incident)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gameState.activeIncidents.map(\.id))
    }

    private func resolveIncident(_ incident: ActiveIncident) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if let idx = gameState.activeIncidents.firstIndex(where: { $0.id == incident.id }) {
            gameState.activeIncidents[idx].resolved = true
            gameState.resolvedIncidentCount += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                gameState.activeIncidents.removeAll { $0.id == incident.id }
            }
        }
    }
}

// MARK: - Warm Incident Card

private struct WarmIncidentCard: View {
    let incident: ActiveIncident
    let onResolve: () -> Void

    @State private var isPulsing = false

    private var incidentEmoji: String {
        switch incident.type {
        case .overheating: return "\u{1F975}"   // hot face
        case .ddosAttack: return "\u{1F6E1}"    // shield
        case .powerOutage: return "\u{26A1}"    // zap
        case .cableFailure: return "\u{1F50C}"  // plug
        }
    }

    private var incidentMessage: String {
        switch incident.type {
        case .overheating: return "Server is getting toasty! Cool it down!"
        case .ddosAttack: return "Under attack! Raise the shields!"
        case .powerOutage: return "Lights out! Time for a quick fix!"
        case .cableFailure: return "Whoops! Something came unplugged!"
        }
    }

    private var toolEmoji: String {
        switch incident.type.requiredTool {
        case .fireExtinguisher: return "\u{1F9EF}"  // fire extinguisher
        case .shield: return "\u{1F6E1}"            // shield
        case .wrench: return "\u{1F527}"            // wrench
        case .cablePlug: return "\u{1F50C}"         // plug
        }
    }

    private var incidentAccentColor: Color {
        switch incident.type {
        case .overheating: return Theme.critical
        case .ddosAttack: return Color(red: 0.68, green: 0.58, blue: 0.82)
        case .powerOutage: return Theme.accentGold
        case .cableFailure: return Theme.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with emoji face + description
            HStack(spacing: 8) {
                Text(incidentEmoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(incidentMessage)
                        .font(Theme.bodyFont(size: 11))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text("Rack at (\(incident.affectedPosition.col),\(incident.affectedPosition.row))")
                        .font(Theme.bodyFont(size: 9))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 4)
            }

            // Timer bar (warm orange draining left to right)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.cardBackground)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * (1.0 - incident.progress))
                }
            }
            .frame(height: 5)

            // Drag hint
            HStack(spacing: 4) {
                Text("Drag \(toolEmoji) to fix!")
                    .font(Theme.headlineFont(size: 11))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(incidentAccentColor.opacity(0.15))
            )
        }
        .padding(12)
        .frame(width: 190)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            incidentAccentColor.opacity(isPulsing ? 0.5 : 0.2),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: incidentAccentColor.opacity(0.15), radius: 6)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
