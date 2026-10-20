import SpriteKit
import SwiftUI

/// Main screen: HUD on top, the SpriteKit room in the middle, the action bar at the bottom.
@MainActor
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = RoomScene(size: CGSize(width: 390, height: 500))
    @State private var notice: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 8) {
            HUDView()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay(alignment: .top) { noticeBanner }
            ActionBar(onFeed: feed, onToggleSleep: toggleSleep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .onAppear {
            scene.store = store
        }
        .onChange(of: store.state.cat.isSleeping) { _, sleeping in
            scene.setSleeping(sleeping, animated: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.tick() } else if phase == .background { store.save() }
        }
        .onChange(of: store.levelUpCount) { _, _ in show("notice.levelUp") }
        .task {
            // Foreground refresh. Offline time is handled by elapsed-time simulation, not timers.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                store.tick()
            }
        }
    }

    @ViewBuilder private var noticeBanner: some View {
        if let notice {
            Text(notice)
                .font(PixelFont.body(12))
                .foregroundStyle(PixelPalette.ink)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .pixelPanel()
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func feed() {
        guard let food = store.firstAvailableFood else { return show("notice.noFood") }
        switch store.feed(food.id) {
        case .ok: scene.playFeeding()
        case .busy: show("notice.busy")
        case .sleeping: show("notice.sleeping")
        case .outOfStock: show("notice.noFood")
        case .noReward, .unknownItem: break
        }
    }

    private func toggleSleep() {
        if store.setSleeping(!store.state.cat.isSleeping) == .busy { show("notice.busy") }
    }

    private func show(_ key: LocalizedStringKey) {
        withAnimation { notice = key }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { notice = nil }
        }
    }
}

private struct ActionBar: View {
    @Environment(GameStore.self) private var store
    let onFeed: @MainActor () -> Void
    let onToggleSleep: @MainActor () -> Void

    var body: some View {
        let sleeping = store.state.cat.isSleeping
        let foodCount = store.firstAvailableFood.map { store.quantity(of: $0.id) } ?? 0
        HStack(spacing: 10) {
            Button(action: { onFeed() }) {
                HStack(spacing: 6) {
                    PixelIcon(name: "icon_hunger", size: 18)
                    Text("action.feed")
                    Text(verbatim: "×\(foodCount)").font(PixelFont.body(10))
                }
            }
            .disabled(sleeping)
            Button(action: { onToggleSleep() }) {
                HStack(spacing: 6) {
                    PixelIcon(name: "icon_energy", size: 18)
                    Text(sleeping ? LocalizedStringKey("action.wake") : "action.sleep")
                }
            }
            .buttonStyle(PixelButtonStyle(fill: Color(red: 0.62, green: 0.74, blue: 0.98)))
        }
        .buttonStyle(PixelButtonStyle())
        .padding(.bottom, 3)
    }
}
