import SwiftUI

struct LevelCompleteView: View {
    let gameState: GameState
    let stars: Int
    let levelName: String
    let elapsedTime: TimeInterval

    @State private var showStars: [Bool] = [false, false, false]
    @State private var showStats = false
    @State private var showButtons = false
    @State private var particleEmojis: [ParticleEmoji] = []

    private let isLastLevel: Bool

    init(gameState: GameState, stars: Int, levelName: String, elapsedTime: TimeInterval) {
        self.gameState = gameState
        self.stars = stars
        self.levelName = levelName
        self.elapsedTime = elapsedTime
        self.isLastLevel = gameState.currentLevel >= 3
    }

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Celebration particles
            ForEach(particleEmojis) { particle in
                Text(particle.emoji)
                    .font(.system(size: particle.size))
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            // Content card
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 6) {
                    Text("LEVEL COMPLETE")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0, green: 0.9, blue: 1), Color(red: 0, green: 0.6, blue: 1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.5), radius: 10)

                    Text(levelName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                }

                // Stars
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                index < stars
                                    ? Color(red: 1, green: 0.8, blue: 0)
                                    : Color.white.opacity(0.15)
                            )
                            .shadow(color: index < stars ? Color(red: 1, green: 0.8, blue: 0).opacity(0.6) : .clear, radius: 8)
                            .scaleEffect(showStars[index] ? 1.0 : 0.0)
                            .rotationEffect(.degrees(showStars[index] ? 0 : -180))
                    }
                }
                .padding(.vertical, 8)

                // Stats
                if showStats {
                    VStack(spacing: 12) {
                        statRow(icon: "clock.fill", label: "Time", value: formatTime(elapsedTime), color: Color(red: 0, green: 0.9, blue: 1))
                        statRow(icon: "dollarsign.circle.fill", label: "Revenue", value: "$\(Int(gameState.revenuePerSecond))/s", color: Color(red: 0, green: 0.9, blue: 0.4))
                        statRow(icon: "checkmark.shield.fill", label: "Uptime", value: String(format: "%.1f%%", gameState.uptimePercent), color: uptimeColor)
                        statRow(icon: "wrench.fill", label: "Incidents Fixed", value: "\(gameState.resolvedIncidentCount)", color: Color(red: 1, green: 0.7, blue: 0))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Buttons
                if showButtons {
                    VStack(spacing: 10) {
                        // Next Level / You Win
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if isLastLevel {
                                gameState.phase = .mainMenu
                            } else {
                                let nextLevel = LevelDefinition.forLevel(gameState.currentLevel + 1)
                                gameState.resetForLevel(nextLevel)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isLastLevel ? "trophy.fill" : "arrow.right.circle.fill")
                                Text(isLastLevel ? "YOU WIN!" : "NEXT LEVEL")
                            }
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0, green: 0.9, blue: 1), Color(red: 0, green: 0.6, blue: 1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.4), radius: 8)
                            )
                        }

                        HStack(spacing: 10) {
                            // Replay
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                let level = LevelDefinition.forLevel(gameState.currentLevel)
                                gameState.resetForLevel(level)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("REPLAY")
                                }
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0, green: 0.9, blue: 1).opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(Color(red: 0, green: 0.9, blue: 1).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }

                            // Main Menu
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                gameState.phase = .mainMenu
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "house.fill")
                                    Text("MENU")
                                }
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.1, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color(red: 0, green: 0.9, blue: 1).opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 30)
            )
        }
        .onAppear { animateIn() }
    }

    // MARK: - Stat Row

    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var uptimeColor: Color {
        if gameState.uptimePercent >= 99 { return Color(red: 0, green: 0.9, blue: 0.4) }
        if gameState.uptimePercent >= 95 { return Color(red: 1, green: 0.7, blue: 0) }
        return Color(red: 1, green: 0.09, blue: 0.27)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Animations

    private func animateIn() {
        // Stars animate in one by one
        for i in 0..<min(stars, 3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3 + Double(i) * 0.3)) {
                showStars[i] = true
            }
        }
        // Show remaining unearned stars (no animation)
        for i in stars..<3 {
            withAnimation(.easeOut(duration: 0.2).delay(0.3 + Double(stars) * 0.3)) {
                showStars[i] = true
            }
        }

        // Stats appear
        withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
            showStats = true
        }

        // Buttons appear
        withAnimation(.easeOut(duration: 0.4).delay(1.6)) {
            showButtons = true
        }

        // Celebration particles
        spawnParticles()
    }

    private func spawnParticles() {
        let emojis = ["*", "+", ".", "o"]
        for i in 0..<20 {
            let particle = ParticleEmoji(
                emoji: emojis[i % emojis.count],
                position: CGPoint(
                    x: CGFloat.random(in: 40...340),
                    y: CGFloat.random(in: 50...700)
                ),
                size: CGFloat.random(in: 12...24),
                opacity: Double.random(in: 0.3...0.8)
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.2...1.5)) {
                withAnimation(.easeOut(duration: 2.0)) {
                    particleEmojis.append(particle)
                }
            }
        }

        // Fade out particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                particleEmojis.removeAll()
            }
        }
    }
}

// MARK: - Particle Model

private struct ParticleEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
}
