import SwiftUI

struct MainMenuView: View {
    let gameState: GameState

    @State private var showContent = false
    @State private var buttonBounce = false
    @State private var pulseServer = false
    @State private var cloudOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background: sky gradient + grass
            cozyBackground

            VStack(spacing: 0) {
                Spacer()

                // Wooden sign title
                woodenTitleSign
                    .padding(.bottom, 8)

                // Cozy server illustration
                serverIllustration
                    .padding(.top, 8)

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
        }
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
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                cloudOffset = 300
            }
        }
    }

    // MARK: - Cozy Background (Sky + Grass)

    private var cozyBackground: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [Theme.skyBlue, Theme.skyBlue.opacity(0.6), Theme.background],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            // Warm cream lower half
            VStack {
                Spacer()
                Theme.background
                    .frame(height: UIScreen.main.bounds.height * 0.45)
            }
            .ignoresSafeArea()

            // Grass strip at the transition
            VStack {
                Spacer()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                grassStrip
                Spacer()
            }

            // Drifting clouds
            floatingClouds

            // Dot pattern overlay (subtle, only in lower half)
            VStack {
                Spacer()
                dotPattern
                    .frame(height: UIScreen.main.bounds.height * 0.4)
                    .opacity(0.5)
            }
            .ignoresSafeArea()
        }
    }

    private var grassStrip: some View {
        Canvas { context, size in
            // Rolling grass hills
            let grassPath = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height * 0.4))

                // Gentle rolling hills
                let segments = 8
                let segWidth = size.width / CGFloat(segments)
                for i in 0..<segments {
                    let x1 = segWidth * CGFloat(i) + segWidth * 0.5
                    let x2 = segWidth * CGFloat(i + 1)
                    let y1 = size.height * CGFloat.random(in: 0.2...0.5)
                    let y2 = size.height * CGFloat.random(in: 0.3...0.55)
                    p.addQuadCurve(to: CGPoint(x: x2, y: y2),
                                   control: CGPoint(x: x1, y: y1))
                }
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.closeSubpath()
            }

            // Dark grass layer
            context.fill(grassPath, with: .color(Theme.grassDark))

            // Lighter grass overlay (slightly offset up)
            var lightPath = grassPath
            let transform = CGAffineTransform(translationX: 0, y: -3)
            lightPath = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height * 0.45))
                let segments = 6
                let segWidth = size.width / CGFloat(segments)
                for i in 0..<segments {
                    let x1 = segWidth * CGFloat(i) + segWidth * 0.5
                    let x2 = segWidth * CGFloat(i + 1)
                    let y1 = size.height * 0.3
                    let y2 = size.height * 0.4
                    p.addQuadCurve(to: CGPoint(x: x2, y: y2),
                                   control: CGPoint(x: x1, y: y1))
                }
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.closeSubpath()
            }
            context.fill(lightPath, with: .color(Theme.grassGreen))
        }
        .frame(height: 50)
    }

    private var floatingClouds: some View {
        ZStack {
            // Cloud 1
            cloudShape
                .fill(.white.opacity(0.5))
                .frame(width: 90, height: 30)
                .offset(x: -80 + cloudOffset * 0.3, y: -280)

            // Cloud 2
            cloudShape
                .fill(.white.opacity(0.4))
                .frame(width: 120, height: 35)
                .offset(x: 60 + cloudOffset * 0.2, y: -320)

            // Cloud 3
            cloudShape
                .fill(.white.opacity(0.35))
                .frame(width: 70, height: 22)
                .offset(x: -40 + cloudOffset * 0.15, y: -250)
        }
    }

    private var cloudShape: some Shape {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    // MARK: - Wooden Title Sign

    private var woodenTitleSign: some View {
        VStack(spacing: 4) {
            Text("SERVER RUSH")
                .font(Theme.headlineFont(size: 38))
                .foregroundStyle(Theme.textPrimary)

            Text("DATA CENTER TYCOON")
                .font(Theme.bodyFont(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .tracking(3)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .woodPanel(cornerRadius: Theme.Radius.xl, borderWidth: 4, shadowRadius: 12)
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
        .woodPanel(cornerRadius: Theme.Radius.lg, borderWidth: 3, shadowRadius: 8)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.9)
    }

    private func warmServerRow(row: Int) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.cardBackground.opacity(0.8))
                .frame(width: 200, height: 26)
                .overlay(
                    HStack(spacing: 5) {
                        // Warm status lights
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(warmLightColor(row: row, index: i))
                                .frame(width: 6, height: 6)
                                .opacity(pulseServer ? 1.0 : 0.6)
                                .shadow(color: warmLightColor(row: row, index: i).opacity(0.5), radius: 2)
                        }
                        Spacer()
                        // Vent lines
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Theme.woodTone.opacity(0.18))
                                .frame(width: 1.5, height: 14)
                        }
                    }
                    .padding(.horizontal, 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.woodTone.opacity(0.25), lineWidth: 1)
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
            // Main START button — cozy 3D style
            Button {
                AudioManager.shared.playUITap()
                gameState.startNewGame()
            } label: {
                Text("START")
                    .font(Theme.headlineFont(size: 22))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(CozyButtonStyle(color: Theme.accent, cornerRadius: 20))
            .scaleEffect(buttonBounce ? 1 : 0.8)
            .padding(.horizontal, 40)

            // Continue button (if save exists)
            if gameState.hasSaveData {
                Button {
                    AudioManager.shared.playUITap()
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
                }
                .buttonStyle(CozyButtonStyle(color: Theme.cardBackground, cornerRadius: 16))
                .padding(.horizontal, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 20) {
            statBadge(
                emoji: "\u{1FA99}",
                value: "$\(Int(gameState.totalMoneyEarned))",
                label: "Earned",
                color: Theme.accentGold
            )
            statBadge(
                emoji: "\u{1F527}",
                value: "\(gameState.totalIncidentsResolved)",
                label: "Fixed",
                color: Theme.accent
            )
            statBadge(
                emoji: "\u{231B}",
                value: formatPlayTime(gameState.playTime),
                label: "Played",
                color: Theme.textSecondary
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .woodPanel(cornerRadius: Theme.Radius.md, borderWidth: 2, shadowRadius: 4)
        .opacity(showContent ? 1 : 0)
    }

    private func statBadge(emoji: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(emoji)
                .font(.system(size: 16))
            Text(value)
                .font(Theme.headlineFont(size: 15))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.bodyFont(size: 10))
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
