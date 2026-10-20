import SpriteKit

/// Visual states of the cat. Each maps to one looping (or one-shot) sprite animation.
enum CatAnimation: Equatable {
    case idle, walk, happy, sad, eat, sleep
}

/// The cat character: a container node that moves (possibly sub-pixel) plus a sprite child
/// that the scene snaps to whole pixels every frame. All frames are 32x32 with feet at the bottom center,
/// so switching animations never shifts the character.
final class CatNode: SKNode {
    static let frameSize = CGSize(width: 32, height: 32)
    static let walkSpeed: CGFloat = 30 // logical pixels per second

    let sprite = SKSpriteNode(texture: SpriteLibrary.texture("cat_idle_0"), size: CatNode.frameSize)
    private(set) var animation: CatAnimation?
    /// True while a scripted sequence (feeding, going to bed) owns the cat.
    var isScripted = false

    override init() {
        super.init()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(sprite)
        play(.idle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Hit area in the parent's coordinate space, slightly generous for small fingers.
    var hitFrame: CGRect {
        CGRect(x: position.x - 14, y: position.y, width: 28, height: 28)
    }

    func play(_ next: CatAnimation, force: Bool = false) {
        guard force || next != animation else { return }
        animation = next
        sprite.removeAction(forKey: "anim")
        sprite.run(Self.action(for: next), withKey: "anim")
    }

    func face(towardX x: CGFloat) {
        guard abs(x - position.x) > 1 else { return }
        sprite.xScale = x < position.x ? -1 : 1
    }

    func walk(to target: CGPoint, completion: (() -> Void)? = nil) {
        removeAction(forKey: "move")
        face(towardX: target.x)
        play(.walk)
        let distance = hypot(target.x - position.x, target.y - position.y)
        let move = SKAction.move(to: target, duration: TimeInterval(distance / Self.walkSpeed))
        run(.sequence([move, .run { [weak self] in
            self?.play(.idle)
            completion?()
        }]), withKey: "move")
    }

    func stopMoving() {
        removeAction(forKey: "move")
    }

    /// One-shot reaction, then back to idle.
    func react(_ reaction: CatAnimation, duration: TimeInterval) {
        play(reaction, force: true)
        run(.sequence([.wait(forDuration: duration), .run { [weak self] in
            guard let self, self.animation == reaction else { return }
            self.play(.idle)
        }]), withKey: "react")
    }

    private static func action(for animation: CatAnimation) -> SKAction {
        func loop(_ names: [String], _ time: TimeInterval) -> SKAction {
            .repeatForever(.animate(with: SpriteLibrary.textures(names), timePerFrame: time))
        }
        switch animation {
        case .idle:
            return loop(["cat_idle_0", "cat_idle_1", "cat_idle_0", "cat_idle_1", "cat_idle_0", "cat_blink", "cat_idle_1"], 0.45)
        case .walk: return loop(["cat_walk_0", "cat_walk_1"], 0.18)
        case .happy: return loop(["cat_happy_0", "cat_happy_1"], 0.25)
        case .sad: return loop(["cat_sad", "cat_sad", "cat_blink"], 0.6)
        case .eat: return loop(["cat_eat_0", "cat_eat_1"], 0.22)
        case .sleep: return loop(["cat_sleep_0", "cat_sleep_1"], 0.9)
        }
    }
}
