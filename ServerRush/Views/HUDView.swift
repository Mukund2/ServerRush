import SwiftUI

struct HUDView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 6) {
            // Objective banner at top
            if let objective = gameState.currentObjective {
                objectiveBanner(objective)
            }

            // Main HUD bar
            HStack(spacing: 14) {
                // Money section
                moneySection

                Spacer()

                // Resource indicators
                resourceIndicator(
                    icon: "bolt.fill",
                    percent: gameState.powerPercent,
                    fillColor: Theme.accentGold
                )
                resourceIndicator(
                    icon: "snowflake",
                    percent: gameState.coolingPercent,
                    fillColor: Color(red: 0.55, green: 0.72, blue: 0.88)
                )
                resourceIndicator(
                    icon: "network",
                    percent: gameState.bandwidthPercent,
                    fillColor: Color(red: 0.68, green: 0.58, blue: 0.82)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.background.opacity(0.92))
                    .shadow(color: Theme.woodTone.opacity(0.15), radius: 6, y: 2)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .animation(.spring(response: 0.3), value: gameState.money)
        .animation(.spring(response: 0.3), value: gameState.powerPercent)
        .animation(.spring(response: 0.3), value: gameState.coolingPercent)
        .animation(.spring(response: 0.3), value: gameState.bandwidthPercent)
    }

    // MARK: - Money Section

    private var moneySection: some View {
        HStack(spacing: 8) {
            Text("\u{1FA99}")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 1) {
                Text("$\(Int(gameState.money))")
                    .font(Theme.moneyFont(size: 18))
                    .foregroundStyle(Theme.accentGold)
                    .contentTransition(.numericText())

                Text("+$\(Int(gameState.revenuePerSecond))/s")
                    .font(Theme.bodyFont(size: 11))
                    .foregroundStyle(Theme.positive)
            }
        }
    }

    // MARK: - Objective Banner

    private func objectiveBanner(_ objective: Objective) -> some View {
        HStack(spacing: 10) {
            Text(objective.description)
                .font(Theme.bodyFont(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cardBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * min(objective.progress, 1.0))
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(objective.progress * 100))%")
                .font(Theme.headlineFont(size: 12))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.background.opacity(0.92))
                .shadow(color: Theme.woodTone.opacity(0.1), radius: 4, y: 1)
        )
    }

    // MARK: - Resource Indicator

    private func resourceIndicator(icon: String, percent: Double, fillColor: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(fillColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.cardBackground)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(fillColor)
                            .frame(width: geo.size.width * min(percent / 100, 1.0))
                    }
                }
                .frame(width: 50, height: 6)

                // Status icon instead of raw numbers
                Text(resourceStatusText(percent))
                    .font(Theme.bodyFont(size: 9))
                    .foregroundStyle(resourceStatusColor(percent))
            }
        }
    }

    private func resourceStatusText(_ percent: Double) -> String {
        if percent > 85 { return "\u{1F525} High" }
        if percent > 60 { return "\u{26A0}\u{FE0F} Warm" }
        return "\u{2713} Good"
    }

    private func resourceStatusColor(_ percent: Double) -> Color {
        if percent > 85 { return Theme.critical }
        if percent > 60 { return Theme.warning }
        return Theme.positive
    }
}
