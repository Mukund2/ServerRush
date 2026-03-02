import SwiftUI

struct MainMenuView: View {
    let gameState: GameState

    @State private var showContent = false
    @State private var buttonBounce = false
    @State private var pulseServer = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            titleSection

            // Server illustration
            serverIllustration
                .padding(.top, 16)

            // Stats (if save exists)
            if gameState.hasSaveData {
                statsSection
                    .padding(.top, 16)
            }

            Spacer()

            // Action buttons
            actionButtons
                .padding(.bottom, 16)

            Text("v1.0  -  Mistral AI Hackathon 2026")
                .font(Theme.bodyFont(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Theme.background.ignoresSafeArea()
                dotPattern
            }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseServer = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.5)) {
                buttonBounce = true
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("SERVER RUSH")
                .font(Theme.headlineFont(size: 40))
                .foregroundStyle(Theme.textPrimary)

            Text("DATA CENTER TYCOON")
                .font(Theme.bodyFont(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .tracking(4)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }

    // MARK: - Server Illustration

    private var serverIllustration: some View {
        VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { row in
                warmServerRow(row: row)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.cardBackground)
                .shadow(color: Theme.woodTone.opacity(0.2), radius: 8)
        )
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.9)
    }

    private func warmServerRow(row: Int) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.cardBackground.opacity(0.8))
                .frame(width: 200, height: 24)
                .overlay(
                    HStack(spacing: 5) {
                        // Warm status lights
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(warmLightColor(row: row, index: i))
                                .frame(width: 5, height: 5)
                                .opacity(pulseServer ? 1.0 : 0.6)
                        }
                        Spacer()
                        // Vent lines
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(Theme.woodTone.opacity(0.15))
                                .frame(width: 1, height: 14)
                        }
                    }
                    .padding(.horizontal, 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.woodTone.opacity(0.2), lineWidth: 0.5)
                )
        }
    }

    private func warmLightColor(row: Int, index: Int) -> Color {
        let pattern: [[Color]] = [
            [Theme.positive, Theme.accentGold, Theme.positive, Theme.accent],
            [Theme.accent, Theme.positive, Theme.accentGold, Theme.positive],
            [Theme.positive, Theme.accent, Theme.positive, Theme.accentGold],
            [Theme.accentGold, Theme.positive, Theme.accent, Theme.textSecondary.opacity(0.3)],
        ]
        return pattern[row % pattern.count][index % pattern[0].count]
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Main START button
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                gameState.startNewGame()
            } label: {
                Text("START")
                    .font(Theme.headlineFont(size: 22))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 10)
                    )
            }
            .scaleEffect(buttonBounce ? 1 : 0.8)
            .padding(.horizontal, 40)

            // Continue button (if save exists)
            if gameState.hasSaveData {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    gameState.loadGame()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Continue")
                            .font(Theme.headlineFont(size: 16))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Theme.textPrimary.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .padding(.horizontal, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 24) {
            statBadge(
                value: "$\(Int(gameState.totalMoneyEarned))",
                label: "Earned",
                color: Theme.accentGold
            )
            statBadge(
                value: "\(gameState.totalIncidentsResolved)",
                label: "Fixed",
                color: Theme.accent
            )
            statBadge(
                value: formatPlayTime(gameState.playTime),
                label: "Played",
                color: Theme.textSecondary
            )
        }
        .opacity(showContent ? 1 : 0)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.headlineFont(size: 16))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.bodyFont(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func formatPlayTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    // MARK: - Dot Pattern Background

    private var dotPattern: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let dotRadius: CGFloat = 1.5
            for x in stride(from: spacing, to: size.width, by: spacing) {
                for y in stride(from: spacing, to: size.height, by: spacing) {
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.woodTone.opacity(0.08)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
