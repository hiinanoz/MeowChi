import SwiftUI

/// Room decoration: pick a slot, then buy or equip an item. The "cat" tab changes the coat color.
@MainActor
struct DecorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .slot(.bed)
    @State private var notice: LocalizedStringKey?
    @State private var debugTabApplied = false

    enum Tab: Hashable {
        case cat
        case slot(DecorSlot)
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: "decor.title", onClose: { dismiss() }) {
            #if DEBUG
            let _ = debugSelectTab()
            #endif
            HStack {
                PixelIcon(name: "icon_coin", size: 18)
                Text(store.state.coins, format: .number).font(PixelFont.body(15)).monospacedDigit()
                Spacer()
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.badText) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(.cat, "decor.slot.cat")
                    ForEach(DecorSlot.allCases) { chip(.slot($0), $0.titleKey) }
                }
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
                    Button {
                        switch store.buyAccessory(item) {
                        case .ok: AudioManager.shared.play(.buy); notice = nil
                        case .insufficientCoins: notice = "notice.noCoins"
                        default: break
                        }
                    } label: {
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

    #if DEBUG
    /// QA helper: `-decorTab cat` opens the cat tab.
    private func debugSelectTab() {
        guard CommandLine.arguments.contains("-decorTab"), tab != .cat, !debugTabApplied else { return }
        DispatchQueue.main.async { tab = .cat; debugTabApplied = true }
    }
    #endif

    private func buy(_ item: DecorItem) {
        switch store.buyDecor(item.id) {
        case .ok: AudioManager.shared.play(.buy); notice = nil
        case .insufficientCoins: notice = "notice.noCoins"
        case .locked: notice = "decor.locked \(item.unlockLevel)"
        default: notice = nil
        }
    }
}
