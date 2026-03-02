import SwiftUI

struct AIGuideView: View {
    let message: String
    let gameState: GameState

    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var currentMessageID = UUID()

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Chip avatar
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 42, height: 42)
                    .shadow(color: Theme.accent.opacity(0.3), radius: 4)

                Text("\u{1F527}")
                    .font(.system(size: 20))
            }

            // Speech bubble with tail
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Chip")
                        .font(Theme.headlineFont(size: 11))
                        .foregroundStyle(Theme.accent)

                    Spacer()

                    // Chat button
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.showingGuideChat.toggle()
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                            .padding(6)
                            .background(
                                Capsule().fill(Theme.accent.opacity(0.12))
                            )
                    }

                    // Dismiss
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.guideVisible = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text(displayedText)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)

                if isAnimating {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Theme.accent.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .offset(y: isAnimating ? -2 : 2)
                                .animation(
                                    .easeInOut(duration: 0.4)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.15),
                                    value: isAnimating
                                )
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.background.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.woodTone.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Theme.woodTone.opacity(0.15), radius: 6)
            )
        }
        .padding(.horizontal, 16)
        .onAppear { startTypewriter() }
        .onChange(of: message) { _, _ in startTypewriter() }
    }

    private func startTypewriter() {
        let id = UUID()
        currentMessageID = id
        displayedText = ""
        isAnimating = true

        let chars = Array(message)
        for (index, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025) {
                guard currentMessageID == id else { return }
                displayedText.append(char)
                if index == chars.count - 1 {
                    isAnimating = false
                }
            }
        }
    }
}
