import SwiftUI

struct IncidentAlertView: View {
    let gameState: GameState

    var body: some View {
        // TimelineView ensures continuous re-render so timer bars drain smoothly
        TimelineView(.animation) { _ in
            VStack(spacing: 8) {
                ForEach(gameState.activeIncidents.filter { !$0.resolved && !$0.failed }) { incident in
                    WarmIncidentCard(incident: incident)
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
    }
}

// MARK: - Warm Incident Card

private struct WarmIncidentCard: View {
    let incident: ActiveIncident

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
                ZStack {
                    Circle()
                        .fill(incidentAccentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Text(incidentEmoji)
                        .font(.system(size: 18))
                }

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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                        )

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [incidentAccentColor.opacity(0.7), incidentAccentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (1.0 - incident.progress))
                }
            }
            .frame(height: 6)

            // Drag hint
            HStack(spacing: 4) {
                Text("Drag \(toolEmoji) to fix!")
                    .font(Theme.headlineFont(size: 11))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(incidentAccentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(incidentAccentColor.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .padding(12)
        .frame(width: 195)
        .woodPanel(cornerRadius: 14, borderWidth: 2, shadowRadius: 6)
        .overlay(
            // Pulsing accent border on top of wood frame
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    incidentAccentColor.opacity(isPulsing ? 0.4 : 0.1),
                    lineWidth: 1.5
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
