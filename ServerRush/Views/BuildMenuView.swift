import SwiftUI

struct BuildMenuView: View {
    let gameState: GameState
    @State private var isExpanded = true
    @State private var selectedCategory: EquipmentCategory = .rack

    private let categories = EquipmentCategory.allCases

    var body: some View {
        VStack(spacing: 0) {
            // Build mode cancel bar
            if gameState.buildMode != nil {
                buildModeBar
            }

            // Expand/collapse handle
            collapseHandle

            if isExpanded {
                VStack(spacing: 0) {
                    // Category tabs
                    categoryTabs

                    // Equipment grid
                    equipmentList
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(red: 0, green: 0.9, blue: 1).opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 10, y: -5)
        )
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Build Mode Bar

    private var buildModeBar: some View {
        HStack {
            if let type = gameState.buildMode {
                Image(systemName: type.icon)
                    .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                Text("Placing: \(type.displayName)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                gameState.buildMode = nil
            } label: {
                Text("CANCEL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.09, blue: 0.27))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(red: 1, green: 0.09, blue: 0.27).opacity(0.15))
                            .overlay(Capsule().strokeBorder(Color(red: 1, green: 0.09, blue: 0.27).opacity(0.5)))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0, green: 0.9, blue: 1).opacity(0.05))
    }

    // MARK: - Collapse Handle

    private var collapseHandle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isExpanded.toggle()
        } label: {
            VStack(spacing: 4) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 12))
                    Text("BUILD")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.self) { category in
                let hasItems = !itemsForCategory(category).isEmpty
                Button {
                    guard hasItems else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedCategory = category
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(
                        selectedCategory == category
                            ? Color(red: 0, green: 0.9, blue: 1)
                            : hasItems ? .gray : .gray.opacity(0.3)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedCategory == category
                            ? Color(red: 0, green: 0.9, blue: 1).opacity(0.1)
                            : Color.clear
                    )
                }
                .disabled(!hasItems)
            }
        }
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Equipment List

    private var equipmentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(itemsForCategory(selectedCategory)) { item in
                    EquipmentCard(type: item, canAfford: gameState.canAfford(item)) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        gameState.buildMode = item
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func itemsForCategory(_ category: EquipmentCategory) -> [EquipmentType] {
        gameState.unlockedEquipment.filter { $0.category == category }
    }
}

// MARK: - Equipment Card

private struct EquipmentCard: View {
    let type: EquipmentType
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(canAfford ? Color(red: 0, green: 0.9, blue: 1) : .gray)
                    .shadow(color: canAfford ? Color(red: 0, green: 0.9, blue: 1).opacity(0.4) : .clear, radius: 4)

                // Name
                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(canAfford ? .white : .gray)
                    .lineLimit(1)

                // Cost
                Text("$\(Int(type.cost))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(canAfford ? Color(red: 0, green: 0.9, blue: 0.4) : Color(red: 1, green: 0.09, blue: 0.27))

                // Brief stats
                statLine
            }
            .frame(width: 90)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(canAfford ? 0.06 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                canAfford
                                    ? Color(red: 0, green: 0.9, blue: 1).opacity(0.2)
                                    : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
            .opacity(canAfford ? 1 : 0.5)
        }
        .disabled(!canAfford)
    }

    @ViewBuilder
    private var statLine: some View {
        let spec = type.spec
        if spec.revenuePerSec > 0 {
            Text("+$\(Int(spec.revenuePerSec))/s")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.4).opacity(0.8))
        } else if spec.powerProvide > 0 {
            Text("+\(Int(spec.powerProvide))W")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 1, green: 0.7, blue: 0).opacity(0.8))
        } else if spec.coolingProvide > 0 {
            Text("+\(Int(spec.coolingProvide)) cool")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1).opacity(0.8))
        } else if spec.bandwidthProvide > 0 {
            Text("+\(Int(spec.bandwidthProvide)) Mbps")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.6, green: 0.4, blue: 1).opacity(0.8))
        }
    }
}
