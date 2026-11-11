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
    @State private var path: [Tab]

    /// `startAtCat` opens straight on the cat's look and accessories (from Settings).
    init(startAtCat: Bool = false) {
        _path = State(initialValue: startAtCat ? [.cat] : Self.initialPath)
    }

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
            .firstTimeTip("decor", "tip.decor")
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

/// One decoration category (or the cat customizer), pushed from `DecorView`. Only places what the
/// player owns; buying happens in the Shop.
@MainActor
struct DecorItemsView: View {
    let tab: DecorView.Tab
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: tab.title, onClose: { dismiss() }, isPushed: true) {
            switch tab {
            case .cat:
                CatCustomizer(look: Binding(get: { store.state.cat.look }, set: { store.setLook($0) }))
                    .padding(10)
                    .background(PixelBorder().fill(PixelPalette.panelShade))
                Text("accessory.title").font(PixelFont.body(13)).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Accessory.allCases.filter { store.state.wardrobe.contains($0.rawValue) }) { accessoryCell($0) }
                }
            case .slot(let slot):
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DecorCatalog.items(in: slot).filter { store.state.decor.isOwned($0) }) { itemCell($0) }
                }
            }
            Text("decor.moreInShop").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
        }
    }

    private func itemCell(_ item: DecorItem) -> some View {
        let equipped = store.state.decor.equipped(item.slot) == item
        return VStack(spacing: 6) {
            DecorPreview(item: item)
            Text(item.nameKey).font(PixelFont.body(10)).lineLimit(2).multilineTextAlignment(.center)
            Group {
                if equipped {
                    Text("decor.inUse").font(PixelFont.body(10)).foregroundStyle(PixelPalette.goodText)
                } else {
                    Button("decor.use") { store.equipDecor(item.id) }
                        .buttonStyle(PixelButtonStyle(fill: PixelPalette.xp))
                }
            }
            .frame(height: 34)
        }
        .padding(8)
        .background(PixelBorder().fill(equipped ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
    }

    private func accessoryCell(_ item: Accessory) -> some View {
        let worn = store.state.cat.look.head == item.rawValue || store.state.cat.look.neck == item.rawValue
        return VStack(spacing: 6) {
            AccessoryPreview(item: item)
            Text(item.nameKey).font(PixelFont.body(10))
            Button(worn ? "accessory.remove" : "decor.use") { store.wear(item) }
                .buttonStyle(PixelButtonStyle(fill: worn ? PixelPalette.panel : PixelPalette.xp))
                .frame(height: 34)
        }
        .padding(8)
        .background(PixelBorder().fill(worn ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
    }
}
