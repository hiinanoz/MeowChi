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
        #endif
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
