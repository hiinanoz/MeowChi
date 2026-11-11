import SpriteKit

/// Life behind the window glass: the sky's color for the time of day, rain or snow, stars at
/// night and now and then a bird. Clipped to the glass so it never spills onto the wall.
final class WindowAmbience: SKNode {
    private let crop = SKCropNode()
    private let content = SKNode()
    private let tint = SKSpriteNode(color: .clear, size: .zero)
    private var glass = CGRect.zero
    private var weather: DayCycle.Weather?
    private var phase: DayCycle.Phase?

    override init() {
        super.init()
        addChild(crop)
        crop.addChild(content)
        tint.anchorPoint = .zero
        tint.zPosition = 1
        content.addChild(tint)
        run(.repeatForever(.sequence([.wait(forDuration: 60), .run { [weak self] in self?.refresh() }])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// `rect` is the window glass in backdrop coordinates.
    func layout(glass rect: CGRect) {
        guard rect != glass else { return }
        glass = rect
        let mask = SKSpriteNode(color: .white, size: rect.size)
        mask.anchorPoint = .zero
        mask.position = rect.origin
        crop.maskNode = mask
        tint.position = rect.origin
        tint.size = rect.size
        weather = nil
        refresh()
    }

    func refresh(now: Date = .now) {
        guard glass != .zero else { return }
        let newPhase = DayCycle.phase(at: now)
        let newWeather = DayCycle.weather(at: now)
        guard newPhase != phase || newWeather != weather else { return }
        phase = newPhase
        weather = newWeather
        content.removeAllActions()
        content.children.filter { $0 !== tint }.forEach { $0.removeFromParent() }
        removeAction(forKey: "birds")

        switch newPhase {
        case .dawn: tint.color = SKColor(red: 1.0, green: 0.62, blue: 0.45, alpha: 0.35)
        case .day: tint.color = newWeather == .clear ? .clear : SKColor(white: 0.45, alpha: 0.35)
        case .evening: tint.color = SKColor(red: 0.85, green: 0.40, blue: 0.45, alpha: 0.4)
        case .night: tint.color = SKColor(red: 0.06, green: 0.07, blue: 0.22, alpha: 0.7)
        }
        if newPhase == .night && newWeather == .clear { addStars() }
        guard !Motion.reduced else { return }
        switch newWeather {
        case .rain: addFalling(color: SKColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 0.8), size: CGSize(width: 1, height: 4),
                               speed: 140, every: 0.05, drift: -12)
        case .snow: addFalling(color: .white, size: CGSize(width: 2, height: 2), speed: 26, every: 0.18, drift: 8)
        case .clear: if newPhase == .day { scheduleBirds() }
        }
    }

    private func addStars() {
        for _ in 0..<10 {
            let star = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
            star.position = CGPoint(x: (glass.minX + .random(in: 4...(glass.width - 4))).rounded(),
                                    y: (glass.minY + .random(in: glass.height * 0.35...(glass.height - 4))).rounded())
            star.zPosition = 2
            content.addChild(star)
            if !Motion.reduced {
                star.run(.repeatForever(.sequence([.wait(forDuration: .random(in: 0.5...3)), .fadeAlpha(to: 0.3, duration: 0.4),
                                                   .fadeAlpha(to: 1, duration: 0.4)])))
            }
        }
    }

    private func addFalling(color: SKColor, size: CGSize, speed: CGFloat, every: TimeInterval, drift: CGFloat) {
        let spawn = SKAction.run { [weak self] in
            guard let self else { return }
            let drop = SKSpriteNode(color: color, size: size)
            drop.anchorPoint = .zero
            drop.position = CGPoint(x: (self.glass.minX + .random(in: 0...self.glass.width)).rounded(), y: self.glass.maxY)
            drop.zPosition = 3
            self.content.addChild(drop)
            let duration = TimeInterval((self.glass.height + 8) / speed)
            drop.run(.sequence([.moveBy(x: drift, y: -(self.glass.height + 8), duration: duration), .removeFromParent()]))
        }
        content.run(.repeatForever(.sequence([spawn, .wait(forDuration: every)])))
    }

    /// A small bird flaps across the glass every so often.
    private func scheduleBirds() {
        let fly = SKAction.run { [weak self] in
            guard let self else { return }
            let bird = SKNode()
            let left = SKSpriteNode(color: SKColor(white: 0.15, alpha: 1), size: CGSize(width: 2, height: 1))
            let right = SKSpriteNode(color: SKColor(white: 0.15, alpha: 1), size: CGSize(width: 2, height: 1))
            left.position = CGPoint(x: -1, y: 0)
            right.position = CGPoint(x: 1, y: 0)
            bird.addChild(left)
            bird.addChild(right)
            let flap = SKAction.repeatForever(.sequence([
                .run { left.position.y = 1; right.position.y = 1 }, .wait(forDuration: 0.15),
                .run { left.position.y = 0; right.position.y = 0 }, .wait(forDuration: 0.15),
            ]))
            let y = (self.glass.minY + .random(in: self.glass.height * 0.5...(self.glass.height - 6))).rounded()
            bird.position = CGPoint(x: self.glass.minX - 4, y: y)
            bird.zPosition = 4
            self.content.addChild(bird)
            bird.run(flap)
            bird.run(.sequence([.moveBy(x: self.glass.width + 8, y: .random(in: -6...6), duration: 3.5), .removeFromParent()]))
        }
        run(.repeatForever(.sequence([.wait(forDuration: 25, withRange: 20), fly])), withKey: "birds")
    }
}
