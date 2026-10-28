import SpriteKit
import SwiftUI

/// Garden walk shell: starts the walk on appear, shows finds as they're dug up, summary on the way home.
@MainActor
struct GardenView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = GardenScene(size: CGSize(width: 390, height: 600))
    @State private var phase = Phase.starting
    @State private var started = false

    private enum Phase: Equatable {
        case starting, walking, blocked(LocalizedStringKey), summary(coins: Int, items: Int)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("game.garden.title").font(PixelFont.body(15))
                Spacer()
                if let walk = store.activeWalk {
                    Label { Text(verbatim: "\(walk.finds.filter(\.collected).count)/\(walk.finds.count)") }
                        icon: { PixelIcon(name: "fx_sparkle", size: 14) }
                }
                Button { goHome() } label: { Text(phase == .walking ? "garden.goHome" : "common.close") }
                    .font(PixelFont.body(12))
                    .foregroundStyle(PixelPalette.accentShade)
            }
            .font(PixelFont.body(13))
            .padding(10)
            .pixelPanel()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay(alignment: .bottom) { overlay }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .foregroundStyle(PixelPalette.ink)
        .onAppear(perform: begin)
        .onChange(of: scenePhase) { _, newPhase in
            // Finds are paid when collected, so ending the walk here loses nothing.
            if newPhase == .background, phase == .walking { store.finishWalk() }
        }
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .starting:
            EmptyView()
        case .walking:
            Text("game.garden.hint")
                .font(PixelFont.body(11)).multilineTextAlignment(.center)
                .padding(10).pixelPanel().padding(10)
        case .blocked(let reason):
            card {
                Text(reason).font(PixelFont.body(13)).multilineTextAlignment(.center)
                Button("common.close") { dismiss() }.buttonStyle(PixelButtonStyle())
            }
        case .summary(let coins, let items):
            card {
                Text("garden.summary").font(PixelFont.body(17))
                HStack(spacing: 16) {
                    Label { Text(verbatim: "+\(coins)") } icon: { PixelIcon(name: "icon_coin", size: 16) }
                    Label { Text(verbatim: "+\(items)") } icon: { PixelIcon(name: "icon_food_treat", size: 16) }
                    Label { Text(verbatim: "+\(store.balance.walkXP) XP") } icon: { PixelIcon(name: "icon_xp", size: 16) }
                }
                .font(PixelFont.body(14))
                Button("common.close") { dismiss() }.buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12, content: content).padding(16).pixelPanel().padding(24)
    }

    private func begin() {
        guard !started else { return }
        started = true
        scene.store = store
        scene.look = store.state.cat.look
        switch store.startWalk() {
        case .ok:
            if let walk = store.activeWalk { scene.showFinds(walk) }
            phase = .walking
        case .tooTired: phase = .blocked("notice.tooTired")
        case .sleeping: phase = .blocked("notice.sleeping")
        default: phase = .blocked("notice.busy")
        }
    }

    private func goHome() {
        guard phase == .walking else { return dismiss() }
        if let walk = store.finishWalk() {
            phase = .summary(coins: walk.coinsFound, items: walk.itemsFound)
        } else {
            dismiss()
        }
    }
}
