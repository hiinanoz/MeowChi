import SwiftUI

/// One place for everything that isn't direct cat care (HIG: group secondary destinations).
@MainActor
struct GameMenuView: View {
    enum Destination: Hashable { case shop, decor, collection, tasks, checkIn, settings, mainMenu }

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onSelect: @MainActor (Destination) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        SheetScaffold(title: "menu.title", onClose: { dismiss() }) {
            LazyVGrid(columns: columns, spacing: 10) {
                tile(.shop, "shop.title", "icon_shop")
                tile(.decor, "decor.title", "icon_decor")
                tile(.collection, "collection.title", "icon_collection", badge: "\(store.state.badges.count)/\(Badge.all.count)")
                tile(.tasks, "tasks.title", "icon_tasks", badge: "\(store.state.daily.tasks.filter(\.claimed).count)/\(store.state.daily.tasks.count)")
                tile(.checkIn, "login.title", "icon_coin", badge: store.canClaimLogin ? "!" : nil)
                tile(.settings, "settings.title", "icon_settings")
            }
            Button { select(.mainMenu) } label: {
                HStack(spacing: 8) {
                    PixelIcon(name: "icon_menu", size: 16)
                    Text("menu.mainMenu")
                }
            }
            .buttonStyle(PixelButtonStyle(fill: PixelPalette.panelShade))
            .padding(.top, 4)
        }
    }

    private func tile(_ destination: Destination, _ title: LocalizedStringKey, _ icon: String, badge: String? = nil) -> some View {
        Button { select(destination) } label: {
            VStack(spacing: 6) {
                PixelIcon(name: icon, size: 30)
                Text(title).font(PixelFont.body(12)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(PixelBorder().fill(PixelPalette.panelShade))
            .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(verbatim: badge).font(PixelFont.body(10)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(PixelPalette.warn)).padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func select(_ destination: Destination) {
        AudioManager.shared.play(.tap)
        dismiss()
        // Open the next sheet after this one has gone, so the presentations don't collide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSelect(destination) }
    }
}
