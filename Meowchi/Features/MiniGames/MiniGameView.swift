import SpriteKit
import SwiftUI

/// Generic mini-game shell: intro → timed round → results. The scene only reports points;
/// rewards are decided by `GameStore.finishMiniGame`.
@MainActor
struct MiniGameView: View {
    let kind: MiniGameKind
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = LaserChaseScene(size: CGSize(width: 390, height: 600))
    @State private var phase = Phase.intro
    @State private var score = 0
    @State private var remaining = 0
    @State private var notice: LocalizedStringKey?

    private enum Phase: Equatable {
        case intro, playing, results(MiniGameReward)
    }

    var body: some View {
        VStack(spacing: 8) {
            topBar
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay { overlay }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .foregroundStyle(PixelPalette.ink)
        .onAppear {
            scene.decor = store.state.decor
            scene.appearance = store.state.cat.appearanceID
            scene.onScore = { score = $0 }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Leaving the app forfeits the round; energy was paid at the start.
            if newPhase == .background, phase == .playing { quit() }
        }
        .task(id: phase) {
            guard phase == .playing else { return }
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled || phase != .playing { return }
                remaining -= 1
            }
            finish()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(kind.titleKey).font(PixelFont.body(15))
            Spacer()
            if phase == .playing {
                Label { Text(verbatim: "\(score)") } icon: { PixelIcon(name: "icon_happiness", size: 16) }
                Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)).monospacedDigit()
            }
            Button { quit() } label: { Text("common.close") }
                .font(PixelFont.body(12))
                .foregroundStyle(PixelPalette.accentShade)
        }
        .font(PixelFont.body(13))
        .padding(10)
        .pixelPanel()
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .intro:
            card {
                Text(kind.hintKey).font(PixelFont.body(13)).multilineTextAlignment(.center)
                Text("game.energyCost \(Int(kind.config(store.balance).energyCost))").font(PixelFont.body(11))
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.bad) }
                Button("game.start") { start() }.buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            }
        case .playing:
            EmptyView()
        case .results(let reward):
            card {
                Text("game.results").font(PixelFont.body(18))
                Text("game.points \(reward.points)").font(PixelFont.body(14))
                HStack(spacing: 16) {
                    Label { Text(verbatim: "+\(reward.coins)") } icon: { PixelIcon(name: "icon_coin", size: 16) }
                    Label { Text(verbatim: "+\(reward.xp) XP") } icon: { PixelIcon(name: "icon_xp", size: 16) }
                }
                .font(PixelFont.body(14))
                HStack(spacing: 10) {
                    Button("game.again") { start() }.buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    Button("common.close") { dismiss() }.buttonStyle(PixelButtonStyle())
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12, content: content)
            .padding(16)
            .pixelPanel()
            .padding(24)
    }

    private func start() {
        switch store.startMiniGame(kind) {
        case .ok:
            score = 0
            remaining = Int(kind.config(store.balance).durationSeconds)
            scene.reset()
            scene.isRunning = true
            phase = .playing
        case .tooTired:
            notice = "notice.tooTired"
            phase = .intro
        case .sleeping:
            notice = "notice.sleeping"
            phase = .intro
        default:
            notice = "notice.busy"
            phase = .intro
        }
    }

    private func finish() {
        scene.isRunning = false
        if let reward = store.finishMiniGame(points: score) { phase = .results(reward) } else { phase = .intro }
    }

    private func quit() {
        if phase == .playing {
            scene.isRunning = false
            store.cancelMiniGame()
        }
        dismiss()
    }
}
