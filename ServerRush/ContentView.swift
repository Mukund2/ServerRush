import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var gameState = GameState()
    @State private var gameScene: GameScene?

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            switch gameState.phase {
            case .mainMenu:
                MainMenuView(gameState: gameState)
                    .transition(.opacity)

            case .playing, .paused:
                gameView
                    .transition(.opacity)

            case .milestone(let type):
                MilestoneView(gameState: gameState, milestoneType: type)
                    .transition(.scale.combined(with: .opacity))

            case .gameOver:
                gameOverView
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: gameState.phase)
    }

    private var gameView: some View {
        ZStack {
            SpriteView(scene: makeScene(), preferredFramesPerSecond: 60)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HUDView(gameState: gameState)
                Spacer()

                if !gameState.activeIncidents.isEmpty {
                    IncidentAlertView(gameState: gameState)
                        .transition(.move(edge: .trailing))
                }

                Spacer()

                if gameState.guideVisible, let message = gameState.guideMessage {
                    AIGuideView(message: message, gameState: gameState)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                BuildMenuView(gameState: gameState)
            }
        }
    }

    private var gameOverView: some View {
        VStack(spacing: 24) {
            Text("Oh no!")
                .font(Theme.headlineFont(size: 36))
                .foregroundStyle(Theme.critical)

            Text("Your data center couldn't keep up. Don't worry, every great builder has setbacks!")
                .font(Theme.bodyFont(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                gameState.phase = .playing
                gameState.money = 500
                gameState.activeIncidents.removeAll()
                gameState.failedIncidentCount = 0
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                    Text("Try Again")
                        .font(Theme.headlineFont(size: 18))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 8)
                )
            }

            Button {
                gameState.phase = .mainMenu
            } label: {
                Text("Main Menu")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundStyle(Theme.textSecondary)
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
