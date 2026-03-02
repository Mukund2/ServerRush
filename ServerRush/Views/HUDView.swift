import SwiftUI

struct HUDView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 6) {
            // Top row: Money + Objective
            HStack(spacing: 8) {
                moneySection

                Spacer()

                // Objective
                if let objective = gameState.currentObjective {
                    compactObjective(objective)
                }

                // Uptime badge
                uptimeBadge
            }

            // Bottom row: Resource bars
            HStack(spacing: 10) {
                resourceIndicator(
                    icon: "bolt.fill",
                    label: "Power",
                    percent: gameState.powerPercent,
                    fillColor: Theme.accentGold
                )
                resourceIndicator(
                    icon: "snowflake",
                    label: "Cool",
                    percent: gameState.coolingPercent,
                    fillColor: Color(red: 0.55, green: 0.72, blue: 0.88)
                )
                resourceIndicator(
                    icon: "network",
                    label: "Net",
                    percent: gameState.bandwidthPercent,
                    fillColor: Color(red: 0.68, green: 0.58, blue: 0.82)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .woodPanel(cornerRadius: Theme.Radius.lg, borderWidth: 3, shadowRadius: 6)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .animation(.spring(response: 0.3), value: gameState.money)
        .animation(.spring(response: 0.3), value: gameState.powerPercent)
        .animation(.spring(response: 0.3), value: gameState.coolingPercent)
        .animation(.spring(response: 0.3), value: gameState.bandwidthPercent)
    }

    // MARK: - Money Section

    private var moneySection: some View {
        HStack(spacing: 6) {
            // Coin bag icon
            ZStack {
                Circle()
                    .fill(Theme.accentGold.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text("\u{1FA99}")
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("$\(Int(gameState.money))")
                    .font(Theme.moneyFont(size: 18))
                    .foregroundStyle(Theme.accentGold)
                    .contentTransition(.numericText())

                Text("+$\(Int(gameState.revenuePerSecond))/s")
                    .font(Theme.bodyFont(size: 10))
                    .foregroundStyle(Theme.positive)
            }
        }
    }

    // MARK: - Uptime Badge

    private var uptimeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 10))
            Text("\(String(format: "%.1f", gameState.uptimePercent))%")
                .font(Theme.headlineFont(size: 11))
        }
        .foregroundStyle(gameState.uptimePercent >= 99 ? Theme.positive : Theme.warning)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((gameState.uptimePercent >= 99 ? Theme.positive : Theme.warning).opacity(0.12))
                .overlay(
                    Capsule()
                        .strokeBorder((gameState.uptimePercent >= 99 ? Theme.positive : Theme.warning).opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Compact Objective

    private func compactObjective(_ objective: Objective) -> some View {
        HStack(spacing: 4) {
            Text(objective.description)
                .font(Theme.bodyFont(size: 10))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.woodTone.opacity(0.2), lineWidth: 0.5)
                        )
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * min(objective.progress, 1.0))
                }
            }
            .frame(width: 40, height: 6)

            Text("\(Int(objective.progress * 100))%")
                .font(Theme.headlineFont(size: 10))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Theme.accent.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.accent.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Resource Indicator

    private func resourceIndicator(icon: String, label: String, percent: Double, fillColor: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fillColor)
                .frame(width: 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track with border
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                        )

                    // Fill bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [fillColor.opacity(0.8), fillColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(percent / 100, 1.0))
                }
            }
            .frame(height: 7)

            Text(resourceStatusEmoji(percent))
                .font(.system(size: 9))
        }
        .frame(maxWidth: .infinity)
    }

    private func resourceStatusEmoji(_ percent: Double) -> String {
        if percent > 85 { return "\u{1F525}" }
        if percent > 60 { return "\u{26A0}\u{FE0F}" }
        return "\u{2713}"
    }
}
