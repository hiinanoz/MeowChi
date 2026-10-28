import SpriteKit
import UIKit

/// Laser Chase: drag to move the laser dot; the cat chases it. Reaching the dot scores a point,
/// then the player has to move the dot away again (`rearmDistance`) before the next point counts.
final class LaserChaseScene: SKScene {
    static let catchRadius: CGFloat = 14
    static let rearmDistance: CGFloat = 70
    static let baseSpeed: CGFloat = 120
    static let speedPerPoint: CGFloat = 3
    static let maxSpeed: CGFloat = 200

    /// Called on the main thread with the new score after every catch.
    var onScore: ((Int) -> Void)?
    var isRunning = false
    /// Set before presenting so the play area matches the player's room.
    var decor = DecorState() { didSet { backdrop.apply(decor) } }
    var look = CatLook() { didSet { cat.look = look } }
    private let backdrop = RoomBackdrop()

    private let world = SKNode()
    private let cat = CatNode()
    private let laser = SKSpriteNode(texture: SpriteLibrary.texture("fx_laser"))
    private var score = 0
    private var armed = true
    private var lastCatchPoint = CGPoint.zero
    private var lastUpdate: TimeInterval?
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    private var isBuilt = false

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
        cat.position = CGPoint(x: RoomScene.roomSize.width / 2, y: 40)
        world.addChild(cat)
        laser.zPosition = 2000
        laser.isHidden = true
        world.addChild(laser)
        laser.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
        layoutWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) { layoutWorld() }

    private func layoutWorld() {
        let s = max(1, floor(min(size.width / RoomScene.safeVisibleSize.width, size.height / RoomScene.safeVisibleSize.height)))
        world.setScale(s)
        world.position = CGPoint(x: ((size.width - RoomScene.roomSize.width * s) / 2).rounded(),
                                 y: ((size.height - RoomScene.roomSize.height * s) / 2).rounded())
    }

    func reset() {
        score = 0
        armed = true
        laser.isHidden = true
        cat.position = CGPoint(x: RoomScene.roomSize.width / 2, y: 40)
        cat.play(.idle)
    }

    /// The laser stays on the floor, where the cat can follow it.
    private var playArea: CGRect { RoomScene.walkArea.insetBy(dx: -20, dy: 0) }

    private func moveLaser(_ touch: UITouch) {
        guard isRunning else { return }
        let p = touch.location(in: world)
        laser.position = CGPoint(x: min(max(p.x, playArea.minX), playArea.maxX).rounded(),
                                 y: min(max(p.y, playArea.minY), playArea.maxY).rounded())
        laser.isHidden = false
        if !armed, hypot(laser.position.x - lastCatchPoint.x, laser.position.y - lastCatchPoint.y) >= Self.rearmDistance {
            armed = true
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { haptics.prepare(); moveLaser(touch) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { moveLaser(touch) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(1.0 / 20, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime
        guard isRunning, !laser.isHidden, armed else {
            if cat.animation == .walk { cat.play(.idle) }
            return
        }
        let dx = laser.position.x - cat.position.x
        let dy = laser.position.y - cat.position.y
        let distance = hypot(dx, dy)
        if distance <= Self.catchRadius {
            score += 1
            armed = false
            lastCatchPoint = laser.position
            haptics.impactOccurred()
            cat.react(.happy, duration: 0.5)
            let heart = SKSpriteNode(texture: SpriteLibrary.texture("fx_heart"))
            heart.position = CGPoint(x: cat.position.x.rounded(), y: cat.position.y.rounded() + 56)
            heart.zPosition = 2100
            world.addChild(heart)
            heart.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
            onScore?(score)
            return
        }
        let speed = min(Self.maxSpeed, Self.baseSpeed + CGFloat(score) * Self.speedPerPoint)
        let step = min(distance, speed * CGFloat(dt))
        cat.position = CGPoint(x: cat.position.x + dx / distance * step, y: cat.position.y + dy / distance * step)
        cat.face(towardX: laser.position.x)
        if cat.animation != .happy { cat.play(.walk) }
    }

    override func didFinishUpdate() {
        cat.sprite.position = CGPoint(x: cat.position.x.rounded() - cat.position.x,
                                      y: cat.position.y.rounded() - cat.position.y)
        cat.zPosition = 1000 - cat.position.y
    }
}
