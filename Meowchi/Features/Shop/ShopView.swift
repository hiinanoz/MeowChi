import SwiftUI

/// Coin shop. Food only for now; toys and decorations join in Phase 5.
@MainActor
struct ShopView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var notice: LocalizedStringKey?

    var body: some View {
        SheetScaffold(title: "shop.title", onClose: { dismiss() }) {
            HStack {
                PixelIcon(name: "icon_coin", size: 18)
                Text(store.state.coins, format: .number).font(PixelFont.body(16)).monospacedDigit()
                Spacer()
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.bad) }
            }
            ForEach(ItemCatalog.foods) { food in
                HStack(spacing: 10) {
                    PixelIcon(name: food.iconName, size: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.nameKey).font(PixelFont.body(13))
                        Text("shop.owned \(store.quantity(of: food.id))").font(PixelFont.body(10))
                            .foregroundStyle(PixelPalette.accentShade)
                    }
                    Spacer()
                    Button { buy(food) } label: {
                        HStack(spacing: 4) {
                            PixelIcon(name: "icon_coin", size: 14)
                            Text(food.price, format: .number)
                        }
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    .fixedSize()
                    .disabled(store.state.coins < food.price)
                }
                .padding(8)
                .background(PixelBorder().fill(PixelPalette.panelShade))
            }
        }
    }

    private func buy(_ food: FoodItem) {
        let result = store.buy(food.id)
        if result == .ok { AudioManager.shared.play(.buy) }
        notice = result == .insufficientCoins ? "notice.noCoins" : nil
    }
}

/// Shared pixel sheet layout (title bar + scrolling content).
struct SheetScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title).font(PixelFont.body(17))
                Spacer()
                Button(action: onClose) { Text("common.close") }
                    .font(PixelFont.body(12))
                    .foregroundStyle(PixelPalette.accentShade)
            }
            ScrollView {
                VStack(spacing: 8) { content }
            }
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(14)
        .background(PixelPalette.panel.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
