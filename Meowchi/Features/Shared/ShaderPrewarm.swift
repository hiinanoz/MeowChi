import SpriteKit
import SwiftUI

/// Draws one tiny cat per coat once, offscreen-small and invisible, so every palette shader is
/// compiled before the player opens the customizer or a friend visits (avoids first-use hitches).
struct ShaderPrewarm: View {
    @State private var scene = PrewarmScene()
    @State private var done = false

    var body: some View {
        Group {
            if !done {
                SpriteView(scene: scene, preferredFramesPerSecond: 10)
                    .frame(width: 8, height: 8)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        done = true
                    }
            }
        }
    }
}

final class PrewarmScene: SKScene {
    override init(size: CGSize) {
        super.init(size: CGSize(width: 64, height: 64))
        for coat in CatCoat.allCases {
            let cat = CatNode()
            cat.look = CatLook(coat: coat.rawValue)
            cat.position = CGPoint(x: 32, y: 0)
            addChild(cat)
        }
    }

    override convenience init() { self.init(size: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
