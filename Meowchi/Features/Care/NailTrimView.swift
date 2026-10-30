import SwiftUI

/// Close-up paw: tap each claw to trim it. The reward is granted once, when the last claw is done.
@MainActor
struct NailTrimView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var trimmed: Set<Int> = []
    @State private var finished = false

    /// Claw tips in paw-image coordinates (paw art is 96x80 px, shown at 3x).
    private let claws: [CGPoint] = [CGPoint(x: 20, y: 6), CGPoint(x: 38, y: -4), CGPoint(x: 58, y: -4), CGPoint(x: 76, y: 6)]
    private let scale: CGFloat = 3

    var body: some View {
        SheetScaffold(title: "nails.title", onClose: { dismiss() }) {
            Text(finished ? "nails.done" : "nails.hint")
                .font(PixelFont.body(12)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            ZStack(alignment: .topLeading) {
                PixelIcon(name: "paw_big", size: 96 * scale)
                    .frame(width: 96 * scale, height: 80 * scale)
                ForEach(claws.indices, id: \.self) { i in
                    if !trimmed.contains(i) {
                        Button { snip(i) } label: {
                            Image("claw").interpolation(.none).resizable()
                                .frame(width: 10 * scale, height: 14 * scale)
                                .padding(10) // bigger touch target
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: claws[i].x * scale, y: claws[i].y * scale + 10)
                        .accessibilityLabel(Text("nails.claw \(i + 1)"))
                    }
                }
            }
            .frame(width: 96 * scale, height: 80 * scale)
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
            if finished {
                Button("common.done") { dismiss() }.buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
            }
        }
        .firstTimeTip("nails", "tip.nails")
    }

    private func snip(_ index: Int) {
        trimmed.insert(index)
        AudioManager.shared.play(.tap)
        guard trimmed.count == claws.count else { return }
        if store.trimNails() == .ok { AudioManager.shared.play(.find) }
        finished = true
    }
}
