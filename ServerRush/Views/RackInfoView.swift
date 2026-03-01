import SwiftUI

struct RackInfoView: View {
    let gameState: GameState
    let equipment: PlacedEquipment

    @State private var showConfirmSell = false

    private var spec: EquipmentSpec { equipment.type.spec }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            VStack(spacing: 16) {
                // Header
                header

                // Stats
                statsGrid

                // Health & Temperature bars
                healthAndTemp

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(red: 0, green: 0.9, blue: 1).opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.6), radius: 20, y: -10)
        )
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0, green: 0.9, blue: 1).opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: equipment.type.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                    .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.5), radius: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(equipment.type.displayName)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text("Tier \(equipment.type.tier)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(red: 0, green: 0.9, blue: 1).opacity(0.15))
                        )

                    statusBadge
                }
            }

            Spacer()

            // Close button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                gameState.selectedTile = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch equipment.status {
            case .normal: return ("ONLINE", Color(red: 0, green: 0.9, blue: 0.4))
            case .warning: return ("WARNING", Color(red: 1, green: 0.7, blue: 0))
            case .critical: return ("CRITICAL", Color(red: 1, green: 0.09, blue: 0.27))
            case .offline: return ("OFFLINE", .gray)
            }
        }()

        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            if spec.revenuePerSec > 0 {
                statItem(icon: "dollarsign.circle", label: "Revenue", value: "+$\(Int(spec.revenuePerSec))/s", color: Color(red: 0, green: 0.9, blue: 0.4))
            }
            if spec.powerDraw > 0 {
                statItem(icon: "bolt.fill", label: "Power", value: "\(Int(spec.powerDraw))W", color: Color(red: 1, green: 0.7, blue: 0))
            }
            if spec.powerProvide > 0 {
                statItem(icon: "bolt.fill", label: "Power", value: "+\(Int(spec.powerProvide))W", color: Color(red: 0, green: 0.9, blue: 0.4))
            }
            if spec.coolingProvide > 0 {
                statItem(icon: "snowflake", label: "Cooling", value: "+\(Int(spec.coolingProvide))", color: Color(red: 0.3, green: 0.6, blue: 1))
            }
            if spec.heatGenerate > 0 {
                statItem(icon: "flame", label: "Heat", value: "+\(Int(spec.heatGenerate))", color: Color(red: 1, green: 0.4, blue: 0.2))
            }
            if spec.bandwidthProvide > 0 {
                statItem(icon: "network", label: "BW", value: "+\(Int(spec.bandwidthProvide))", color: Color(red: 0.6, green: 0.4, blue: 1))
            }
            if spec.bandwidthUse > 0 {
                statItem(icon: "network", label: "BW Use", value: "\(Int(spec.bandwidthUse))", color: Color(red: 1, green: 0.7, blue: 0))
            }
        }
    }

    private func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Health & Temperature

    private var healthAndTemp: some View {
        VStack(spacing: 10) {
            // Health bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Health")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text("\(Int(equipment.health))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(healthColor)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [healthColor.opacity(0.7), healthColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * equipment.health / 100)
                            .shadow(color: healthColor.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 8)
            }

            // Temperature
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Temperature")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text("\(Int(equipment.temperature)) C")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(tempColor)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [tempColor.opacity(0.7), tempColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(equipment.temperature / 100, 1.0))
                            .shadow(color: tempColor.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private var healthColor: Color {
        if equipment.health < 25 { return Color(red: 1, green: 0.09, blue: 0.27) }
        if equipment.health < 50 { return Color(red: 1, green: 0.7, blue: 0) }
        return Color(red: 0, green: 0.9, blue: 0.4)
    }

    private var tempColor: Color {
        if equipment.temperature > 80 { return Color(red: 1, green: 0.09, blue: 0.27) }
        if equipment.temperature > 60 { return Color(red: 1, green: 0.7, blue: 0) }
        return Color(red: 0.3, green: 0.6, blue: 1)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Upgrade button
            if let upgrade = equipment.type.upgradesTo {
                let canUpgrade = gameState.canAfford(upgrade)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    gameState.upgradeEquipment(at: equipment.position)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("UPGRADE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            Text("$\(Int(upgrade.cost)) -> \(upgrade.displayName)")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(canUpgrade ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                canUpgrade
                                    ? Color(red: 0, green: 0.9, blue: 1).opacity(0.2)
                                    : Color.white.opacity(0.03)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        canUpgrade
                                            ? Color(red: 0, green: 0.9, blue: 1).opacity(0.4)
                                            : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .disabled(!canUpgrade)
            }

            // Sell button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if showConfirmSell {
                    gameState.sellEquipment(at: equipment.position)
                    gameState.selectedTile = nil
                } else {
                    showConfirmSell = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showConfirmSell ? "exclamationmark.triangle.fill" : "trash.fill")
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(showConfirmSell ? "CONFIRM" : "SELL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("+$\(Int(equipment.type.cost * 0.5))")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .opacity(0.7)
                    }
                }
                .foregroundStyle(showConfirmSell ? .white : Color(red: 1, green: 0.09, blue: 0.27))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            showConfirmSell
                                ? Color(red: 1, green: 0.09, blue: 0.27).opacity(0.3)
                                : Color(red: 1, green: 0.09, blue: 0.27).opacity(0.1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(red: 1, green: 0.09, blue: 0.27).opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .animation(.spring(response: 0.3), value: showConfirmSell)
        }
    }
}
