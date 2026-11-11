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
    @State private var scene: MiniGameScene
    @State private var phase = Phase.intro
    @State private var score = 0
    @State private var remaining = 0
    @State private var notice: LocalizedStringKey?
    @State private var confirmLeave = false

    init(kind: MiniGameKind) {
        self.kind = kind
        let size = CGSize(width: 390, height: 600)
        let scene: MiniGameScene = switch kind {
        case .laserChase: LaserChaseScene(size: size)
        case .yarnBall: YarnBallScene(size: size)
        case .toyMouse: ToyMouseScene(size: size)
        }
        _scene = State(initialValue: scene)
    }

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
            scene.look = store.state.cat.look
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
        PixelHeader(title: kind.titleKey, onBack: { phase == .playing ? (confirmLeave = true) : quit() }) {
            if phase == .playing {
                HStack(spacing: 8) {
                    Label { Text(verbatim: "\(score)") } icon: { PixelIcon(name: "icon_happiness", size: 14) }
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)).monospacedDigit()
                }
                .font(PixelFont.body(12))
            }
        }
        .padding(10)
        .pixelPanel()
        .alert("game.leave.title", isPresented: $confirmLeave) {
            Button("game.leave.confirm", role: .destructive) { quit() }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("game.leave.message")
        }
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .intro:
            card {
                Text(kind.hintKey).font(PixelFont.body(13)).multilineTextAlignment(.center)
                if let best = store.state.bestScores[kind.rawValue], best > 0 {
                    Text("game.best \(best)").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
                }
                Text("game.energyCost \(Int(kind.config(store.balance).energyCost))").font(PixelFont.body(11))
                if let notice { Text(notice).font(PixelFont.body(11)).foregroundStyle(PixelPalette.badText) }
                Button("game.start") { start() }.buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            }
        case .playing:
            EmptyView()
        case .results(let reward):
            card {
                Text("game.results").font(PixelFont.body(18))
                StarRow(stars: reward.stars)
                Text("game.points \(reward.points)").font(PixelFont.body(14))
                if reward.isNewBest {
                    Text("game.newBest").font(PixelFont.body(13)).foregroundStyle(PixelPalette.goodText)
                } else {
                    Text("game.best \(reward.best)").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
                }
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
        if let reward = store.finishMiniGame(points: score) {
            AudioManager.shared.play(.coin)
            phase = .results(reward)
        } else {
            phase = .intro
        }
    }

    private func quit() {
        if phase == .playing {
            scene.isRunning = false
            store.cancelMiniGame()
        }
        dismiss()
    }
}

/// 1-3 stars that pop in one after another.
private struct StarRow: View {
    let stars: Int
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Text(verbatim: "★")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(index < shown ? PixelPalette.warn : PixelPalette.barTrack)
                    .shadow(color: PixelPalette.ink, radius: 0, x: 2, y: 2)
                    .scaleEffect(index < shown ? 1 : 0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(stars)/3 ★"))
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .task {
            for step in 0..<stars {
                try? await Task.sleep(for: .seconds(Motion.reduced ? 0 : 0.25))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shown = step + 1 }
            }
        }
    }
}
