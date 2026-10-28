import SpriteKit

/// Visual states of the cat. Each maps to one looping (or one-shot) sprite animation.
enum CatAnimation: Equatable {
    case idle, walk, happy, sad, eat, sleep
}

/// Tail body language, independent of the body animation.
enum TailMood: Equatable {
    case happy, calm, tired, sad, annoyed

    init(_ mood: Mood) {
        switch mood {
        case .happy, .excited: self = .happy
        case .neutral, .bored: self = .calm
        case .sleepy: self = .tired
        case .hungry, .sad: self = .sad
        }
    }
}

/// The cat character: a container node that moves (possibly sub-pixel) plus a body sprite that the
/// scene snaps to whole pixels every frame. Ears and tail are child layers of the body, so they flip
/// and snap with it. All layers are 64x64 with feet at the bottom center.
final class CatNode: SKNode {
    static let frameSize = CGSize(width: 64, height: 64)
    static let walkSpeed: CGFloat = 60 // logical pixels per second

    /// The body layer (named `sprite` because scenes snap it to whole pixels).
    let sprite = SKSpriteNode(texture: SpriteLibrary.texture("cat_idle_0"), size: CatNode.frameSize)
    private let earsLayer = SKSpriteNode(texture: nil, size: CatNode.frameSize)
    private let tailLayer = SKSpriteNode(texture: nil, size: CatNode.frameSize)
    private(set) var animation: CatAnimation?
    /// True while a scripted sequence (feeding, going to bed) owns the cat.
    var isScripted = false
    var look = CatLook() {
        didSet { if look != oldValue { applyLook() } }
    }
    private var tailMood = TailMood.calm
    private var tailFlash: TailMood?

    override init() {
        super.init()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        for layer in [earsLayer, tailLayer] {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0)
            layer.zPosition = -0.5 // behind the body
            sprite.addChild(layer)
        }
        addChild(sprite)
        applyLook()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Hit area in the parent's coordinate space, slightly generous for small fingers.
    var hitFrame: CGRect {
        CGRect(x: position.x - 28, y: position.y, width: 56, height: 56)
    }

    func play(_ next: CatAnimation, force: Bool = false) {
        guard force || next != animation else { return }
        animation = next
        let (frames, time) = Self.frames(for: next)
        let ears = look.earsValue.rawValue
        loop(sprite, frames.map { "cat_" + $0 }, time)
        loop(earsLayer, frames.map { "cat_ears_\(ears)_" + $0 }, time)
        refreshTail()
    }

    func setTailMood(_ mood: TailMood) {
        guard mood != tailMood else { return }
        tailMood = mood
        refreshTail()
    }

    /// Shows a tail mood briefly (e.g. an annoyed upright tail during a bath), then returns to the base mood.
    func flashTail(_ mood: TailMood, duration: TimeInterval) {
        tailFlash = mood
        refreshTail()
        run(.sequence([.wait(forDuration: duration), .run { [weak self] in
            self?.tailFlash = nil
            self?.refreshTail()
        }]), withKey: "tailFlash")
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
        if animation == .walk { play(.idle) }
    }

    /// One-shot reaction, then back to idle.
    func react(_ reaction: CatAnimation, duration: TimeInterval) {
        play(reaction, force: true)
        if reaction == .happy { flashTail(.happy, duration: duration) }
        run(.sequence([.wait(forDuration: duration), .run { [weak self] in
            guard let self, self.animation == reaction else { return }
            self.play(.idle)
        }]), withKey: "react")
    }

    // MARK: Layers

    private func applyLook() {
        let shader = CatShader.shader(for: look.coatValue)
        for layer in [sprite, earsLayer, tailLayer] { layer.shader = shader }
        play(animation ?? .idle, force: true)
    }

    private func refreshTail() {
        let length = look.tailValue.rawValue
        tailLayer.removeAction(forKey: "anim")
        if animation == .sleep {
            tailLayer.texture = SpriteLibrary.texture("cat_tail_\(length)_sleep")
            tailLayer.zPosition = 0.5 // curled in front of the sleeping body
            return
        }
        tailLayer.zPosition = -0.5
        let family = animation == .walk ? "side" : "front"
        let mood = tailFlash ?? tailMood
        let (poses, time): ([String], TimeInterval)
        switch mood {
        case .happy: (poses, time) = (["wag0", "wag1"], 0.15)
        case .calm: (poses, time) = (["wag0", "wag1"], animation == .walk ? 0.3 : 0.6)
        case .tired, .sad: (poses, time) = (["down"], 1)
        case .annoyed: (poses, time) = (["up", "up", "up", "wag0"], 0.2)
        }
        loop(tailLayer, poses.map { "cat_tail_\(length)_\(family)_\($0)" }, time)
    }

    private func loop(_ node: SKSpriteNode, _ names: [String], _ time: TimeInterval) {
        node.removeAction(forKey: "anim")
        let textures = SpriteLibrary.textures(names)
        node.texture = textures.first
        guard textures.count > 1 else { return }
        node.run(.repeatForever(.animate(with: textures, timePerFrame: time)), withKey: "anim")
    }

    private static func frames(for animation: CatAnimation) -> ([String], TimeInterval) {
        switch animation {
        case .idle: (["idle_0", "idle_1", "idle_0", "idle_1", "idle_0", "blink", "idle_1"], 0.45)
        case .walk: (["walk_0", "walk_1", "walk_2", "walk_3"], 0.15)
        case .happy: (["happy_0", "happy_1"], 0.25)
        case .sad: (["sad", "sad", "blink"], 0.6)
        case .eat: (["eat_0", "eat_1"], 0.22)
        case .sleep: (["sleep_0", "sleep_1"], 0.9)
        }
    }
}
