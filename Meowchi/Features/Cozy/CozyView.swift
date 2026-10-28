import SpriteKit
import SwiftUI

/// Cozy time: the cat fills the screen and you pet it up close. Rewards use the normal petting rules.
@MainActor
struct CozyView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scene = CozyScene(size: CGSize(width: 390, height: 600))

    var body: some View {
        VStack(spacing: 8) {
            PixelHeader(title: "cozy.title", onBack: { dismiss() })
                .padding(10)
                .pixelPanel()
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay(alignment: .bottom) {
                    Text("cozy.hint \(store.state.cat.name)")
                        .font(PixelFont.body(11)).multilineTextAlignment(.center)
                        .foregroundStyle(PixelPalette.ink)
                        .padding(10).pixelPanel().padding(10)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .onAppear {
            scene.store = store
            scene.look = store.state.cat.look
        }
    }
}

final class CozyScene: SKScene {
    weak var store: GameStore?
    var look = CatLook() { didSet { cat.look = look } }

    private let cat = CatNode()
    private var catScale: CGFloat = 4
    private var lastPoint = CGPoint.zero
    private var travel: CGFloat = 0
    private var touchingCat = false
    private let haptics = UIImpactFeedbackGenerator(style: .soft)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.98, green: 0.86, blue: 0.74, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        guard cat.parent == nil else { return }
        let rug = SKShapeNode(ellipseOf: CGSize(width: 300, height: 90))
        rug.fillColor = SKColor(red: 0.94, green: 0.75, blue: 0.63, alpha: 1)
        rug.strokeColor = .clear
        rug.isAntialiased = false
        rug.name = "rug"
        addChild(rug)
        addChild(cat)
        cat.setTailMood(.happy)
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) { layout() }

    private func layout() {
        catScale = max(2, floor(min(size.width, size.height * 0.75) / 80))
        cat.setScale(catScale)
        cat.position = CGPoint(x: (size.width / 2).rounded(), y: (size.height * 0.18).rounded())
        childNode(withName: "rug")?.position = CGPoint(x: size.width / 2, y: size.height * 0.18 + 10)
    }

    private var catFrame: CGRect {
        CGRect(x: cat.position.x - 30 * catScale, y: cat.position.y, width: 60 * catScale, height: 60 * catScale)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        touchingCat = catFrame.contains(p)
        lastPoint = p
        travel = 0
        haptics.prepare()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchingCat, let p = touches.first?.location(in: self), let store else { return }
        travel += hypot(p.x - lastPoint.x, p.y - lastPoint.y)
        lastPoint = p
        // Same stroke length as in the room, measured in room pixels.
        guard travel >= CGFloat(store.balance.strokeDistance) * catScale / 2 else { return }
        travel = 0
        let result = store.pet(.stroke)
        cat.react(.happy, duration: 1.6)
        if result == .ok {
            AudioManager.shared.play(.purr)
            haptics.impactOccurred(intensity: 0.7)
            heart(at: p)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touchingCat, travel < 10 {
            cat.react(.happy, duration: 0.6)
            AudioManager.shared.play(.meow)
        }
        touchingCat = false
    }

    private func heart(at point: CGPoint) {
        let node = SKSpriteNode(texture: SpriteLibrary.texture("fx_heart"))
        node.setScale(catScale / 2)
        node.position = point
        node.zPosition = 100
        addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 80, duration: 1.2), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
    }

    override func didFinishUpdate() {
        cat.sprite.position = .zero
    }
}
