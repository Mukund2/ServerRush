import SwiftUI

struct MainMenuView: View {
    let gameState: GameState

    @State private var titleGlow = false
    @State private var showContent = false
    @State private var pulseServer = false

    // Track best stars per level (in a real app, persist with UserDefaults/AppStorage)
    @State private var bestStars: [Int: Int] = [1: 0, 2: 0, 3: 0]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title section
            titleSection
                .padding(.bottom, 32)

            // Server art
            serverArt
                .padding(.bottom, 40)

            // Level select
            levelSelect
                .padding(.bottom, 24)

            // Quick start
            startButton
                .padding(.bottom, 16)

            Spacer()

            // Version
            Text("v1.0  //  Swift Student Challenge 2026")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.15)
                    .ignoresSafeArea()

                // Subtle grid pattern
                gridBackground
            }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                titleGlow = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseServer = true
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("SERVER RUSH")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0, green: 0.9, blue: 1),
                            Color(red: 0, green: 0.7, blue: 1),
                            Color(red: 0, green: 0.9, blue: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(titleGlow ? 0.8 : 0.3), radius: titleGlow ? 20 : 10)

            Text("DATA CENTER TYCOON")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(6)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }

    // MARK: - Server Art

    private var serverArt: some View {
        VStack(spacing: 2) {
            serverRow(lights: [.green, .cyan, .green, .cyan])
            serverRow(lights: [.cyan, .green, .cyan, .green])
            serverRow(lights: [.green, .cyan, .green, .cyan])
            serverRow(lights: [.cyan, .green, .cyan, .off])
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(red: 0, green: 0.9, blue: 1).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(pulseServer ? 0.15 : 0.05), radius: 20)
        )
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.9)
    }

    private func serverRow(lights: [ServerLight]) -> some View {
        HStack(spacing: 6) {
            // Server face
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.22))
                .frame(width: 200, height: 22)
                .overlay(
                    HStack(spacing: 4) {
                        // Lights
                        ForEach(Array(lights.enumerated()), id: \.offset) { _, light in
                            Circle()
                                .fill(light.color)
                                .frame(width: 5, height: 5)
                                .shadow(color: light.color.opacity(0.8), radius: 3)
                                .opacity(light == .off ? 0.2 : (pulseServer ? 1.0 : 0.6))
                        }

                        Spacer()

                        // Vent lines
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1, height: 12)
                        }
                    }
                    .padding(.horizontal, 8)
                )
        }
    }

    // MARK: - Level Select

    private var levelSelect: some View {
        VStack(spacing: 8) {
            Text("SELECT LEVEL")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(3)

            VStack(spacing: 8) {
                ForEach(LevelDefinition.allLevels, id: \.id) { level in
                    let isLocked = level.id > 1 && (bestStars[level.id - 1] ?? 0) == 0 && level.id > 1
                    levelButton(level: level, locked: isLocked)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    private func levelButton(level: LevelDefinition, locked: Bool) -> some View {
        Button {
            guard !locked else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            gameState.resetForLevel(level)
        } label: {
            HStack(spacing: 12) {
                // Level number
                Text("\(level.id)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(locked ? .gray.opacity(0.3) : Color(red: 0, green: 0.9, blue: 1))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(locked ? .gray.opacity(0.4) : .white)

                    Text(level.subtitle)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.6))
                }

                Spacer()

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray.opacity(0.3))
                } else {
                    // Star rating
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < (bestStars[level.id] ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    i < (bestStars[level.id] ?? 0)
                                        ? Color(red: 1, green: 0.8, blue: 0)
                                        : .white.opacity(0.15)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(locked ? Color.white.opacity(0.02) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                locked
                                    ? Color.white.opacity(0.03)
                                    : Color(red: 0, green: 0.9, blue: 1).opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .disabled(locked)
        .padding(.horizontal, 24)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            gameState.resetForLevel(LevelDefinition.level1)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                Text("QUICK START")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0, green: 0.9, blue: 1), Color(red: 0, green: 0.6, blue: 1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.4), radius: 12)
            )
        }
        .padding(.horizontal, 40)
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Server Light

private enum ServerLight: Equatable {
    case green, cyan, off

    var color: Color {
        switch self {
        case .green: return Color(red: 0, green: 0.9, blue: 0.4)
        case .cyan: return Color(red: 0, green: 0.9, blue: 1)
        case .off: return .gray
        }
    }
}
