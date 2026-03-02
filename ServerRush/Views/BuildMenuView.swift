import SwiftUI

struct BuildMenuView: View {
    let gameState: GameState
    @State private var isExpanded = true
    @State private var selectedCategory: EquipmentCategory = .rack

    private let categories = EquipmentCategory.allCases

    // Category pill colors
    private func categoryColor(_ cat: EquipmentCategory) -> Color {
        switch cat {
        case .rack: return Color(red: 0.60, green: 0.63, blue: 0.58)    // warm gray
        case .cooling: return Color(red: 0.55, green: 0.72, blue: 0.88) // soft blue
        case .power: return Theme.accentGold                              // warm amber
        case .network: return Color(red: 0.68, green: 0.58, blue: 0.82) // soft lavender
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Build mode cancel bar (show on top when placing)
            if gameState.buildMode != nil {
                buildModeBar
            }

            // Collapse handle
            collapseHandle

            if isExpanded && gameState.buildMode == nil {
                VStack(spacing: 0) {
                    categoryTabs
                    equipmentList
                }
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.background.opacity(0.95))
                .shadow(color: Theme.woodTone.opacity(0.2), radius: 8, y: -3)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: gameState.buildMode == nil)
    }

    // MARK: - Build Mode Bar

    private var buildModeBar: some View {
        HStack {
            if let type = gameState.buildMode {
                Image(systemName: type.icon)
                    .foregroundStyle(Theme.accent)
                Text("Placing: \(type.displayName)")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                AudioManager.shared.playUITap()
                gameState.buildMode = nil
            } label: {
                Text("Cancel")
                    .font(Theme.headlineFont(size: 12))
                    .foregroundStyle(Theme.critical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.critical.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.06))
    }

    // MARK: - Collapse Handle

    private var collapseHandle: some View {
        Button {
            AudioManager.shared.playUITap()
            isExpanded.toggle()
        } label: {
            VStack(spacing: 2) {
                Capsule()
                    .fill(Theme.woodTone.opacity(0.4))
                    .frame(width: 32, height: 4)
                    .padding(.top, 6)

                HStack(spacing: 5) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 10))
                    Text("BUILD")
                        .font(Theme.headlineFont(size: 11))
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(categories, id: \.self) { category in
                let hasItems = !itemsForCategory(category).isEmpty
                let isSelected = selectedCategory == category

                Button {
                    guard hasItems else { return }
                    AudioManager.shared.playUITap()
                    selectedCategory = category
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10))
                        Text(category.rawValue)
                            .font(Theme.bodyFont(size: 10))
                    }
                    .foregroundStyle(
                        isSelected ? .white : (hasItems ? Theme.textPrimary : Theme.textSecondary.opacity(0.4))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isSelected ? categoryColor(category) : Theme.cardBackground.opacity(0.6))
                    )
                }
                .disabled(!hasItems)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Equipment List

    private var equipmentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(itemsForCategory(selectedCategory)) { item in
                    WarmEquipmentCard(type: item, canAfford: gameState.canAfford(item)) {
                        AudioManager.shared.playUITap()
                        gameState.buildMode = item
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func itemsForCategory(_ category: EquipmentCategory) -> [EquipmentType] {
        gameState.unlockedEquipment.filter { $0.category == category }
    }
}

// MARK: - Warm Equipment Card

private struct WarmEquipmentCard: View {
    let type: EquipmentType
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(canAfford ? Theme.accent : Theme.textSecondary.opacity(0.4))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(Theme.bodyFont(size: 11))
                        .foregroundStyle(canAfford ? Theme.textPrimary : Theme.textSecondary.opacity(0.5))
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Text("$\(Int(type.cost))")
                            .font(Theme.moneyFont(size: 11))
                            .foregroundStyle(canAfford ? Theme.accentGold : Theme.critical.opacity(0.6))

                        friendlyStatLine
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.cardBackground.opacity(canAfford ? 1 : 0.5))
                    .shadow(color: Theme.woodTone.opacity(canAfford ? 0.12 : 0), radius: 3, y: 1)
            )
            .opacity(canAfford ? 1 : 0.6)
        }
        .disabled(!canAfford)
    }

    @ViewBuilder
    private var friendlyStatLine: some View {
        let spec = type.spec
        if spec.revenuePerSec > 0 {
            Text("Earns $\(Int(spec.revenuePerSec))/sec")
                .font(Theme.bodyFont(size: 9))
                .foregroundStyle(Theme.positive)
        } else if spec.powerProvide > 0 {
            Text("Provides \(Int(spec.powerProvide))W")
                .font(Theme.bodyFont(size: 9))
                .foregroundStyle(Theme.accentGold)
        } else if spec.coolingProvide > 0 {
            Text("Cools \(Int(spec.coolingProvide)) units")
                .font(Theme.bodyFont(size: 9))
                .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.88))
        } else if spec.bandwidthProvide > 0 {
            Text("\(Int(spec.bandwidthProvide)) Mbps")
                .font(Theme.bodyFont(size: 9))
                .foregroundStyle(Color(red: 0.68, green: 0.58, blue: 0.82))
        }
    }
}
