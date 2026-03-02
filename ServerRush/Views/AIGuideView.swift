import SwiftUI

struct AIGuideView: View {
    let message: String
    let gameState: GameState

    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var currentMessageID = UUID()

    var body: some View {
        HStack(spacing: 8) {
            // Chip avatar (smaller, in cozy circle)
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.woodLight, lineWidth: 2)
                    )
                    .shadow(color: Theme.accent.opacity(0.3), radius: 3)

                Text("\u{1F9D1}\u{200D}\u{1F527}")
                    .font(.system(size: 15))
            }

            // Compact speech bubble with wood frame
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chip")
                        .font(Theme.headlineFont(size: 10))
                        .foregroundStyle(Theme.accent)

                    Text(displayedText)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                // Dismiss
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    gameState.guideVisible = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Theme.cardBackground)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Theme.woodTone.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .woodPanel(cornerRadius: Theme.Radius.md, borderWidth: 2, shadowRadius: 4)
        }
        .frame(maxWidth: 400)
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
