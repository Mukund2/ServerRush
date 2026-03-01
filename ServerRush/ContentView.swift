import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var gameScene: GameScene?

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.1, blue: 0.15)
                .ignoresSafeArea()

            switch gameState.phase {
            case .mainMenu:
                MainMenuView(gameState: gameState)
                    .transition(.opacity)

            case .playing, .paused:
                gameView
                    .transition(.opacity)

            case .levelComplete(let stars):
                LevelCompleteView(
                    gameState: gameState,
                    stars: stars,
                    levelName: LevelDefinition.forLevel(gameState.currentLevel).name,
                    elapsedTime: gameState.levelElapsedTime
                )
                .transition(.scale.combined(with: .opacity))

            case .gameOver:
                gameOverView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState.phase)
    }

    private var gameView: some View {
        ZStack {
            // SpriteKit game world
            SpriteView(scene: makeScene(), preferredFramesPerSecond: 60)
                .ignoresSafeArea()

            // SwiftUI HUD overlay
            VStack(spacing: 0) {
                HUDView(gameState: gameState)
                Spacer()

                // Incident alerts
                if !gameState.activeIncidents.isEmpty {
                    IncidentAlertView(gameState: gameState)
                        .transition(.move(edge: .trailing))
                }

                Spacer()

                // AI Guide chat bubble
                if gameState.guideVisible, let message = gameState.guideMessage {
                    AIGuideView(message: message, gameState: gameState)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                // Build menu
                BuildMenuView(gameState: gameState)
            }
        }
    }

    private var gameOverView: some View {
        VStack(spacing: 24) {
            Text("SYSTEM FAILURE")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(.red)

            Text("Your data center couldn't maintain operations")
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.gray)

            Button {
                let level = LevelDefinition.forLevel(gameState.currentLevel)
                gameState.resetForLevel(level)
            } label: {
                Text("REBOOT")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red.opacity(0.8))
                    )
            }

            Button {
                gameState.phase = .mainMenu
            } label: {
                Text("Main Menu")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    private func makeScene() -> GameScene {
        if let existing = gameScene {
            return existing
        }
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.gameState = gameState
        scene.scaleMode = .resizeFill
        gameScene = scene
        return scene
    }
}
