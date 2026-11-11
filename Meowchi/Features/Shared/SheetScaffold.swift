import SwiftUI

/// Shared pixel sheet layout (title bar + scrolling content).
struct SheetScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    /// Pushed pages inside a sheet show Back instead of Close.
    var isPushed = false
    /// Each screen's own color: a pixel stripe across the top of the sheet.
    var accent: Color? = nil
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
        .overlay(alignment: .top) {
            if let accent {
                HStack(spacing: 0) {
                    // Bunting: alternating flags in the screen color and a lighter shade.
                    ForEach(0..<24, id: \.self) { index in
                        Triangle().fill(index % 2 == 0 ? accent : accent.opacity(0.55)).frame(height: 8)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Downward pennant used by the sheet bunting.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
