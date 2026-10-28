import SwiftUI

/// Top HUD: name, mood, level/XP, coins and the five need bars.
struct HUDView: View {
    @Environment(GameStore.self) private var store
    var onShop: @MainActor () -> Void = {}
    var onTasks: @MainActor () -> Void = {}
    var onSettings: @MainActor () -> Void = {}
    var onMainMenu: @MainActor () -> Void = {}
    var onCollection: @MainActor () -> Void = {}

    var body: some View {
        let state = store.state
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CatPreview(look: state.cat.look, size: 64)
                    .frame(width: 44, height: 40, alignment: .top)
                    .clipped()
                    .padding(2)
                    .pixelPanel(PixelPalette.panelShade)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(verbatim: state.cat.name).font(PixelFont.body(16))
                        Text(store.mood.titleKey)
                            .font(PixelFont.body(11))
                            .foregroundStyle(PixelPalette.accentShade)
                    }
                    HStack(spacing: 6) {
                        Text("hud.level \(state.progression.level)").font(PixelFont.body(11))
                        PixelBar(value: Double(state.progression.xp) / Double(store.balance.xpRequired(forLevel: state.progression.level)) * 100,
                                 color: PixelPalette.xp, segments: 12)
                            .frame(maxWidth: 110)
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    Button { onShop() } label: {
                        HStack(spacing: 4) {
                            PixelIcon(name: "icon_coin", size: 16)
                            Text(state.coins, format: .number).font(PixelFont.body(14)).monospacedDigit()
                            PixelIcon(name: "icon_shop", size: 14)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .pixelPanel(PixelPalette.panelShade)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("hud.coins \(state.coins)"))
                    .accessibilityHint(Text("shop.title"))
                    HStack(spacing: 6) {
                    Button { onMainMenu() } label: {
                        PixelIcon(name: "icon_menu", size: 14)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .pixelPanel(PixelPalette.panelShade)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("menu.mainMenu"))
                    Button { onCollection() } label: {
                        PixelIcon(name: "icon_collection", size: 14)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .pixelPanel(PixelPalette.panelShade)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("collection.title"))
                    Button { onSettings() } label: {
                        PixelIcon(name: "icon_settings", size: 14)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .pixelPanel(PixelPalette.panelShade)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("settings.title"))
                    Button { onTasks() } label: {
                        HStack(spacing: 4) {
                            PixelIcon(name: "icon_tasks", size: 14)
                            Text(verbatim: "\(state.daily.tasks.filter(\.claimed).count)/\(state.daily.tasks.count)")
                                .font(PixelFont.body(11)).monospacedDigit()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .pixelPanel(PixelPalette.panelShade)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("tasks.title"))
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(StatKind.allCases) { kind in
                    StatChip(kind: kind, value: state.cat.stats[kind])
                }
            }
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(10)
        .pixelPanel()
    }
}

private struct StatChip: View {
    let kind: StatKind
    let value: Double
    private var percent: Double { value.rounded() / 100 }

    var body: some View {
        VStack(spacing: 3) {
            PixelIcon(name: kind.iconName, size: 16)
            PixelBar(value: value, color: PixelPalette.level(value), segments: 5)
            Text(percent, format: .percent).font(PixelFont.body(9)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.titleKey))
        .accessibilityValue(Text(percent, format: .percent))
    }
}
