import SpriteKit

/// Wall, floor, window, rug and wall art: the static layers behind the cat, built from the
/// equipped decorations. Shared by the room and the mini-games so they always match.
final class RoomBackdrop: SKNode {
    private let wall = SKSpriteNode()
    private let floorLayer = SKSpriteNode()
    private let window = SKSpriteNode(texture: SpriteLibrary.texture("window_basic"))
    private let rug = SKSpriteNode()
    private let wallArt = SKSpriteNode()

    override init() {
        super.init()
        let origin = CGPoint(x: -RoomScene.artPadding.width, y: -RoomScene.artPadding.height)
        for (node, z) in [(wall, -1000), (floorLayer, -999)] {
            node.anchorPoint = .zero
            node.position = origin
            node.zPosition = CGFloat(z)
            addChild(node)
        }
        window.anchorPoint = CGPoint(x: 0, y: 1)
        window.position = CGPoint(x: 92, y: 372)
        window.zPosition = -990
        wallArt.anchorPoint = CGPoint(x: 0, y: 1)
        wallArt.position = CGPoint(x: 284, y: 324)
        wallArt.zPosition = -990
        rug.position = CGPoint(x: 180, y: 70)
        rug.zPosition = -900
        [window, wallArt, rug].forEach(addChild)
        apply(DecorState())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func apply(_ decor: DecorState) {
        set(wall, decor.equipped(.wallpaper).id)
        set(floorLayer, decor.equipped(.floor).id)
        set(rug, decor.equipped(.rug).id)
        set(wallArt, decor.equipped(.wallArt).id)
    }

    private func set(_ node: SKSpriteNode, _ name: String) {
        let texture = SpriteLibrary.texture(name)
        node.texture = texture
        node.size = texture.size()
    }
}
