import SwiftUI

struct ExpansionConfirmView: View {
    let gameState: GameState
    let zone: ExpansionZone
    let onConfirm: () -> Void

    private var canAfford: Bool { gameState.money >= zone.cost }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Expand Your Data Center?")
                .font(Theme.headlineFont(size: 22))
                .foregroundStyle(Theme.textPrimary)

            // Zone info
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                    Text("Zone \(zone.id)")
                        .font(Theme.bodyFont(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("$\(Int(zone.cost))")
                        .font(Theme.headlineFont(size: 20))
                        .foregroundStyle(canAfford ? Theme.positive : Theme.critical)
                }

                // Equipment unlocks
                if !zone.unlocksEquipment.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.accentGold)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlocks:")
                                .font(Theme.bodyFont(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                            ForEach(zone.unlocksEquipment, id: \.self) { eq in
                                Text(eq.displayName)
                                    .font(Theme.bodyFont(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        Spacer()
                    }
                }

                // Balance after purchase
                HStack {
                    Text("Balance after:")
                        .font(Theme.bodyFont(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("$\(Int(gameState.money - zone.cost))")
                        .font(Theme.headlineFont(size: 14))
                        .foregroundStyle(canAfford ? Theme.textPrimary : Theme.critical)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.cardBackground.opacity(0.6))
            )

            // Buttons
            HStack(spacing: 12) {
                Button {
                    gameState.cancelExpansion()
                } label: {
                    Text("Cancel")
                        .font(Theme.headlineFont(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.textSecondary.opacity(0.3), lineWidth: 1.5)
                        )
                }

                Button {
                    guard canAfford else { return }
                    onConfirm()
                } label: {
                    Text("Expand!")
                        .font(Theme.headlineFont(size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canAfford ? Theme.accent : Theme.textSecondary.opacity(0.3))
                                .shadow(color: canAfford ? Theme.accent.opacity(0.4) : .clear, radius: 6)
                        )
                }
                .disabled(!canAfford)
            }

            if !canAfford {
                Text("Not enough money — need $\(Int(zone.cost - gameState.money)) more")
                    .font(Theme.bodyFont(size: 12))
                    .foregroundStyle(Theme.critical)
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.background)
                .shadow(color: Theme.woodTone.opacity(0.3), radius: 20)
        )
    }
}
