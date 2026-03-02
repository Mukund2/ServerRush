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
            // Build mode cancel bar
            if gameState.buildMode != nil {
                buildModeBar
            }

            // Collapse handle
            collapseHandle

            if isExpanded {
                VStack(spacing: 0) {
                    categoryTabs
                    equipmentList
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.background.opacity(0.95))
                .shadow(color: Theme.woodTone.opacity(0.2), radius: 10, y: -4)
        )
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isExpanded.toggle()
        } label: {
            VStack(spacing: 4) {
                // Wood-tone handle
                Capsule()
                    .fill(Theme.woodTone.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 12))
                    Text("BUILD")
                        .font(Theme.headlineFont(size: 12))
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        HStack(spacing: 8) {
            ForEach(categories, id: \.self) { category in
                let hasItems = !itemsForCategory(category).isEmpty
                let isSelected = selectedCategory == category

                Button {
                    guard hasItems else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedCategory = category
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 12))
                        Text(category.rawValue)
                            .font(Theme.bodyFont(size: 11))
                    }
                    .foregroundStyle(
                        isSelected ? .white : (hasItems ? Theme.textPrimary : Theme.textSecondary.opacity(0.4))
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isSelected ? categoryColor(category) : Theme.cardBackground.opacity(0.6))
                    )
                }
                .disabled(!hasItems)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Equipment List

    private var equipmentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(itemsForCategory(selectedCategory)) { item in
                    WarmEquipmentCard(type: item, canAfford: gameState.canAfford(item)) {
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

// MARK: - Warm Equipment Card

private struct WarmEquipmentCard: View {
    let type: EquipmentType
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(canAfford ? Theme.accent : Theme.textSecondary.opacity(0.4))

                Text(type.displayName)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundStyle(canAfford ? Theme.textPrimary : Theme.textSecondary.opacity(0.5))
                    .lineLimit(1)

                // Price with coin icon
                HStack(spacing: 3) {
                    Text("\u{1FA99}")
                        .font(.system(size: 10))
                    Text("$\(Int(type.cost))")
                        .font(Theme.moneyFont(size: 12))
                        .foregroundStyle(canAfford ? Theme.accentGold : Theme.critical.opacity(0.6))
                }

                friendlyStatLine
            }
            .frame(width: 95)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground.opacity(canAfford ? 1 : 0.5))
                    .shadow(color: Theme.woodTone.opacity(canAfford ? 0.12 : 0), radius: 4, y: 2)
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
