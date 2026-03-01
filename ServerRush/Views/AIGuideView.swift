import SwiftUI

struct AIGuideView: View {
    let message: String
    let gameState: GameState

    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var currentMessageID = UUID()

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0, green: 0.9, blue: 1).opacity(0.3),
                                Color(red: 0, green: 0.5, blue: 0.8).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(red: 0, green: 0.9, blue: 1).opacity(0.4), lineWidth: 1)
                    )

                Text("\u{1F916}")
                    .font(.system(size: 20))
            }

            // Message bubble
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("AI GUIDE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))

                    Spacer()

                    // Chat button
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.showingGuideChat.toggle()
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                    }

                    // Dismiss
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.guideVisible = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                }

                Text(displayedText)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(2)

                if isAnimating {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color(red: 0, green: 0.9, blue: 1).opacity(0.6))
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.18).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 0, green: 0.9, blue: 1).opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.1), radius: 8)
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
