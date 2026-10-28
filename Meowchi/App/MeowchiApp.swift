import SwiftUI

@main
@MainActor
struct MeowchiApp: App {
    @State private var store = GameStore.makeDefault()

    init() {
        #if DEBUG
        // Screenshot/QA helper: `-skipOnboarding` jumps straight into the room.
        if CommandLine.arguments.contains("-skipOnboarding"), store.needsOnboarding {
            store.completeOnboarding(name: "Mochi")
            store.tutorialStep = nil
        }
        if CommandLine.arguments.contains("-refillStats") { store.debugRefill() }
        if let i = CommandLine.arguments.firstIndex(of: "-debugDecor"), i + 1 < CommandLine.arguments.count {
            store.debugEquip(CommandLine.arguments[i + 1].split(separator: ",").map(String.init))
        }
        // `-debugLook coat,ears,tail`, e.g. `-debugLook cocoa,folded,long`.
        if let i = CommandLine.arguments.firstIndex(of: "-debugLook"), i + 1 < CommandLine.arguments.count {
            let parts = CommandLine.arguments[i + 1].split(separator: ",").map(String.init)
            if parts.count == 3 { store.setLook(CatLook(coat: parts[0], ears: parts[1], tail: parts[2])) }
        }
        #endif
        AudioManager.shared.apply(store.state.settings)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView().transition(.opacity)
            } else {
                HomeView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.needsOnboarding)
        .preferredColorScheme(.dark)
            .alert("save.error.title", isPresented: Binding(get: { store.loadIssue != nil },
                                                            set: { if !$0 { store.loadIssue = nil } })) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text("save.error.message")
            }
    }
}
