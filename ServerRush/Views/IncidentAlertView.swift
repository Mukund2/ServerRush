import SwiftUI

struct IncidentAlertView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(gameState.activeIncidents.filter { !$0.resolved && !$0.failed }) { incident in
                IncidentCard(incident: incident) {
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

            // Remove after a brief delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                gameState.activeIncidents.removeAll { $0.id == incident.id }
            }
        }
    }
}

// MARK: - Incident Card

private struct IncidentCard: View {
    let incident: ActiveIncident
    let onResolve: () -> Void

    @State private var isPulsing = false

    private var incidentColor: Color {
        switch incident.type {
        case .overheating: return Color(red: 1, green: 0.09, blue: 0.27)
        case .ddosAttack: return Color(red: 0.6, green: 0.2, blue: 1)
        case .powerOutage: return Color(red: 1, green: 0.7, blue: 0)
        case .cableFailure: return Color(red: 1, green: 0.5, blue: 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Pulsing icon
                Image(systemName: incident.type.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(incidentColor)
                    .shadow(color: incidentColor.opacity(isPulsing ? 0.8 : 0.3), radius: isPulsing ? 8 : 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(incident.type.displayName)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("Rack (\(incident.affectedPosition.col),\(incident.affectedPosition.row))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                }

                Spacer(minLength: 4)
            }

            // Timer bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [incidentColor, incidentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (1.0 - incident.progress))
                        .shadow(color: incidentColor.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 5)

            // Resolve button
            Button(action: onResolve) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 11))
                    Text("RESOLVE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(incidentColor.opacity(0.8))
                        .shadow(color: incidentColor.opacity(0.4), radius: 4)
                )
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(incidentColor.opacity(isPulsing ? 0.6 : 0.25), lineWidth: 1.5)
                )
                .shadow(color: incidentColor.opacity(0.2), radius: 8)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
