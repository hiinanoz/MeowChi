import SwiftUI

/// Title screen shown on launch (after onboarding): go home or open settings.
@MainActor
struct MainMenuView: View {
    @Environment(GameStore.self) private var store
    let onGoHome: @MainActor () -> Void
    @State private var showSettings = false
    @State private var showCollection = false
    @State private var hop = false
    @State private var logoUp = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            VStack(spacing: 6) {
                Image("ui_logo").interpolation(.none).resizable().scaledToFit()
                    .frame(width: 306)
                    .offset(y: logoUp ? -3 : 0)
                    .accessibilityLabel(Text(verbatim: "Meowchi"))
                Text("menu.subtitle").font(PixelFont.body(13)).foregroundStyle(PixelPalette.panel)
            }
            CatPreview(look: store.state.cat.look, size: 192, animation: .happy)
                .offset(y: hop ? -18 : 0)
                .contentShape(Rectangle())
                .onTapGesture { petOnMenu() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("a11y.pet"))
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
        .background(MenuSky().ignoresSafeArea())
        .sheet(isPresented: $showSettings) { SettingsView().environment(store) }
        .sheet(isPresented: $showCollection) { CollectionView().environment(store) }
        .onAppear {
            AudioManager.shared.context = .menu
            guard !Motion.reduced else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { logoUp = true }
        }
    }

    /// Tapping the cat on the title screen: a meow and a little hop.
    private func petOnMenu() {
        AudioManager.shared.play(.meow)
        guard !Motion.reduced else { return }
        withAnimation(.easeOut(duration: 0.15)) { hop = true }
        withAnimation(.easeIn(duration: 0.2).delay(0.15)) { hop = false }
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

/// Title-screen sky that follows the time of day, with drifting sparkles (stars at night).
private struct MenuSky: View {
    private struct Mote { let x: CGFloat, y: CGFloat, speed: CGFloat, size: CGFloat, phase: Double }

    @State private var motes: [Mote] = (0..<28).map { _ in
        Mote(x: .random(in: 0...1), y: .random(in: 0...1), speed: .random(in: 4...14), size: [2, 3, 4].randomElement()!,
             phase: .random(in: 0...6))
    }

    private var colors: (top: Color, bottom: Color, isNight: Bool) {
        switch Calendar.current.component(.hour, from: .now) {
        case 6..<10: (Color(red: 0.98, green: 0.72, blue: 0.62), Color(red: 0.55, green: 0.42, blue: 0.62), false)
        case 10..<17: (Color(red: 0.45, green: 0.66, blue: 0.92), Color(red: 0.32, green: 0.36, blue: 0.62), false)
        case 17..<20: (Color(red: 0.95, green: 0.55, blue: 0.40), Color(red: 0.36, green: 0.24, blue: 0.45), false)
        default: (Color(red: 0.12, green: 0.12, blue: 0.28), PixelPalette.frame, true)
        }
    }

    var body: some View {
        let sky = colors
        ZStack {
            LinearGradient(colors: [sky.top, sky.bottom], startPoint: .top, endPoint: .bottom)
            if !Motion.reduced {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        for mote in motes {
                            let y = (mote.y * size.height - CGFloat(t) * mote.speed).truncatingRemainder(dividingBy: size.height)
                            let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 1.5 + mote.phase))
                            let rect = CGRect(x: (mote.x * size.width).rounded(), y: (y < 0 ? y + size.height : y).rounded(),
                                              width: mote.size, height: mote.size)
                            context.fill(Path(rect), with: .color(.white.opacity(sky.isNight ? twinkle : twinkle * 0.5)))
                        }
                    }
                }
            }
        }
    }
}
