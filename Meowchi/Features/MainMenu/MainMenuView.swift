import SwiftUI

/// Title screen shown on launch (after onboarding): go home or open settings.
@MainActor
struct MainMenuView: View {
    @Environment(GameStore.self) private var store
    let onGoHome: @MainActor () -> Void
    @State private var showSettings = false
    @State private var showCollection = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            VStack(spacing: 6) {
                Text(verbatim: "Meowchi")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelPalette.accent)
                    .shadow(color: PixelPalette.ink, radius: 0, x: 3, y: 3)
                Text("menu.subtitle").font(PixelFont.body(13)).foregroundStyle(PixelPalette.panel)
            }
            CatPreview(look: store.state.cat.look, size: 192, animation: .happy)
            Text(verbatim: store.state.cat.name).font(PixelFont.body(16)).foregroundStyle(PixelPalette.panel)
            VStack(spacing: 12) {
                menuButton("menu.continue", icon: "icon_happiness", fill: PixelPalette.good) { onGoHome() }
                menuButton("collection.title", icon: "icon_collection", fill: PixelPalette.panelShade) { showCollection = true }
                menuButton("settings.title", icon: "icon_settings", fill: PixelPalette.panelShade) { showSettings = true }
            }
            .padding(.horizontal, 40)
            Spacer(minLength: 20)
            Text(verbatim: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(PixelFont.body(10)).foregroundStyle(PixelPalette.barTrack)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelPalette.frame.ignoresSafeArea())
        .sheet(isPresented: $showSettings) { SettingsView().environment(store) }
        .sheet(isPresented: $showCollection) { CollectionView().environment(store) }
        .onAppear { AudioManager.shared.context = .menu }
    }

    private func menuButton(_ title: LocalizedStringKey, icon: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button {
            AudioManager.shared.play(.tap)
            action()
        } label: {
            HStack(spacing: 10) {
                PixelIcon(name: icon, size: 20)
                Text(title).font(PixelFont.body(16))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PixelButtonStyle(fill: fill))
    }
}
