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
                tile(0, .shop, "shop.title", "icon_shop", color: Color(red: 1.0, green: 0.86, blue: 0.62),
                     status: Text("hud.coins \(store.state.coins)"))
                tile(1, .decor, "decor.title", "icon_decor", color: Color(red: 0.80, green: 0.90, blue: 0.74),
                     status: Text("decor.owned \(store.state.decor.owned.count)"))
                tile(2, .collection, "collection.title", "icon_collection", color: Color(red: 0.86, green: 0.82, blue: 0.96),
                     status: Text(verbatim: "★ \(store.state.badges.count)/\(Badge.all.count)"))
                tile(3, .tasks, "tasks.title", "icon_tasks", color: Color(red: 0.78, green: 0.88, blue: 0.98),
                     status: Text(verbatim: "\(store.state.daily.tasks.filter(\.claimed).count)/\(store.state.daily.tasks.count)"),
                     badge: store.state.daily.tasks.contains { !$0.claimed && $0.progress >= (store.definition(for: $0)?.target ?? .max) } ? "!" : nil)
                tile(4, .checkIn, "login.title", "icon_coin", color: Color(red: 1.0, green: 0.80, blue: 0.80),
                     status: store.canClaimLogin ? Text("login.ready") : Text("login.day \(store.state.login.days)"),
                     badge: store.canClaimLogin ? "!" : nil)
                tile(5, .settings, "settings.title", "icon_settings", color: PixelPalette.panelShade, status: nil)
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

    @State private var appeared = false

    private func tile(_ index: Int, _ destination: Destination, _ title: LocalizedStringKey, _ icon: String, color: Color,
                      status: Text?, badge: String? = nil) -> some View {
        Button { select(destination) } label: {
            VStack(spacing: 4) {
                PixelIcon(name: icon, size: 30)
                Text(title).font(PixelFont.body(12)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                if let status {
                    status.font(PixelFont.body(9)).foregroundStyle(PixelPalette.accentShade).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(PixelBorder().fill(color))
            .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 2))
            .background(PixelBorder().fill(PixelPalette.ink).offset(y: 3))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(verbatim: badge).font(PixelFont.body(10)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(PixelPalette.warn)).padding(6)
                }
            }
        }
        .buttonStyle(PixelPressStyle())
        // Tiles drop in one after another when the menu opens.
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || Motion.reduced ? 0 : 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.75).delay(Double(index) * 0.04), value: appeared)
        .onAppear { appeared = true }
    }

    private func select(_ destination: Destination) {
        AudioManager.shared.play(.tap)
        dismiss()
        // Open the next sheet after this one has gone, so the presentations don't collide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSelect(destination) }
    }
}
