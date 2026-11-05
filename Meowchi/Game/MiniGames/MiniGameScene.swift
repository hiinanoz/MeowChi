import SpriteKit
import UIKit

/// Shared room setup for the cat mini-games: the player's room as backdrop, the cat, whole-number
/// world scaling, a heart on every point and pixel-snapped drawing. Subclasses add the play logic
/// in `didBuild`, `resetPlay`, touches and `update`.
class MiniGameScene: SKScene {
    /// Called on the main thread with the new score after every point.
    var onScore: ((Int) -> Void)?
    var isRunning = false
    /// Set before presenting so the play area matches the player's room.
    var decor = DecorState() { didSet { backdrop.apply(decor) } }
    var look = CatLook() { didSet { cat.look = look } }

    let world = SKNode()
    let cat = CatNode()
    private(set) var score = 0
    private let backdrop = RoomBackdrop()
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    private var isBuilt = false
    var lastUpdate: TimeInterval?

    /// The floor area where toys and the cat move.
    var playArea: CGRect { RoomScene.walkArea.insetBy(dx: -20, dy: 0) }
    var catStart: CGPoint { CGPoint(x: RoomScene.roomSize.width / 2, y: 40) }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.17, green: 0.13, blue: 0.20, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        guard !isBuilt else { return }
        isBuilt = true
        addChild(world)
        world.addChild(backdrop)
        cat.setTailMood(.happy)
        cat.position = catStart
        world.addChild(cat)
        didBuild()
        layoutWorld()
    }

    /// Adds the game's own nodes to `world`.
    func didBuild() {}

    /// Clears the game's own state for a new round.
    func resetPlay() {}

    override func didChangeSize(_ oldSize: CGSize) { layoutWorld() }

    private func layoutWorld() {
        let s = max(1, floor(min(size.width / RoomScene.safeVisibleSize.width, size.height / RoomScene.safeVisibleSize.height)))
        world.setScale(s)
        world.position = CGPoint(x: ((size.width - RoomScene.roomSize.width * s) / 2).rounded(),
                                 y: ((size.height - RoomScene.roomSize.height * s) / 2).rounded())
    }

    func reset() {
        score = 0
        cat.position = catStart
        cat.play(.idle)
        resetPlay()
    }

    func clamped(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, playArea.minX), playArea.maxX), y: min(max(p.y, playArea.minY), playArea.maxY))
    }

    func prepareHaptics() { haptics.prepare() }

    /// Scores a point with a heart, a happy cat, a haptic tap and the catch sound.
    func scorePoint() {
        score += 1
        haptics.impactOccurred()
        AudioManager.shared.play(.laserCatch)
        cat.react(.happy, duration: 0.5)
        let heart = SKSpriteNode(texture: SpriteLibrary.texture("fx_heart"))
        heart.position = CGPoint(x: cat.position.x.rounded(), y: cat.position.y.rounded() + 56)
        heart.zPosition = 2100
        world.addChild(heart)
        heart.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        onScore?(score)
    }

    /// Moves the cat toward `target` at `speed` points per second; returns the remaining distance.
    @discardableResult
    func moveCat(toward target: CGPoint, speed: CGFloat, dt: CGFloat) -> CGFloat {
        let dx = target.x - cat.position.x
        let dy = target.y - cat.position.y
        let distance = hypot(dx, dy)
        guard distance > 0.5 else { return distance }
        let step = min(distance, speed * dt)
        cat.position = CGPoint(x: cat.position.x + dx / distance * step, y: cat.position.y + dy / distance * step)
        cat.face(towardX: target.x)
        if cat.animation != .happy { cat.play(.walk) }
        return distance - step
    }

    /// Frame time, capped so a hitch doesn't teleport anything.
    func frameTime(_ currentTime: TimeInterval) -> CGFloat {
        let dt = min(1.0 / 20, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime
        return CGFloat(dt)
    }

    override func didFinishUpdate() {
        cat.sprite.position = CGPoint(x: cat.position.x.rounded() - cat.position.x,
                                      y: cat.position.y.rounded() - cat.position.y)
        cat.zPosition = 1000 - cat.position.y
    }
}
