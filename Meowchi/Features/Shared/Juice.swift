import SwiftUI

// Small feedback pieces shared by the screens: shake on a failed tap, a pressed look for plain
// tile buttons, the pixel iris transition and coins that fly into the HUD counter.

/// Horizontal shake; bump `shakes` by 1 to play it once. Turns into nothing with Reduce Motion.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard !Motion.reduced else { return ProjectionTransform(.identity) }
        return ProjectionTransform(CGAffineTransform(translationX: (6 * sin(shakes * .pi * 4)).rounded(), y: 0))
    }
}

/// Plain tiles and rows sink by 2 pt while pressed, like the pixel buttons.
struct PixelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.04 : 0)
    }
}

/// A black screen with a round hole: `closed` 0 shows everything, 1 is fully black.
struct IrisShape: Shape {
    var closed: CGFloat
    var animatableData: CGFloat {
        get { closed }
        set { closed = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let maxRadius = hypot(rect.width, rect.height) / 2
        // Whole-point steps keep the edge looking pixelated rather than smooth.
        let radius = (maxRadius * (1 - closed) / 4).rounded() * 4
        if radius > 0 {
            path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

struct IrisCurtain: View {
    var closed: CGFloat

    var body: some View {
        IrisShape(closed: closed)
            .fill(Color.black, style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Where coins fly from (the room) and to (the HUD counter), in the "home" coordinate space.
struct CoinTargetKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct CoinOriginKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

extension View {
    /// Reports this view's frame in the "home" space through `key`.
    func reportFrame<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGRect {
        background(GeometryReader { proxy in Color.clear.preference(key: key, value: proxy.frame(in: .named("home"))) })
    }
}

/// Coins that pop out of the room and fly into the HUD counter.
struct CoinBurstLayer: View {
    struct Burst: Identifiable {
        let id = UUID()
        let count: Int
    }

    let bursts: [Burst]
    let origin: CGRect
    let target: CGRect

    var body: some View {
        ZStack {
            ForEach(bursts) { burst in
                ForEach(0..<burst.count, id: \.self) { index in
                    FlyingCoin(index: index, from: CGPoint(x: origin.midX, y: origin.midY),
                               to: CGPoint(x: target.midX, y: target.midY))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FlyingCoin: View {
    let index: Int
    let from: CGPoint
    let to: CGPoint
    @State private var phase = 0 // 0 = start, 1 = popped out, 2 = arrived

    var body: some View {
        let spread = CGFloat(index % 2 == 0 ? index : -index) * 9
        let point: CGPoint = switch phase {
        case 0: from
        case 1: CGPoint(x: from.x + spread, y: from.y - 28 - CGFloat(index % 3) * 6)
        default: to
        }
        PixelIcon(name: "icon_coin", size: 18)
            .position(point)
            .opacity(phase == 2 ? 0 : 1)
            .onAppear {
                let delay = Double(index) * 0.06
                withAnimation(.easeOut(duration: 0.22).delay(delay)) { phase = 1 }
                withAnimation(.easeIn(duration: 0.5).delay(delay + 0.22)) { phase = 2 }
            }
    }
}
