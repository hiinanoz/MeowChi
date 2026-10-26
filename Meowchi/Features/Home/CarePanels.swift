import SwiftUI

/// Bottom-sheet style panels that open above the action bar.
enum CarePanel: Equatable {
    case food, clean, health
}

@MainActor
struct FoodPanel: View {
    @Environment(GameStore.self) private var store
    let onPick: @MainActor (FoodItem) -> Void

    var body: some View {
        let owned = ItemCatalog.foods.filter { store.quantity(of: $0.id) > 0 }
        PanelContainer(title: "food.title") {
            if owned.isEmpty {
                Text("notice.noFood").font(PixelFont.body(12))
            } else {
                ForEach(owned) { food in
                    Button { onPick(food) } label: {
                        PanelRow(icon: food.iconName, title: food.nameKey,
                                 detail: Text(verbatim: "×\(store.quantity(of: food.id))"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

@MainActor
struct CleanPanel: View {
    @Environment(GameStore.self) private var store
    let onBath: @MainActor () -> Void
    let onBrush: @MainActor () -> Void
    let onLitter: @MainActor () -> Void

    var body: some View {
        PanelContainer(title: "action.clean") {
            Button { onBath() } label: { PanelRow(icon: "icon_clean", title: "clean.bath", detail: nil) }
                .buttonStyle(.plain)
            Button { onBrush() } label: { PanelRow(icon: "icon_brush", title: "clean.brush", detail: nil) }
                .buttonStyle(.plain)
            Button { onLitter() } label: {
                PanelRow(icon: "icon_cleanliness", title: "clean.litter",
                         detail: Text(store.state.care.litter / 100, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(store.isLitterDirty ? PixelPalette.bad : PixelPalette.ink))
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
struct HealthPanel: View {
    @Environment(GameStore.self) private var store
    let onVet: @MainActor () -> Void

    var body: some View {
        let stats = store.state.cat.stats
        PanelContainer(title: "stat.health") {
            HStack(spacing: 8) {
                PixelIcon(name: "icon_health", size: 18)
                PixelBar(value: stats.health, color: PixelPalette.level(stats.health), segments: 10)
                Text(stats.health / 100, format: .percent.precision(.fractionLength(0)))
                    .font(PixelFont.body(12)).monospacedDigit()
            }
            Text(tipKey(for: stats))
                .font(PixelFont.body(11))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onVet() } label: {
                HStack(spacing: 6) {
                    PixelIcon(name: "icon_health", size: 16)
                    Text("health.vet")
                }
            }
            .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            Text("health.vet.hint").font(PixelFont.body(9)).foregroundStyle(PixelPalette.accentShade)
        }
    }

    /// Points the player at the lowest need, the main driver of health.
    private func tipKey(for stats: CatStats) -> LocalizedStringKey {
        let lowest = [StatKind.hunger, .cleanliness, .energy, .happiness].min { stats[$0] < stats[$1] } ?? .hunger
        return stats[lowest] >= 60 ? "health.tip.good" : LocalizedStringKey("health.tip." + lowest.rawValue)
    }
}

private struct PanelContainer<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(PixelFont.body(14))
            content
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }
}

private struct PanelRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: Text?

    var body: some View {
        HStack(spacing: 10) {
            PixelIcon(name: icon, size: 20)
            Text(title).font(PixelFont.body(13))
            Spacer(minLength: 4)
            detail?.font(PixelFont.body(12)).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(PixelBorder().fill(PixelPalette.panelShade))
        .contentShape(Rectangle())
    }
}
