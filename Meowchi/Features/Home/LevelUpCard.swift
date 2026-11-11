import SwiftUI

/// Full-room celebration when the cat levels up: confetti, the new level, the coin reward and
/// what just unlocked (decorations and walk places).
struct LevelUpCard: View {
    let level: Int
    let onClose: () -> Void
    @Environment(GameStore.self) private var store

    private var unlockedDecor: [DecorItem] {
        DecorCatalog.items.filter { $0.unlockLevel == level && $0.tint == nil && !$0.isEmpty }
    }

    private var unlockedPlaces: [WalkLocation] {
        WalkLocation.allCases.filter { store.balance.walkLocations[$0]?.unlockLevel == level }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onClose)
            if !Motion.reduced { Confetti().ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 12) {
                Text("levelUp.title \(level)").font(PixelFont.body(22)).foregroundStyle(PixelPalette.accentShade)
                CatPreview(look: store.state.cat.look, size: 96, animation: .happy)
                Label { Text(verbatim: "+\(store.balance.levelUpCoins)") } icon: { PixelIcon(name: "icon_coin", size: 18) }
                    .font(PixelFont.body(16))
                if !unlockedDecor.isEmpty || !unlockedPlaces.isEmpty {
                    Text("levelUp.unlocked").font(PixelFont.body(12))
                    HStack(spacing: 10) {
                        ForEach(unlockedDecor.prefix(4)) { item in
                            VStack(spacing: 2) {
                                PixelIcon(name: item.id, size: 34)
                                Text(item.nameKey).font(PixelFont.body(9)).lineLimit(2).multilineTextAlignment(.center)
                            }
                            .frame(width: 64)
                        }
                        ForEach(unlockedPlaces) { place in
                            VStack(spacing: 2) {
                                PixelIcon(name: "fx_sparkle", size: 34)
                                Text(place.titleKey).font(PixelFont.body(9)).lineLimit(2)
                            }
                            .frame(width: 64)
                        }
                    }
                }
                Button("levelUp.ok", action: onClose).buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            }
            .foregroundStyle(PixelPalette.ink)
            .padding(18)
            .pixelPanel()
            .padding(28)
            .transition(Motion.reduced ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Falling pixel confetti, drawn with a TimelineView so it costs nothing when hidden.
struct Confetti: View {
    private struct Piece {
        let x: CGFloat, speed: CGFloat, delay: Double, size: CGFloat, color: Color, sway: CGFloat
    }

    @State private var pieces: [Piece] = (0..<40).map { _ in
        Piece(x: .random(in: 0...1), speed: .random(in: 160...300), delay: .random(in: 0...0.8), size: [4, 6, 8].randomElement()!,
              color: [PixelPalette.accent, PixelPalette.good, PixelPalette.warn, PixelPalette.xp, PixelPalette.bad].randomElement()!,
              sway: .random(in: 8...24))
    }
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces where t > piece.delay {
                    let elapsed = t - piece.delay
                    let y = -10 + CGFloat(elapsed) * piece.speed
                    guard y < size.height + 10 else { continue }
                    let x = piece.x * size.width + sin(CGFloat(elapsed) * 3) * piece.sway
                    context.fill(Path(CGRect(x: x.rounded(), y: y.rounded(), width: piece.size, height: piece.size)),
                                 with: .color(piece.color))
                }
            }
        }
    }
}
