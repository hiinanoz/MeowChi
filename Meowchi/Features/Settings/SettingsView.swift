import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = store.state.settings
        SheetScaffold(title: "settings.title", onClose: { dismiss() }) {
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
            Text("settings.silentHint").font(PixelFont.body(10)).foregroundStyle(PixelPalette.accentShade)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(PixelPalette.accentShade)
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

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8, content: content)
            .padding(12)
            .background(PixelBorder().fill(PixelPalette.panelShade))
    }
}
