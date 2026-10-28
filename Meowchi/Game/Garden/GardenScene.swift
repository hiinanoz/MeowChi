import SpriteKit
import UIKit

/// Side-scrolling garden walk. Tap the path to walk; tap a sparkle to walk there and dig it up.
/// Rewards are validated and paid by `GameStore.collectFind`.
final class GardenScene: SKScene {
    static let gardenWidth: CGFloat = 1080
    /// Walkable path (garden coordinates, origin bottom-left of the 400-pt core band).
    static let path = CGRect(x: 30, y: 20, width: 1020, height: 92)

    weak var store: GameStore?
    var appearance = CatAppearance.defaultID { didSet { cat.appearance = appearance } }
    /// Called with the reward after a successful dig, for the SwiftUI layer.
    var onFind: ((FindReward) -> Void)?

    private let world = SKNode()
    private let cat = CatNode()
    private var findNodes: [Int: SKSpriteNode] = [:]
    private var worldScale: CGFloat = 1
    private var isBuilt = false
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.63, green: 0.82, blue: 0.96, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        guard !isBuilt else { return }
        isBuilt = true
        addChild(world)
        let background = SKSpriteNode(texture: SpriteLibrary.texture("garden_background"))
        background.anchorPoint = .zero
        background.position = CGPoint(x: 0, y: -RoomScene.artPadding.height)
        background.zPosition = -1000
        world.addChild(background)
        cat.position = CGPoint(x: 80, y: 60)
        world.addChild(cat)
        layoutWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) { layoutWorld() }

    private func layoutWorld() {
        worldScale = max(1, floor(min(size.width / RoomScene.safeVisibleSize.width,
                                      size.height / RoomScene.safeVisibleSize.height)))
        world.setScale(worldScale)
        followCat()
    }

    /// Places the sparkles for the current walk. Call after `GameStore.startWalk` succeeded.
    func showFinds(_ walk: WalkSession) {
        findNodes.values.forEach { $0.removeFromParent() }
        findNodes = [:]
        for (i, find) in walk.finds.enumerated() where !find.collected {
            let node = SKSpriteNode(texture: SpriteLibrary.texture("fx_sparkle"))
            node.position = point(for: find)
            node.zPosition = 1000 - node.position.y
            node.setScale(2)
            node.run(.repeatForever(.sequence([.scale(to: 2.6, duration: 0.5), .scale(to: 2, duration: 0.5)])))
            world.addChild(node)
            findNodes[i] = node
        }
    }

    private func point(for find: WalkFind) -> CGPoint {
        CGPoint(x: (Self.path.minX + CGFloat(find.x) * Self.path.width).rounded(),
                y: (Self.path.minY + CGFloat(find.y) * Self.path.height).rounded())
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, store?.activeWalk != nil else { return }
        let p = touch.location(in: world)
        if let nearest = findNodes.min(by: { distance($0.value.position, p) < distance($1.value.position, p) }),
           distance(nearest.value.position, p) < 40 {
            let index = nearest.key, spot = nearest.value.position
            cat.walk(to: CGPoint(x: spot.x - 10, y: spot.y)) { [weak self] in self?.dig(index) }
            return
        }
        cat.walk(to: CGPoint(x: min(max(p.x, Self.path.minX), Self.path.maxX).rounded(),
                             y: min(max(p.y, Self.path.minY), Self.path.maxY).rounded()))
    }

    private func dig(_ index: Int) {
        guard let node = findNodes[index], let reward = store?.collectFind(index) else { return }
        findNodes[index] = nil
        node.removeFromParent()
        haptics.impactOccurred()
        cat.react(.happy, duration: 1)
        let icon: String
        switch reward {
        case .coins: icon = "icon_coin"
        case .item(let id): icon = ItemCatalog.food(id)?.iconName ?? "icon_coin"
        }
        let pop = SKSpriteNode(texture: SpriteLibrary.texture(icon))
        pop.setScale(2)
        pop.position = CGPoint(x: node.position.x, y: node.position.y + 40)
        pop.zPosition = 2100
        world.addChild(pop)
        pop.run(.sequence([.group([.moveBy(x: 0, y: 30, duration: 1), .fadeOut(withDuration: 1)]), .removeFromParent()]))
        onFind?(reward)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    override func didFinishUpdate() {
        cat.sprite.position = CGPoint(x: cat.position.x.rounded() - cat.position.x,
                                      y: cat.position.y.rounded() - cat.position.y)
        cat.zPosition = 1000 - cat.position.y
        followCat()
    }

    /// Horizontal camera: keep the cat centered, clamped to the garden edges, on whole points.
    private func followCat() {
        let visible = Self.gardenWidth * worldScale
        let x = min(0, max(size.width - visible, size.width / 2 - cat.position.x * worldScale))
        world.position = CGPoint(x: x.rounded(),
                                 y: ((size.height - RoomScene.roomSize.height * worldScale) / 2).rounded())
    }
}
