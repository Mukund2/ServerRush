import SwiftUI

struct MilestoneView: View {
    let gameState: GameState
    let milestoneType: MilestoneType

    @State private var showTitle = false
    @State private var showStats = false
    @State private var showButton = false
    @State private var confettiParticles: [ConfettiParticle] = []

    private var titleText: String {
        switch milestoneType {
        case .equipmentPlaced: return "Nice Setup!"
        case .firstExpansion: return "Growing Fast!"
        case .expansionUnlocked: return "Well Done!"
        case .revenueTarget: return "Incredible!"
        case .incidentsMastered: return "Master Fixer!"
        }
    }

    private var subtitleText: String {
        switch milestoneType {
        case .equipmentPlaced(let count):
            return "You built \(count) pieces of equipment!"
        case .firstExpansion:
            return "Your data center is expanding!"
        case .expansionUnlocked(let zone):
            return "Expansion zone \(zone) unlocked!"
        case .revenueTarget(let amount):
            return "You earned $\(Int(amount)) total!"
        case .incidentsMastered(let count):
            return "You resolved \(count) incidents!"
        }
    }

    private var milestoneEmoji: String {
        switch milestoneType {
        case .equipmentPlaced: return "\u{1F3D7}"   // building construction
        case .firstExpansion: return "\u{1F30D}"     // globe
        case .expansionUnlocked: return "\u{1F513}"  // unlocked
        case .revenueTarget: return "\u{1F4B0}"      // money bag
        case .incidentsMastered: return "\u{1F6E0}"  // hammer and wrench
        }
    }

    var body: some View {
        ZStack {
            // Golden tint overlay
            Theme.accentGold.opacity(0.15)
                .ignoresSafeArea()

            // Confetti particles
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            // Content card
            VStack(spacing: 20) {
                // Emoji
                Text(milestoneEmoji)
                    .font(.system(size: 56))
                    .scaleEffect(showTitle ? 1 : 0)

                // Title
                Text(titleText)
                    .font(Theme.headlineFont(size: 32))
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                // Subtitle
                Text(subtitleText)
                    .font(Theme.bodyFont(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showTitle ? 1 : 0)

                // Stats relevant to milestone
                if showStats {
                    milestoneStats
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Keep Going button
                if showButton {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        gameState.phase = .playing
                    } label: {
                        Text("Keep Going!")
                            .font(Theme.headlineFont(size: 18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(CozyButtonStyle(color: Theme.accent, cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(32)
            .frame(maxWidth: 380)
            .woodPanel(cornerRadius: Theme.Radius.xl, borderWidth: 4, shadowRadius: 16)
        }
        .onAppear { animateIn() }
    }

    // MARK: - Milestone Stats

    @ViewBuilder
    private var milestoneStats: some View {
        VStack(spacing: 10) {
            switch milestoneType {
            case .revenueTarget:
                statRow(icon: "dollarsign.circle.fill", label: "Revenue", value: "$\(Int(gameState.revenuePerSecond))/s", color: Theme.accentGold)
                statRow(icon: "dollarsign.circle", label: "Total Earned", value: "$\(Int(gameState.totalMoneyEarned))", color: Theme.positive)

            case .incidentsMastered:
                statRow(icon: "wrench.fill", label: "Incidents Fixed", value: "\(gameState.totalIncidentsResolved)", color: Theme.accent)
                statRow(icon: "checkmark.shield.fill", label: "Uptime", value: String(format: "%.1f%%", gameState.uptimePercent), color: Theme.positive)

            case .expansionUnlocked, .firstExpansion:
                statRow(icon: "square.grid.3x3", label: "Expansions", value: "\(gameState.unlockedExpansions.count)", color: Theme.accent)
                statRow(icon: "server.rack", label: "Equipment", value: "\(gameState.placedEquipment.count)", color: Theme.textSecondary)

            case .equipmentPlaced:
                statRow(icon: "server.rack", label: "Equipment", value: "\(gameState.totalEquipmentPlaced)", color: Theme.accent)
                statRow(icon: "dollarsign.circle.fill", label: "Balance", value: "$\(Int(gameState.money))", color: Theme.accentGold)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.cardBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(Theme.bodyFont(size: 13))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.headlineFont(size: 14))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Animations

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            showTitle = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            showStats = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
            showButton = true
        }

        spawnConfetti()
    }

    private func spawnConfetti() {
        let warmColors: [Color] = [
            Theme.accentGold,
            Theme.accent,
            Theme.positive,
            Theme.critical,
            Theme.woodTone
        ]

        for i in 0..<30 {
            let particle = ConfettiParticle(
                color: warmColors[i % warmColors.count],
                position: CGPoint(
                    x: CGFloat.random(in: 30...350),
                    y: CGFloat.random(in: 40...700)
                ),
                size: CGFloat.random(in: 4...10),
                opacity: Double.random(in: 0.4...0.9)
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...1.0)) {
                withAnimation(.easeOut(duration: 1.5)) {
                    confettiParticles.append(particle)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                confettiParticles.removeAll()
            }
        }
    }
}

// MARK: - Confetti Particle

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
}
