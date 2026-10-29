import SwiftUI

/// Daily check-in calendar: 7 stamps, today's reward claimable once per day.
@MainActor
struct LoginRewardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        let today = store.loginCycleIndex
        let claimable = store.canClaimLogin
        SheetScaffold(title: "login.title", onClose: { dismiss() }) {
            Text("login.days \(store.state.login.days)").font(PixelFont.body(12))
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(store.balance.loginRewards.indices, id: \.self) { i in
                    let reward = store.balance.loginRewards[i]
                    let done = i < today || (i == today && !claimable)
                    VStack(spacing: 4) {
                        Text("login.day \(i + 1)").font(PixelFont.body(10))
                        PixelIcon(name: reward.item.map { ItemCatalog.food($0)?.iconName ?? "icon_coin" } ?? "icon_coin", size: 22)
                        Text(verbatim: "+\(reward.coins)").font(PixelFont.body(11))
                        if done { Text("tasks.claimed").font(PixelFont.body(8)).foregroundStyle(PixelPalette.goodText) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(PixelBorder().fill(i == today ? PixelPalette.warn : PixelPalette.panelShade))
                    .opacity(done && i != today ? 0.6 : 1)
                }
            }
            if claimable {
                Button("tasks.claim") {
                    if store.claimLogin() != nil { AudioManager.shared.play(.coin) }
                }
                .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            } else {
                Text("login.comeBack").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
            }
        }
    }
}
