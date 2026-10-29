import SwiftUI

/// Shared pixel sheet layout (title bar + scrolling content).
struct SheetScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    /// Pushed pages inside a sheet show Back instead of Close.
    var isPushed = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            if isPushed {
                PixelHeader(title: title, onBack: onClose)
            } else {
                PixelSheetHeader(title: title, onClose: onClose)
            }
            ScrollView {
                VStack(spacing: 8) { content }
            }
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(14)
        .background(PixelPalette.panel.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
