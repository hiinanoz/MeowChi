import SwiftUI

/// A one-sentence tip shown the first time a feature opens; "Got it" hides it for good.
struct FirstTimeTip: ViewModifier {
    let id: String
    let text: LocalizedStringKey
    @Environment(GameStore.self) private var store

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if !store.hasSeenTip(id) {
                HStack(spacing: 10) {
                    PixelIcon(name: "fx_sparkle", size: 16)
                    Text(text).font(PixelFont.body(11)).frame(maxWidth: .infinity, alignment: .leading)
                    Button("tip.gotIt") { withAnimation { store.markTipSeen(id) } }
                        .font(PixelFont.body(11))
                        .foregroundStyle(PixelPalette.accentShade)
                        .hitTarget(20)
                }
                .foregroundStyle(PixelPalette.ink)
                .padding(12)
                .pixelPanel(PixelPalette.warn.opacity(0.95))
                .padding(12)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

extension View {
    func firstTimeTip(_ id: String, _ text: LocalizedStringKey) -> some View {
        modifier(FirstTimeTip(id: id, text: text))
    }
}
