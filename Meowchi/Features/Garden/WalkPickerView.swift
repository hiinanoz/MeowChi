import SwiftUI

/// Choose where to walk. Locked places show their unlock level.
@MainActor
struct WalkPickerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: @MainActor (WalkLocation) -> Void

    var body: some View {
        SheetScaffold(title: "walk.title", onClose: { dismiss() }) {
            Text("game.energyCost \(Int(store.balance.walkEnergyCost))").font(PixelFont.body(11))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(WalkLocation.allCases) { location in
                let unlocked = store.isUnlocked(location)
                Button { onPick(location) } label: {
                    HStack(spacing: 10) {
                        Image(location.background).interpolation(.none).resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 96, height: 56, alignment: .center)
                            .clipped()
                            .overlay(PixelBorder(step: 2).stroke(PixelPalette.ink, lineWidth: 1.5))
                            .saturation(unlocked ? 1 : 0)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.titleKey).font(PixelFont.body(14))
                            if unlocked {
                                Text("walk.ready").font(PixelFont.body(10)).foregroundStyle(PixelPalette.goodText)
                            } else {
                                Text("decor.locked \(store.balance.walkLocations[location]?.unlockLevel ?? 1)")
                                    .font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(PixelBorder().fill(PixelPalette.panelShade))
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
            }
        }
    }
}
