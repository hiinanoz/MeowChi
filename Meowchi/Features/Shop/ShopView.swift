import SwiftUI

/// Coin shop: food, toys, accessories and decorations in tabs, plus one discounted item a day.
/// Everything is bought here; Decorate only places what the player owns.
@MainActor
struct ShopView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case food, toys, accessories, decor
        var id: String { rawValue }
        var titleKey: LocalizedStringKey { LocalizedStringKey("shop.tab." + rawValue) }
    }

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.food
    @State private var notice: LocalizedStringKey?
    @State private var purchases = 0
    @State private var pendingDecor: DecorItem?
    @State private var pendingAccessory: Accessory?

    /// Big purchases ask first (HIG: confirm costly actions).
    static let confirmThreshold = 200
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: "shop.title", onClose: { dismiss() }, accent: Color(red: 0.95, green: 0.60, blue: 0.29)) {
            HStack {
                PixelIcon(name: "icon_coin", size: 18)
                Text(store.state.coins, format: .number).font(PixelFont.body(16)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(store.state.coins)))
                    .animation(.snappy, value: store.state.coins)
                Spacer()
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.badText) }
            }
            dealCard
            tabBar
            switch tab {
            case .food:
                ForEach(ItemCatalog.foods) { foodRow($0) }
            case .toys:
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DecorCatalog.items(in: .toy).filter { !$0.isEmpty && ($0.isAvailable() || store.state.decor.isOwned($0)) }) {
                        decorCell($0)
                    }
                }
            case .accessories:
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Accessory.allCases) { accessoryCell($0) }
                }
            case .decor:
                ForEach(DecorSlot.allCases.filter { $0 != .toy }) { slot in
                    let items = DecorCatalog.items(in: slot)
                        .filter { !$0.isFree && !$0.isEmpty && ($0.isAvailable() || store.state.decor.isOwned($0)) }
                    if !items.isEmpty {
                        Text(slot.titleKey).font(PixelFont.body(12)).foregroundStyle(PixelPalette.accentShade)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(items) { decorCell($0) }
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: purchases)
        .confirmationDialog("purchase.confirm", isPresented: Binding(get: { pendingDecor != nil || pendingAccessory != nil },
                                                                     set: { if !$0 { pendingDecor = nil; pendingAccessory = nil } }),
                            titleVisibility: .visible) {
            Button("purchase.buy \(pendingDecor?.price ?? pendingAccessory?.price ?? 0)") {
                if let item = pendingDecor { buyDecor(item, confirmed: true) }
                if let item = pendingAccessory { buyAccessory(item, confirmed: true) }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }

    // MARK: Pieces

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { item in
                let selected = item == tab
                Button {
                    AudioManager.shared.play(.tab)
                    withAnimation(.easeOut(duration: 0.15)) { tab = item }
                } label: {
                    Text(item.titleKey).font(PixelFont.body(11)).lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(PixelBorder().fill(selected ? PixelPalette.warn : PixelPalette.panelShade))
                        .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(PixelPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var dealCard: some View {
        if let deal = store.dailyDeal {
            let owned = store.isOwned(deal.item)
            HStack(spacing: 10) {
                Group {
                    switch deal.item {
                    case .decor(let item): DecorPreview(item: item)
                    case .accessory(let item): AccessoryPreview(item: item)
                    }
                }
                .frame(width: 64, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("shop.deal").font(PixelFont.body(11)).foregroundStyle(PixelPalette.badText)
                    switch deal.item {
                    case .decor(let item): Text(item.nameKey).font(PixelFont.body(13))
                    case .accessory(let item): Text(item.nameKey).font(PixelFont.body(13))
                    }
                    if !owned {
                        Text(deal.fullPrice, format: .number).font(PixelFont.body(10)).strikethrough()
                            .foregroundStyle(PixelPalette.accentShade)
                    }
                }
                Spacer(minLength: 0)
                if owned {
                    Text("shop.soldOut").font(PixelFont.body(10)).foregroundStyle(PixelPalette.goodText)
                        .multilineTextAlignment(.trailing)
                } else {
                    Button { buyDeal() } label: {
                        HStack(spacing: 3) { PixelIcon(name: "icon_coin", size: 12); Text(deal.price, format: .number) }
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    .fixedSize()
                    .disabled(store.state.coins < deal.price)
                }
            }
            .padding(10)
            .background(PixelBorder().fill(Color(red: 1.0, green: 0.88, blue: 0.70)))
            .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 2))
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 10) {
            PixelIcon(name: food.iconName, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.nameKey).font(PixelFont.body(13))
                Text("shop.owned \(store.quantity(of: food.id))").font(PixelFont.body(10))
                    .foregroundStyle(PixelPalette.accentShade)
            }
            Spacer()
            priceButton(food.price) { buyFood(food) }
        }
        .padding(8)
        .background(PixelBorder().fill(PixelPalette.panelShade))
    }

    private func decorCell(_ item: DecorItem) -> some View {
        let owned = store.state.decor.isOwned(item)
        let locked = store.state.progression.level < item.unlockLevel
        return VStack(spacing: 6) {
            DecorPreview(item: item)
                .overlay(alignment: .topTrailing) {
                    if let season = item.season {
                        Text(season.nameKey).font(PixelFont.body(8)).padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(PixelPalette.warn))
                    }
                }
            Text(item.nameKey).font(PixelFont.body(10)).lineLimit(2).multilineTextAlignment(.center)
            status(owned: owned, locked: locked, unlockLevel: item.unlockLevel, price: item.price) { buyDecor(item) }
        }
        .padding(8)
        .background(PixelBorder().fill(PixelPalette.panelShade))
        .opacity(locked ? 0.6 : 1)
    }

    private func accessoryCell(_ item: Accessory) -> some View {
        let owned = store.state.wardrobe.contains(item.rawValue)
        let locked = store.state.progression.level < item.unlockLevel
        return VStack(spacing: 6) {
            AccessoryPreview(item: item)
            Text(item.nameKey).font(PixelFont.body(10))
            status(owned: owned, locked: locked, unlockLevel: item.unlockLevel, price: item.price) { buyAccessory(item) }
        }
        .padding(8)
        .background(PixelBorder().fill(PixelPalette.panelShade))
        .opacity(locked ? 0.6 : 1)
    }

    @ViewBuilder
    private func status(owned: Bool, locked: Bool, unlockLevel: Int, price: Int, buy: @escaping () -> Void) -> some View {
        Group {
            if owned {
                Text("shop.ownedBadge").font(PixelFont.body(10)).foregroundStyle(PixelPalette.goodText)
            } else if locked {
                Text("decor.locked \(unlockLevel)").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
            } else {
                priceButton(price, action: buy)
            }
        }
        .frame(height: 34)
    }

    private func priceButton(_ price: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) { PixelIcon(name: "icon_coin", size: 12); Text(price, format: .number) }
                .padding(.horizontal, 8)
        }
        .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
        .fixedSize()
        .disabled(store.state.coins < price)
    }

    // MARK: Buying

    private func handle(_ result: ActionResult) {
        switch result {
        case .ok:
            AudioManager.shared.play(.buy)
            purchases += 1
            notice = nil
        case .insufficientCoins: notice = "notice.noCoins"
        default: break
        }
    }

    private func buyFood(_ food: FoodItem) { handle(store.buy(food.id)) }

    private func buyDeal() { handle(store.buyDailyDeal()) }

    private func buyDecor(_ item: DecorItem, confirmed: Bool = false) {
        if !confirmed, item.price >= Self.confirmThreshold { return pendingDecor = item }
        handle(store.buyDecor(item.id))
    }

    private func buyAccessory(_ item: Accessory, confirmed: Bool = false) {
        if !confirmed, item.price >= Self.confirmThreshold { return pendingAccessory = item }
        handle(store.buyAccessory(item))
    }
}
