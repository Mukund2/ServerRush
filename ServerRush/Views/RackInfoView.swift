import SwiftUI

struct RackInfoView: View {
    let gameState: GameState
    let equipment: PlacedEquipment

    @State private var showConfirmSell = false

    private var spec: EquipmentSpec { equipment.type.spec }

    // Equipment mood emoji
    private var moodEmoji: String {
        if equipment.status == .offline { return "\u{1F4A4}" }           // sleeping
        if equipment.health < 25 || equipment.temperature > 70 { return "\u{1F630}" }  // overheating/critical
        if equipment.health < 50 { return "\u{1F613}" }                  // stressed
        return "\u{1F60A}"                                                // happy
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Theme.woodTone.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            VStack(spacing: 14) {
                header
                statsSection
                healthAndTemp
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .woodPanel(cornerRadius: Theme.Radius.xl, borderWidth: 3, shadowRadius: 10)
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Mood emoji + icon
            ZStack {
                Circle()
                    .fill(Theme.cardBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.woodTone.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 2) {
                    Text(moodEmoji)
                        .font(.system(size: 18))
                    Image(systemName: equipment.type.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(equipment.type.displayName)
                    .font(Theme.headlineFont(size: 18))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Text("Tier \(equipment.type.tier)")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.accent.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Theme.accent.opacity(0.2), lineWidth: 0.5)
                                )
                        )

                    statusBadge
                }
            }

            Spacer()

            // Close
            Button {
                AudioManager.shared.playUITap()
                gameState.selectedTile = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Theme.cardBackground)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                            )
                    )
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch equipment.status {
            case .normal: return ("Online", Theme.positive)
            case .warning: return ("Warning", Theme.warning)
            case .critical: return ("Critical", Theme.critical)
            case .offline: return ("Offline", Theme.textSecondary)
            }
        }()

        Text(text)
            .font(Theme.bodyFont(size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(
                        Capsule()
                            .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
                    )
            )
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 10) {
            if spec.revenuePerSec > 0 {
                friendlyStatCard(
                    icon: "dollarsign.circle",
                    text: "Making $\(Int(spec.revenuePerSec)) per second",
                    color: Theme.positive
                )
            }
            if spec.powerProvide > 0 {
                friendlyStatCard(
                    icon: "bolt.fill",
                    text: "Provides \(Int(spec.powerProvide))W",
                    color: Theme.accentGold
                )
            }
            if spec.powerDraw > 0 {
                friendlyStatCard(
                    icon: "bolt.fill",
                    text: "Uses \(Int(spec.powerDraw))W",
                    color: Theme.warning
                )
            }
            if spec.coolingProvide > 0 {
                friendlyStatCard(
                    icon: "snowflake",
                    text: "Cools \(Int(spec.coolingProvide)) units",
                    color: Color(red: 0.55, green: 0.72, blue: 0.88)
                )
            }
            if spec.bandwidthProvide > 0 {
                friendlyStatCard(
                    icon: "network",
                    text: "\(Int(spec.bandwidthProvide)) Mbps",
                    color: Color(red: 0.68, green: 0.58, blue: 0.82)
                )
            }
        }
    }

    private func friendlyStatCard(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(text)
                .font(Theme.bodyFont(size: 10))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Health & Temperature

    private var healthAndTemp: some View {
        VStack(spacing: 10) {
            // Health bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Health")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(equipment.health))%")
                        .font(Theme.headlineFont(size: 11))
                        .foregroundStyle(healthColor)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                            )
                        RoundedRectangle(cornerRadius: 5)
                            .fill(healthColor)
                            .frame(width: geo.size.width * equipment.health / 100)
                    }
                }
                .frame(height: 10)
            }

            // Temperature bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Temperature")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(equipment.temperature))\u{00B0}C")
                        .font(Theme.headlineFont(size: 11))
                        .foregroundStyle(tempColor)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Theme.woodTone.opacity(0.15), lineWidth: 0.5)
                            )
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.55, green: 0.72, blue: 0.88), Theme.accent, Theme.critical],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(equipment.temperature / 100, 1.0))
                    }
                }
                .frame(height: 10)
            }
        }
    }

    private var healthColor: Color {
        if equipment.health < 25 { return Theme.critical }
        if equipment.health < 50 { return Theme.warning }
        return Theme.positive
    }

    private var tempColor: Color {
        if equipment.temperature > 80 { return Theme.critical }
        if equipment.temperature > 60 { return Theme.warning }
        return Color(red: 0.55, green: 0.72, blue: 0.88)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Upgrade button
            if let upgrade = equipment.type.upgradesTo {
                let canUpgrade = gameState.canAfford(upgrade)
                Button {
                    AudioManager.shared.playUpgradeSound()
                    gameState.upgradeEquipment(at: equipment.position)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Upgrade")
                                .font(Theme.headlineFont(size: 12))
                            HStack(spacing: 2) {
                                Text("\u{1FA99}")
                                    .font(.system(size: 8))
                                Text("$\(Int(upgrade.cost))")
                                    .font(Theme.bodyFont(size: 9))
                            }
                        }
                    }
                    .foregroundStyle(canUpgrade ? .white : Theme.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(CozyButtonStyle(color: canUpgrade ? Theme.accent : Theme.cardBackground, cornerRadius: Theme.Radius.md))
                .disabled(!canUpgrade)
            }

            // Sell button
            Button {
                if showConfirmSell {
                    AudioManager.shared.playSellSound()
                } else {
                    AudioManager.shared.playUITap()
                }
                if showConfirmSell {
                    gameState.sellEquipment(at: equipment.position)
                    gameState.selectedTile = nil
                } else {
                    showConfirmSell = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showConfirmSell ? "exclamationmark.triangle.fill" : "arrow.down.to.line")
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(showConfirmSell ? "Confirm?" : "Sell")
                            .font(Theme.headlineFont(size: 12))
                        Text("+$\(Int(equipment.type.cost * 0.5))")
                            .font(Theme.bodyFont(size: 9))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(CozyButtonStyle(color: showConfirmSell ? Theme.woodTone.opacity(0.5) : Theme.cardBackground, cornerRadius: Theme.Radius.md))
            .animation(.spring(response: 0.3), value: showConfirmSell)
        }
    }
}
