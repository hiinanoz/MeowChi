import SpriteKit
import SwiftUI

/// Main screen: HUD on top, the SpriteKit room in the middle, the action bar at the bottom.
@MainActor
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = RoomScene(size: CGSize(width: 390, height: 500))
    @State private var notice: LocalizedStringKey?

    @State private var panel: CarePanel?
    @State private var isBrushing = false

    var body: some View {
        VStack(spacing: 8) {
            HUDView()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay(alignment: .top) { noticeBanner }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if isBrushing { brushBanner } else { TutorialBanner() }
                        panelView.padding(8)
                    }
                    .animation(.easeOut(duration: 0.2), value: panel)
                }
            ActionBar(panel: $panel, onToggleSleep: toggleSleep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .onAppear {
            scene.store = store
        }
        .onChange(of: store.state.cat.isSleeping) { _, sleeping in
            if sleeping { setBrushing(false) }
            scene.setSleeping(sleeping, animated: true)
        }
        .onChange(of: store.isLitterDirty) { _, _ in scene.refreshLitter() }
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

    @ViewBuilder private var panelView: some View {
        switch panel {
        case .food:
            FoodPanel { food in run(store.feed(food.id), noReward: nil) { scene.playFeeding() } }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .clean:
            CleanPanel(
                onBath: { run(store.bathe(), noReward: "notice.alreadyClean") { scene.playBath() } },
                onBrush: { panel = nil; setBrushing(true) },
                onLitter: { run(store.cleanLitter(), noReward: "notice.litterClean") { scene.refreshLitter(sparkle: true) } }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .health:
            HealthPanel { run(store.visitVet(), noReward: "notice.healthy") { scene.playVet() } }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case nil:
            EmptyView()
        }
    }

    private var brushBanner: some View {
        HStack(spacing: 10) {
            PixelIcon(name: "icon_brush", size: 18)
            Text("brush.hint \(store.state.cat.name)")
                .font(PixelFont.body(12))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("brush.done") { setBrushing(false) }
                .font(PixelFont.body(12))
                .foregroundStyle(PixelPalette.accentShade)
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .pixelPanel()
        .padding(8)
    }

    /// Runs an action result: success closes the panel and plays the scene part; anything else shows why.
    private func run(_ result: ActionResult, noReward: LocalizedStringKey?, onSuccess: () -> Void) {
        switch result {
        case .ok:
            panel = nil
            onSuccess()
        case .busy: show("notice.busy")
        case .sleeping: show("notice.sleeping")
        case .outOfStock: show("notice.noFood")
        case .tooSoon: show("notice.tooSoon")
        case .noReward: if let noReward { show(noReward) }
        case .unknownItem: break
        }
    }

    private func setBrushing(_ on: Bool) {
        isBrushing = on
        scene.isBrushing = on
    }

    private func toggleSleep() {
        panel = nil
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
    @Binding var panel: CarePanel?
    let onToggleSleep: @MainActor () -> Void

    var body: some View {
        let sleeping = store.state.cat.isSleeping
        HStack(spacing: 8) {
            ActionButton(icon: "icon_hunger", title: "action.feed", selected: panel == .food) { toggle(.food) }
                .disabled(sleeping)
            ActionButton(icon: "icon_clean", title: "action.clean", selected: panel == .clean) { toggle(.clean) }
            ActionButton(icon: "icon_energy", title: sleeping ? "action.wake" : "action.sleep", selected: false,
                         fill: Color(red: 0.62, green: 0.74, blue: 0.98)) { onToggleSleep() }
            ActionButton(icon: "icon_health", title: "action.health", selected: panel == .health) { toggle(.health) }
        }
        .padding(.bottom, 3)
    }

    private func toggle(_ target: CarePanel) {
        withAnimation(.easeOut(duration: 0.2)) { panel = panel == target ? nil : target }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let selected: Bool
    var fill = PixelPalette.accent
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: { action() }) {
            VStack(spacing: 3) {
                PixelIcon(name: icon, size: 20)
                Text(title).font(PixelFont.body(10)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PixelButtonStyle(fill: selected ? PixelPalette.warn : fill))
    }
}
