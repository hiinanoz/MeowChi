import SwiftUI

/// First-launch flow: welcome → meet & name the kitten. Feeding and petting are then taught
/// in the room itself via `TutorialBanner`, so the cat is playable right away.
@MainActor
struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @State private var step = Step.welcome
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private enum Step { case welcome, name }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            PixelIcon(name: step == .welcome ? "cat_happy_0" : "cat_idle_0", size: 192)
            Group {
                switch step {
                case .welcome: welcome
                case .name: naming
                }
            }
            .padding(20)
            .pixelPanel()
            Spacer()
        }
        .padding(.horizontal, 24)
        .foregroundStyle(PixelPalette.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelPalette.frame.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Text("onboarding.welcome.title").font(PixelFont.body(20))
            Text("onboarding.welcome.body")
                .font(PixelFont.body(13))
                .multilineTextAlignment(.center)
            Button("onboarding.welcome.button") {
                step = .name
                nameFocused = true
            }
            .buttonStyle(PixelButtonStyle())
        }
    }

    private var naming: some View {
        let valid = CatState.sanitizedName(name, maxLength: store.balance.maxNameLength) != nil
        return VStack(spacing: 14) {
            Text("onboarding.name.title")
                .font(PixelFont.body(16))
                .multilineTextAlignment(.center)
            TextField("onboarding.name.placeholder", text: $name)
                .font(PixelFont.body(16))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(10)
                .pixelPanel(PixelPalette.panelShade)
                .onChange(of: name) { _, new in
                    if new.count > store.balance.maxNameLength { name = String(new.prefix(store.balance.maxNameLength)) }
                }
                .onSubmit { if valid { store.completeOnboarding(name: name) } }
            Button("onboarding.name.button") { store.completeOnboarding(name: name) }
                .buttonStyle(PixelButtonStyle())
                .disabled(!valid)
        }
    }
}

/// Short, skippable in-room hints right after onboarding.
@MainActor
struct TutorialBanner: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let step = store.tutorialStep {
            HStack(spacing: 10) {
                Group {
                    switch step {
                    case .feed: Text("tutorial.feed \(store.state.cat.name)")
                    case .pet: Text("tutorial.pet \(store.state.cat.name)")
                    case .done: Text("tutorial.done")
                    }
                }
                .font(PixelFont.body(12))
                .frame(maxWidth: .infinity, alignment: .leading)
                if step != .done {
                    Button("common.skip") { store.tutorialStep = nil }
                        .font(PixelFont.body(11))
                        .foregroundStyle(PixelPalette.accentShade)
                }
            }
            .foregroundStyle(PixelPalette.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .pixelPanel()
            .padding(8)
            .task(id: step) {
                guard step == .done else { return }
                try? await Task.sleep(for: .seconds(3))
                store.tutorialStep = nil
            }
        }
    }
}
