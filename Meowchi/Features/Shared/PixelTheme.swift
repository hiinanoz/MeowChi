import SwiftUI

/// Game UI palette. The game keeps its own art direction in light and dark mode.
enum PixelPalette {
    static let ink = Color(red: 0.23, green: 0.15, blue: 0.16)
    static let panel = Color(red: 1.0, green: 0.95, blue: 0.88)
    static let panelShade = Color(red: 0.91, green: 0.80, blue: 0.70)
    static let frame = Color(red: 0.17, green: 0.13, blue: 0.20)
    static let accent = Color(red: 0.95, green: 0.60, blue: 0.29)
    static let accentShade = Color(red: 0.80, green: 0.42, blue: 0.17)
    static let barTrack = Color(red: 0.78, green: 0.70, blue: 0.64)
    static let good = Color(red: 0.42, green: 0.78, blue: 0.40)
    static let warn = Color(red: 0.98, green: 0.75, blue: 0.25)
    static let bad = Color(red: 0.92, green: 0.33, blue: 0.33)
    static let xp = Color(red: 0.45, green: 0.62, blue: 0.95)

    static func level(_ value: Double) -> Color {
        value >= 60 ? good : value >= 30 ? warn : bad
    }
}

enum PixelFont {
    // System monospaced keeps CJK glyphs working. A bitmap font can replace this in the polish phase.
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
}

/// Rectangle with stepped "pixel" corners.
struct PixelBorder: Shape {
    var step: CGFloat = 3

    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = step
        p.move(to: CGPoint(x: r.minX + s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + s))
        p.closeSubpath()
        return p
    }
}

struct PixelPanel: ViewModifier {
    var fill = PixelPalette.panel

    func body(content: Content) -> some View {
        content
            .background(PixelBorder().fill(fill))
            .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 2))
    }
}

extension View {
    func pixelPanel(_ fill: Color = PixelPalette.panel) -> some View { modifier(PixelPanel(fill: fill)) }
}

struct PixelButtonStyle: ButtonStyle {
    var fill = PixelPalette.accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(PixelFont.body(13))
            .foregroundStyle(PixelPalette.ink)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(PixelBorder().fill(isEnabled ? fill : PixelPalette.barTrack))
            .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 2))
            .background(PixelBorder().fill(PixelPalette.ink).offset(y: pressed ? 0 : 3))
            .offset(y: pressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.7)
    }
}

/// Segmented pixel progress bar.
struct PixelBar: View {
    var value: Double // 0...100
    var color: Color
    var segments = 10

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle().fill(Double(i) < (value / 100 * Double(segments)).rounded(.up) ? color : PixelPalette.barTrack)
            }
        }
        .padding(2)
        .background(PixelPalette.ink)
        .frame(height: 10)
    }
}

/// The one back button used everywhere: arrow + "Back", top-left of a screen.
struct BackButton: View {
    var title: LocalizedStringKey = "common.back"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                PixelIcon(name: "icon_back", size: 14)
                Text(title).font(PixelFont.body(12))
            }
            .foregroundStyle(PixelPalette.ink)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .pixelPanel(PixelPalette.panelShade)
        }
        .buttonStyle(.plain)
    }
}

/// Screen header: back button on the left, centered title, optional trailing content.
struct PixelHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title).font(PixelFont.body(16)).lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 90)
            HStack {
                BackButton(action: onBack)
                Spacer()
                trailing
            }
        }
        .foregroundStyle(PixelPalette.ink)
    }
}

extension PixelHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

struct PixelIcon: View {
    let name: String
    var size: CGFloat = 18

    var body: some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
