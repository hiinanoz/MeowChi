import SwiftUI

@main
@MainActor
struct MeowchiApp: App {
    @State private var store = GameStore.makeDefault()

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
        HomeView()
            .preferredColorScheme(.dark)
            .alert("save.error.title", isPresented: Binding(get: { store.loadIssue != nil },
                                                            set: { if !$0 { store.loadIssue = nil } })) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text("save.error.message")
            }
    }
}
