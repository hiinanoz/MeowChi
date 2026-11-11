import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var previousContext = AudioManager.MusicContext.home
    @State private var name = ""
    @State private var showLook = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        let settings = store.state.settings
        SheetScaffold(title: "settings.title", onClose: { dismiss() }) {
            sectionTitle("settings.cat")
            section {
                HStack(spacing: 10) {
                    CatPreview(look: store.state.cat.look, size: 64).frame(width: 52, height: 48, alignment: .top).clipped()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.name").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                        TextField("onboarding.name.placeholder", text: $name)
                            .font(PixelFont.body(14))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { store.rename(name); name = store.state.cat.name }
                            .padding(6)
                            .background(PixelBorder().fill(PixelPalette.panel))
                    }
                }
                Button { showLook = true } label: {
                    HStack(spacing: 6) { PixelIcon(name: "icon_decor", size: 16); Text("settings.changeLook") }
                }
                .buttonStyle(PixelButtonStyle(fill: PixelPalette.xp))
            }
            sectionTitle("settings.audio")
            section {
                Toggle(isOn: binding(\.musicEnabled)) { Text("settings.music").font(PixelFont.body(13)) }
                volume(binding(\.musicVolume), enabled: settings.musicEnabled)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(MusicTrack.allCases) { track in
                        let selected = settings.musicTrack == track.rawValue
                        Button { binding(\.musicTrack).wrappedValue = track.rawValue } label: {
                            Text(track.nameKey).font(PixelFont.body(11)).lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(PixelBorder().fill(selected ? PixelPalette.warn : PixelPalette.panel))
                                .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .disabled(!settings.musicEnabled)
                .opacity(settings.musicEnabled ? 1 : 0.5)
            }
            section {
                Toggle(isOn: binding(\.soundEnabled)) { Text("settings.sound").font(PixelFont.body(13)) }
                volume(binding(\.sfxVolume), enabled: settings.soundEnabled)
            }
            sectionTitle("settings.game")
            section {
                Toggle(isOn: binding(\.openHomeOnLaunch)) { Text("settings.openHome").font(PixelFont.body(13)) }
                Toggle(isOn: Binding(get: { store.state.settings.remindersEnabled }, set: { setReminders($0) })) {
                    Text("settings.reminders").font(PixelFont.body(13))
                }
                Text("reminders.explain").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("settings.silentHint").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                .frame(maxWidth: .infinity, alignment: .leading)
            sectionTitle("settings.about")
            section {
                linkRow("settings.support", "https://hii.othinks.com/meowchi/support")
                linkRow("settings.privacy", "https://hii.othinks.com/meowchi/privacy")
                linkRow("settings.contact", "mailto:mobile@othinks.com")
                Text("settings.version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $showLook) { DecorView(startAtCat: true).environment(store) }
        .tint(PixelPalette.accentShade)
        .onAppear {
            name = store.state.cat.name
            // Let the player hear their pick while choosing, then restore the screen's music.
            previousContext = AudioManager.shared.context
            AudioManager.shared.context = .home
        }
        .onDisappear { AudioManager.shared.context = previousContext }
    }

    /// Turning reminders on asks for permission; if it's refused the switch stays off.
    private func setReminders(_ on: Bool) {
        Task {
            var settings = store.state.settings
            settings.remindersAsked = true
            settings.remindersEnabled = on ? await Reminders.requestPermission() : false
            store.updateSettings(settings)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<GameSettings, T>) -> Binding<T> {
        Binding(get: { store.state.settings[keyPath: keyPath] },
                set: { value in
                    var settings = store.state.settings
                    settings[keyPath: keyPath] = value
                    store.updateSettings(settings)
                })
    }

    private func volume(_ value: Binding<Double>, enabled: Bool) -> some View {
        HStack(spacing: 8) {
            Text("settings.volume").font(PixelFont.body(11))
            Slider(value: value, in: 0...1)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title).font(PixelFont.body(12)).foregroundStyle(PixelPalette.accentShade)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
    }

    private func linkRow(_ title: LocalizedStringKey, _ url: String) -> some View {
        Button { if let link = URL(string: url) { openURL(link) } } label: {
            HStack {
                Text(title).font(PixelFont.body(13))
                Spacer()
                PixelIcon(name: "icon_back", size: 12).rotationEffect(.degrees(180))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PixelPressStyle())
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8, content: content)
            .padding(12)
            .background(PixelBorder().fill(PixelPalette.panelShade))
    }
}
