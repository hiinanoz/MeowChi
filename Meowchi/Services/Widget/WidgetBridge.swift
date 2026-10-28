import UIKit
import WidgetKit

/// Writes the widget snapshot (12-hour forecast + cat picture) and asks WidgetKit to refresh.
@MainActor
enum WidgetBridge {
    static let forecastHours = 12

    static func makeSnapshot(from state: GameState, now: Date, balance: Balance) -> WidgetSnapshot {
        var copy = state
        var points: [WidgetSnapshot.Point] = []
        for hour in 0...forecastHours {
            let date = now.addingTimeInterval(Double(hour) * 3600)
            CatSimulator.advance(&copy, to: date, balance: balance)
            let s = copy.cat.stats
            points.append(.init(date: date, hunger: s.hunger, energy: s.energy, happiness: s.happiness,
                                cleanliness: s.cleanliness, health: s.health, sleeping: copy.cat.isSleeping))
        }
        return WidgetSnapshot(name: state.cat.name, points: points)
    }

    static func update(from store: GameStore) {
        let snapshot = makeSnapshot(from: store.state, now: .now, balance: store.balance)
        guard snapshot.write(image: CatImageRenderer.render(store.state.cat.look)) else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Flattens the cat's layers into one image on the CPU (no shader), with an exact fur palette swap.
/// Used where SpriteKit isn't available, like the widget picture.
enum CatImageRenderer {
    private static let keys: [(UInt8, UInt8, UInt8)] = [(242, 153, 74), (222, 120, 52), (251, 188, 115), (198, 94, 28)]

    static func render(_ look: CatLook, scale: Int = 4) -> UIImage? {
        let size = 64
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let coat = look.coatValue.palette.map { (UInt8($0.0), UInt8($0.1), UInt8($0.2)) }
        let fur = ["cat_tail_\(look.tailValue.rawValue)_front_wag1", "cat_ears_\(look.earsValue.rawValue)_idle_0", "cat_idle_0"]
        let extras = [look.neck, look.head].compactMap { $0 }.map { "cat_acc_\($0)_idle_0" }
        for (name, recolor) in fur.map({ ($0, true) }) + extras.map({ ($0, false) }) {
            guard let layer = rgba(name, size: size) else { continue }
            for i in stride(from: 0, to: layer.count, by: 4) where layer[i + 3] > 0 {
                var rgb = (layer[i], layer[i + 1], layer[i + 2])
                if recolor, let k = keys.firstIndex(where: { $0 == rgb }) { rgb = coat[k] }
                pixels[i] = rgb.0; pixels[i + 1] = rgb.1; pixels[i + 2] = rgb.2; pixels[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let small = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let out = CGSize(width: size * scale, height: size * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: out, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.translateBy(x: 0, y: out.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.draw(small, in: CGRect(origin: .zero, size: out))
        }
    }

    /// Unpremultiplied RGBA bytes of an asset, in sRGB so key colors stay exact.
    static func rgba(_ name: String, size: Int) -> [UInt8]? {
        guard let cg = UIImage(named: name)?.cgImage else { return nil }
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        guard let ctx = CGContext(data: &bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        return bytes
    }
}
