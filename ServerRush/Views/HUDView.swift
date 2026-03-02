import SwiftUI

struct HUDView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 4) {
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
            HStack(spacing: 12) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.background.opacity(0.92))
                .shadow(color: Theme.woodTone.opacity(0.15), radius: 4, y: 2)
        )
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
            Text("\u{1FA99}")
                .font(.system(size: 18))

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
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((gameState.uptimePercent >= 99 ? Theme.positive : Theme.warning).opacity(0.1))
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.cardBackground)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * min(objective.progress, 1.0))
                }
            }
            .frame(width: 40, height: 5)

            Text("\(Int(objective.progress * 100))%")
                .font(Theme.headlineFont(size: 10))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Theme.accent.opacity(0.08))
        )
    }

    // MARK: - Resource Indicator

    private func resourceIndicator(icon: String, label: String, percent: Double, fillColor: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fillColor)
                .frame(width: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.cardBackground)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillColor)
                        .frame(width: geo.size.width * min(percent / 100, 1.0))
                }
            }
            .frame(height: 5)

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
