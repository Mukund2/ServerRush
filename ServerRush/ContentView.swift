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
                .id("gameScene")  // Stable identity — don't recreate on state changes

            VStack(spacing: 0) {
                HUDView(gameState: gameState)

                // Guide message just below HUD
                if gameState.guideVisible, let message = gameState.guideMessage {
                    AIGuideView(message: message, gameState: gameState)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(true)
                        .padding(.top, 4)
                }

                // Incident alerts below guide (pass touches through to SpriteKit)
                if !gameState.activeIncidents.isEmpty {
                    IncidentAlertView(gameState: gameState)
                        .allowsHitTesting(false)
                        .transition(.move(edge: .trailing))
                        .padding(.top, 4)
                }

                Spacer()
                BuildMenuView(gameState: gameState)
            }

            // RackInfoView bottom sheet when a tile with equipment is selected
            if let selectedPos = gameState.selectedTile,
               let equipment = gameState.placedEquipment[selectedPos] {
                VStack {
                    Spacer()
                    RackInfoView(gameState: gameState, equipment: equipment)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gameState.selectedTile)
            }

            // Expansion confirmation overlay
            if let zone = gameState.pendingExpansion {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        gameState.cancelExpansion()
                    }

                ExpansionConfirmView(gameState: gameState, zone: zone) {
                    gameState.confirmExpansion()
                    gameScene?.rebuildFloorGrid()
                    AudioManager.shared.playExpansionUnlock()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gameState.pendingExpansion != nil)
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
                gameScene = nil
                gameState.startNewGame()
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
                gameScene = nil
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
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.gameState = gameState
        scene.scaleMode = .resizeFill
        gameScene = scene
        return scene
    }
}
