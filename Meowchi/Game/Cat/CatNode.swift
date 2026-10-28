import SpriteKit

/// Visual states of the cat. Each maps to one looping (or one-shot) sprite animation.
enum CatAnimation: Equatable {
    case idle, walk, happy, sad, eat, sleep
}

/// The cat character: a container node that moves (possibly sub-pixel) plus a sprite child
/// that the scene snaps to whole pixels every frame. All frames are 64x64 with feet at the bottom center,
/// so switching animations never shifts the character.
final class CatNode: SKNode {
    static let frameSize = CGSize(width: 64, height: 64)
    static let walkSpeed: CGFloat = 60 // logical pixels per second

    let sprite = SKSpriteNode(texture: SpriteLibrary.texture("cat_idle_0"), size: CatNode.frameSize)
    private(set) var animation: CatAnimation?
    /// True while a scripted sequence (feeding, going to bed) owns the cat.
    var isScripted = false
    /// Coat color; changing it swaps the running animation's frames in place.
    var appearance = CatAppearance.defaultID {
        didSet {
            guard appearance != oldValue, let current = animation else { return }
            sprite.texture = SpriteLibrary.texture(CatAppearance.textureName("idle_0", appearance: appearance))
            play(current, force: true)
        }
    }

    override init() {
        super.init()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(sprite)
        play(.idle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Hit area in the parent's coordinate space, slightly generous for small fingers.
    var hitFrame: CGRect {
        CGRect(x: position.x - 28, y: position.y, width: 56, height: 56)
    }

    func play(_ next: CatAnimation, force: Bool = false) {
        guard force || next != animation else { return }
        animation = next
        sprite.removeAction(forKey: "anim")
        sprite.run(action(for: next), withKey: "anim")
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

    private func action(for animation: CatAnimation) -> SKAction {
        let appearance = appearance
        func loop(_ names: [String], _ time: TimeInterval) -> SKAction {
            .repeatForever(.animate(with: SpriteLibrary.textures(names.map { CatAppearance.textureName($0, appearance: appearance) }),
                                    timePerFrame: time))
        }
        switch animation {
        case .idle:
            return loop(["idle_0", "idle_1", "idle_0", "idle_1", "idle_0", "blink", "idle_1"], 0.45)
        case .walk: return loop(["walk_0", "walk_1"], 0.18)
        case .happy: return loop(["happy_0", "happy_1"], 0.25)
        case .sad: return loop(["sad", "sad", "blink"], 0.6)
        case .eat: return loop(["eat_0", "eat_1"], 0.22)
        case .sleep: return loop(["sleep_0", "sleep_1"], 0.9)
        }
    }
}
