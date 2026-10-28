import SwiftUI

/// Room decoration: pick a slot, then buy or equip an item. The "cat" tab changes the coat color.
@MainActor
struct DecorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .slot(.bed)
    @State private var notice: LocalizedStringKey?

    enum Tab: Hashable {
        case cat
        case slot(DecorSlot)
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: "decor.title", onClose: { dismiss() }) {
            HStack {
                PixelIcon(name: "icon_coin", size: 18)
                Text(store.state.coins, format: .number).font(PixelFont.body(15)).monospacedDigit()
                Spacer()
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.bad) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(.cat, "decor.slot.cat")
                    ForEach(DecorSlot.allCases) { chip(.slot($0), $0.titleKey) }
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                switch tab {
                case .cat:
                    ForEach(CatAppearance.allCases) { appearanceCell($0) }
                case .slot(let slot):
                    ForEach(DecorCatalog.items(in: slot)) { itemCell($0) }
                }
            }
        }
    }

    private func chip(_ target: Tab, _ title: LocalizedStringKey) -> some View {
        Button { tab = target; notice = nil } label: {
            Text(title).font(PixelFont.body(11)).padding(.horizontal, 10).padding(.vertical, 6)
                .background(PixelBorder().fill(tab == target ? PixelPalette.warn : PixelPalette.panelShade))
                .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func itemCell(_ item: DecorItem) -> some View {
        let decor = store.state.decor
        let equipped = decor.equipped(item.slot) == item
        let owned = decor.isOwned(item)
        let locked = store.state.progression.level < item.unlockLevel
        return VStack(spacing: 6) {
            preview(item.id, cropBottom: item.slot == .floor)
            Text(item.nameKey).font(PixelFont.body(10)).lineLimit(2).multilineTextAlignment(.center)
            Group {
                if equipped {
                    Text("decor.inUse").font(PixelFont.body(10)).foregroundStyle(PixelPalette.good)
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

    private func appearanceCell(_ appearance: CatAppearance) -> some View {
        let selected = store.state.cat.appearanceID == appearance.rawValue
        return VStack(spacing: 6) {
            preview(CatAppearance.textureName("idle_0", appearance: appearance.rawValue), cropBottom: false)
            Text(appearance.nameKey).font(PixelFont.body(10))
            Group {
                if selected {
                    Text("decor.inUse").font(PixelFont.body(10)).foregroundStyle(PixelPalette.good)
                } else {
                    Button("decor.use") { store.setAppearance(appearance.rawValue) }
                        .buttonStyle(PixelButtonStyle(fill: PixelPalette.xp))
                }
            }
            .frame(height: 34)
        }
        .padding(8)
        .background(PixelBorder().fill(selected ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
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

    private func buy(_ item: DecorItem) {
        switch store.buyDecor(item.id) {
        case .insufficientCoins: notice = "notice.noCoins"
        case .locked: notice = "decor.locked \(item.unlockLevel)"
        default: notice = nil
        }
    }
}
