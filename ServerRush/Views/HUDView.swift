import SwiftUI

struct HUDView: View {
    let gameState: GameState

    var body: some View {
        HStack(spacing: 12) {
            // Money
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.4))
                    .font(.system(size: 16, weight: .bold))

                VStack(alignment: .leading, spacing: 0) {
                    Text("$\(Int(gameState.money))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("+$\(Int(gameState.revenuePerSecond))/s")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.4))
                }
            }

            Spacer()

            // Resource bars
            ResourceBarCompact(
                icon: "bolt.fill",
                value: gameState.powerPercent,
                label: "\(Int(gameState.powerUsage))/\(Int(gameState.powerCapacity))"
            )

            ResourceBarCompact(
                icon: "snowflake",
                value: gameState.coolingPercent,
                label: "\(Int(gameState.coolingUsage))/\(Int(gameState.coolingCapacity))"
            )

            ResourceBarCompact(
                icon: "network",
                value: gameState.bandwidthPercent,
                label: "\(Int(gameState.bandwidthUsage))/\(Int(gameState.bandwidthCapacity))"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .animation(.spring(response: 0.3), value: gameState.money)
        .animation(.spring(response: 0.3), value: gameState.powerPercent)
        .animation(.spring(response: 0.3), value: gameState.coolingPercent)
        .animation(.spring(response: 0.3), value: gameState.bandwidthPercent)
    }
}

// MARK: - Compact Resource Bar
private struct ResourceBarCompact: View {
    let icon: String
    let value: Double
    let label: String

    private var barColor: Color {
        if value > 80 { return Color(red: 1, green: 0.09, blue: 0.27) }
        if value > 60 { return Color(red: 1, green: 0.7, blue: 0) }
        return Color(red: 0, green: 0.9, blue: 0.4)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(barColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                // Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [barColor.opacity(0.8), barColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(value / 100, 1.0))
                            .shadow(color: barColor.opacity(0.5), radius: 3, x: 0, y: 0)
                    }
                }
                .frame(width: 50, height: 6)

                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
            }
        }
    }
}
