import SpriteKit
import UIKit
import os

/// Loads pixel-art textures with nearest-neighbor filtering. Missing assets fall back to a
/// visible magenta placeholder instead of crashing.
enum SpriteLibrary {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture: SKTexture
        if let image = UIImage(named: name) {
            texture = SKTexture(image: image)
        } else {
            Logger(subsystem: "Meowchi", category: "Sprites").error("Missing sprite: \(name, privacy: .public)")
            texture = missingTexture
        }
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    static func textures(_ names: [String]) -> [SKTexture] { names.map(texture) }

    private static var missingTexture: SKTexture {
        let size = CGSize(width: 8, height: 8)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.magenta.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}
