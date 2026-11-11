import SwiftUI

/// The cat's profile: who they are, what they like, their numbers and diary. Shareable as an image.
@MainActor
struct CatCardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = store.state
        SheetScaffold(title: "card.title", onClose: { dismiss() }, accent: Color(red: 0.92, green: 0.45, blue: 0.55)) {
            VStack(spacing: 6) {
                CatPreview(look: state.cat.look, size: 128, animation: .happy)
                Text(verbatim: state.cat.name).font(PixelFont.body(20))
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(store.stage.nameKey))
                    Text(verbatim: "·")
                    Text(LocalizedStringKey("personality." + state.cat.personality.rawValue))
                }
                .font(PixelFont.body(12)).foregroundStyle(PixelPalette.accentShade)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(PixelBorder().fill(PixelPalette.panelShade))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                fact("card.days", Text(verbatim: "\(state.login.days)"))
                fact("card.level", Text(verbatim: "\(state.progression.level)"))
                fact("card.favorite", store.favoriteFood.map { Text($0.nameKey) } ?? Text("card.none"))
                fact("card.pets", Text(verbatim: "\(state.lifetime[TaskEvent.petted.rawValue] ?? 0)"))
                fact("card.meals", Text(verbatim: "\(state.lifetime[TaskEvent.fed.rawValue] ?? 0)"))
                fact("card.walks", Text(verbatim: "\(state.lifetime[TaskEvent.walked.rawValue] ?? 0)"))
                fact("card.games", Text(verbatim: "\(state.lifetime[TaskEvent.played.rawValue] ?? 0)"))
                fact("card.photos", Text(verbatim: "\(state.lifetime["photos"] ?? 0)"))
            }

            if let image = shareImage() {
                ShareLink(item: image, preview: SharePreview(Text(verbatim: state.cat.name), image: image)) {
                    HStack(spacing: 6) { PixelIcon(name: "icon_camera", size: 16); Text("card.share") }
                }
                .buttonStyle(PixelButtonStyle(fill: PixelPalette.xp))
            }

            Text("card.diary").font(PixelFont.body(13)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            if state.diary.isEmpty {
                Image("ui_empty_cat").interpolation(.none).resizable().scaledToFit().frame(width: 96).accessibilityHidden(true)
                Text("card.diaryEmpty").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(state.diary) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.date, format: .dateTime.day().month(.abbreviated)).font(PixelFont.body(10)).monospacedDigit()
                        .foregroundStyle(PixelPalette.accentShade).frame(width: 52, alignment: .leading)
                    Text(entry.titleKey).font(PixelFont.body(12))
                    if let detail = entry.detail { Text(LocalizedStringKey(detail)).font(PixelFont.body(11)) }
                    if let number = entry.number { Text(verbatim: "\(number)").font(PixelFont.body(11)).monospacedDigit() }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func fact(_ title: LocalizedStringKey, _ value: Text) -> some View {
        VStack(spacing: 2) {
            Text(title).font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade).lineLimit(1).minimumScaleFactor(0.7)
            value.font(PixelFont.body(14)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(8)
        .background(PixelBorder().fill(PixelPalette.panelShade))
    }

    /// A small square card (cat, name, stage, days) rendered to an image for sharing.
    private func shareImage() -> Image? {
        let state = store.state
        guard let cat = CatImageRenderer.render(state.cat.look, scale: 4) else { return nil }
        let card = VStack(spacing: 8) {
            Image(uiImage: cat).interpolation(.none).resizable().frame(width: 192, height: 192)
            Text(verbatim: state.cat.name).font(.system(size: 28, weight: .heavy, design: .monospaced))
            Text(LocalizedStringKey(store.stage.nameKey)).font(.system(size: 16, weight: .bold, design: .monospaced))
            Text(verbatim: "Meowchi").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(PixelPalette.accentShade)
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(24)
        .frame(width: 320, height: 360)
        .background(PixelPalette.panel)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
