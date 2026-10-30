import SwiftUI

/// Decoration hub (HIG: hierarchy via navigation). Groups → category page → buy or equip.
@MainActor
struct DecorView: View {
    enum Tab: Hashable {
        case cat
        case slot(DecorSlot)

        var title: LocalizedStringKey {
            switch self {
            case .cat: "decor.slot.cat"
            case .slot(let slot): slot.titleKey
            }
        }
    }

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Tab] = Self.initialPath

    private static var initialPath: [Tab] {
        #if DEBUG
        if CommandLine.arguments.contains("-decorTab") { return [.cat] }
        #endif
        return []
    }

    private let groups: [(LocalizedStringKey, [Tab])] = [
        ("decor.group.cat", [.cat]),
        ("decor.group.walls", [.slot(.wallpaper), .slot(.wallColor), .slot(.view), .slot(.wallArt)]),
        ("decor.group.floor", [.slot(.floor), .slot(.floorColor), .slot(.rug)]),
        ("decor.group.furniture", [.slot(.bed), .slot(.post), .slot(.plant), .slot(.toy), .slot(.tv)]),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            SheetScaffold(title: "decor.title", onClose: { dismiss() }) {
                ForEach(groups.indices, id: \.self) { g in
                    Text(groups[g].0).font(PixelFont.body(12)).foregroundStyle(PixelPalette.accentShade)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    ForEach(groups[g].1, id: \.self) { tab in
                        NavigationLink(value: tab) { row(tab) }.buttonStyle(.plain)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Tab.self) { tab in
                DecorItemsView(tab: tab).toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private func row(_ tab: Tab) -> some View {
        let current: LocalizedStringKey
        switch tab {
        case .cat: current = store.state.cat.look.coatValue.nameKey
        case .slot(let slot): current = store.state.decor.equipped(slot).nameKey
        }
        return HStack {
            Text(tab.title).font(PixelFont.body(13))
            Spacer()
            Text(current).font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade).lineLimit(1)
            Text(verbatim: "›").font(PixelFont.body(16))
        }
        .padding(.horizontal, 12).frame(minHeight: 44)
        .background(PixelBorder().fill(PixelPalette.panelShade))
        .contentShape(Rectangle())
    }
}

/// One decoration category (or the cat customizer), pushed from `DecorView`.
@MainActor
struct DecorItemsView: View {
    let tab: DecorView.Tab
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var notice: LocalizedStringKey?
    @State private var pendingDecor: DecorItem?
    @State private var pendingAccessory: Accessory?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: tab.title, onClose: { dismiss() }, isPushed: true) {
            HStack {
                PixelIcon(name: "icon_coin", size: 18)
                Text(store.state.coins, format: .number).font(PixelFont.body(15)).monospacedDigit()
                Spacer()
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.badText) }
            }
            switch tab {
            case .cat:
                CatCustomizer(look: Binding(get: { store.state.cat.look }, set: { store.setLook($0) }))
                    .padding(10)
                    .background(PixelBorder().fill(PixelPalette.panelShade))
                Text("accessory.title").font(PixelFont.body(13)).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Accessory.allCases) { accessoryCell($0) }
                }
            case .slot(let slot):
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DecorCatalog.items(in: slot)) { itemCell($0) }
                }
            }
        }
        .confirmationDialog("purchase.confirm", isPresented: Binding(get: { pendingDecor != nil || pendingAccessory != nil },
                                                                     set: { if !$0 { pendingDecor = nil; pendingAccessory = nil } }),
                            titleVisibility: .visible) {
            Button("purchase.buy \(pendingDecor?.price ?? pendingAccessory?.price ?? 0)") {
                if let item = pendingDecor { buy(item, confirmed: true) }
                if let item = pendingAccessory { buyAccessory(item, confirmed: true) }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.state.coins)
    }

    /// Big purchases ask first (HIG: confirm costly actions).
    static let confirmThreshold = 200

    private func itemCell(_ item: DecorItem) -> some View {
        let decor = store.state.decor
        let equipped = decor.equipped(item.slot) == item
        let owned = decor.isOwned(item)
        let locked = store.state.progression.level < item.unlockLevel
        return VStack(spacing: 6) {
            itemPreview(item)
            Text(item.nameKey).font(PixelFont.body(10)).lineLimit(2).multilineTextAlignment(.center)
            Group {
                if equipped {
                    Text("decor.inUse").font(PixelFont.body(10)).foregroundStyle(PixelPalette.goodText)
                } else if owned {
                    Button("decor.use") { notice = nil; store.equipDecor(item.id) }
                        .buttonStyle(PixelButtonStyle(fill: PixelPalette.xp))
                } else if locked {
                    Text("decor.locked \(item.unlockLevel)").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                } else {
                    Button { buy(item) } label: {
                        HStack(spacing: 3) { PixelIcon(name: "icon_coin", size: 12); Text(item.price, format: .number) }
                    }
                    .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    .disabled(store.state.coins < item.price)
                }
            }
            .frame(height: 34)
        }
        .padding(8)
        .background(PixelBorder().fill(equipped ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
    }

    @ViewBuilder private func itemPreview(_ item: DecorItem) -> some View {
        let decor = store.state.decor
        if item.isEmpty {
            PixelIcon(name: "icon_close", size: 24).frame(width: 64, height: 56)
        } else if let color = item.color {
            // Color swatch shown on the currently equipped pattern.
            let pattern = item.slot == .wallColor ? decor.equipped(.wallpaper).id : decor.equipped(.floor).id
            preview(pattern, cropBottom: item.slot == .floorColor).colorMultiply(color)
        } else if item.slot == .wallpaper {
            preview(item.id, cropBottom: false).colorMultiply(decor.equipped(.wallColor).color ?? .white)
        } else if item.slot == .floor {
            preview(item.id, cropBottom: true).colorMultiply(decor.equipped(.floorColor).color ?? .white)
        } else {
            preview(item.id, cropBottom: false)
        }
    }

    private func accessoryCell(_ item: Accessory) -> some View {
        let owned = store.state.wardrobe.contains(item.rawValue)
        let worn = store.state.cat.look.head == item.rawValue || store.state.cat.look.neck == item.rawValue
        let locked = store.state.progression.level < item.unlockLevel
        return VStack(spacing: 6) {
            Image("cat_acc_\(item.rawValue)_idle_0").interpolation(.none).resizable()
                .frame(width: 64, height: 64)
                .frame(width: 64, height: 40, alignment: item.slot == .head ? .top : .center)
                .clipped()
            Text(item.nameKey).font(PixelFont.body(10))
            Group {
                if owned {
                    Button(worn ? "accessory.remove" : "decor.use") { store.wear(item) }
                        .buttonStyle(PixelButtonStyle(fill: worn ? PixelPalette.panel : PixelPalette.xp))
                } else if locked {
                    Text("decor.locked \(item.unlockLevel)").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                } else {
                    Button { buyAccessory(item) } label: {
                        HStack(spacing: 3) { PixelIcon(name: "icon_coin", size: 12); Text(item.price, format: .number) }
                    }
                    .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    .disabled(store.state.coins < item.price)
                }
            }
            .frame(height: 34)
        }
        .padding(8)
        .background(PixelBorder().fill(worn ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
    }

    private func buyAccessory(_ item: Accessory, confirmed: Bool = false) {
        if !confirmed, item.price >= Self.confirmThreshold { return pendingAccessory = item }
        switch store.buyAccessory(item) {
        case .ok: AudioManager.shared.play(.buy); notice = nil
        case .insufficientCoins: notice = "notice.noCoins"
        default: break
        }
    }

    /// Big wall/floor textures are cropped to a swatch; small items are shown whole.
    private func preview(_ sprite: String, cropBottom: Bool) -> some View {
        Image(sprite)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: sprite.hasPrefix("wall_") || sprite.hasPrefix("floor_") ? .fill : .fit)
            .frame(width: 64, height: 56, alignment: cropBottom ? .bottom : .top)
            .clipped()
            .accessibilityHidden(true)
    }

    private func buy(_ item: DecorItem, confirmed: Bool = false) {
        if !confirmed, item.price >= Self.confirmThreshold { return pendingDecor = item }
        switch store.buyDecor(item.id) {
        case .ok: AudioManager.shared.play(.buy); notice = nil
        case .insufficientCoins: notice = "notice.noCoins"
        case .locked: notice = "decor.locked \(item.unlockLevel)"
        default: notice = nil
        }
    }
}
