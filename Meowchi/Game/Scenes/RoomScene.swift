import SpriteKit

/// The cat's home. Art is authored at a fixed logical resolution (`roomSize`) and scaled
/// by a whole-number factor so every art pixel maps to an integer number of screen points.
final class RoomScene: SKScene {
    static let roomSize = CGSize(width: 180, height: 200)
    /// Area that must always be visible; it sets the whole-number scale. Edges outside it may be cropped on narrow phones.
    static let safeVisibleSize = CGSize(width: 160, height: 200)
    /// Extra background art around the core room (see Tools/gen_sprites.py ROOM_PAD_X/Y).
    static let artPadding = CGSize(width: 20, height: 80)
    /// Walkable floor area in room coordinates (origin bottom-left).
    static let walkArea = CGRect(x: 30, y: 8, width: 120, height: 52)

    private enum Spot {
        static let catStart = CGPoint(x: 90, y: 28)
        static let foodBowl = CGPoint(x: 44, y: 44)
        static let waterBowl = CGPoint(x: 26, y: 46)
        static let eat = CGPoint(x: 60, y: 42)
        static let bed = CGPoint(x: 136, y: 16)
        static let sleep = CGPoint(x: 136, y: 18)
        static let scratchingPost = CGPoint(x: 160, y: 62)
        static let plant = CGPoint(x: 20, y: 64)
        static let yarn = CGPoint(x: 104, y: 22)
    }

    weak var store: GameStore?

    private let world = SKNode()
    private let cat = CatNode()
    private let foodBowl = SKSpriteNode(texture: SpriteLibrary.texture("bowl_empty"))
    private let nightOverlay = SKSpriteNode(color: SKColor(red: 0.08, green: 0.07, blue: 0.25, alpha: 1), size: RoomScene.roomSize)
    private var isBuilt = false
    private var lastUpdate: TimeInterval = 0
    private var nextDecisionAt: TimeInterval = 0

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
        let background = SKSpriteNode(texture: SpriteLibrary.texture("room_background"))
        background.anchorPoint = .zero
        background.position = CGPoint(x: -Self.artPadding.width, y: -Self.artPadding.height)
        background.zPosition = -1000
        world.addChild(background)

        place(foodBowl, at: Spot.foodBowl)
        place(SKSpriteNode(texture: SpriteLibrary.texture("bowl_water")), at: Spot.waterBowl)
        place(SKSpriteNode(texture: SpriteLibrary.texture("bed_basic")), at: Spot.bed)
        place(SKSpriteNode(texture: SpriteLibrary.texture("scratching_post")), at: Spot.scratchingPost)
        place(SKSpriteNode(texture: SpriteLibrary.texture("plant_basic")), at: Spot.plant)
        place(SKSpriteNode(texture: SpriteLibrary.texture("toy_yarn")), at: Spot.yarn)

        cat.position = Spot.catStart
        world.addChild(cat)

        nightOverlay.anchorPoint = .zero
        nightOverlay.size = CGSize(width: Self.roomSize.width + 2 * Self.artPadding.width,
                                   height: Self.roomSize.height + 2 * Self.artPadding.height)
        nightOverlay.position = background.position
        nightOverlay.alpha = 0
        nightOverlay.zPosition = 2000
        world.addChild(nightOverlay)

        layoutWorld()
        if store?.state.cat.isSleeping == true { setSleeping(true, animated: false) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutWorld()
    }

    private func layoutWorld() {
        let scale = max(1, floor(min(size.width / Self.safeVisibleSize.width, size.height / Self.safeVisibleSize.height)))
        world.setScale(scale)
        world.position = CGPoint(x: ((size.width - Self.roomSize.width * scale) / 2).rounded(),
                                 y: ((size.height - Self.roomSize.height * scale) / 2).rounded())
    }

    private func place(_ node: SKSpriteNode, at point: CGPoint) {
        node.texture?.filteringMode = .nearest
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = point
        node.zPosition = depth(for: point.y)
        world.addChild(node)
    }

    private func depth(for y: CGFloat) -> CGFloat { 1000 - y }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        lastUpdate = currentTime
        guard let store, !cat.isScripted, !store.state.cat.isSleeping,
              cat.action(forKey: "move") == nil, currentTime >= nextDecisionAt else { return }
        decideNextBehavior(mood: store.mood)
    }

    override func didFinishUpdate() {
        // Keep the moving container smooth but draw the sprite on whole art pixels.
        cat.sprite.position = CGPoint(x: cat.position.x.rounded() - cat.position.x,
                                      y: cat.position.y.rounded() - cat.position.y)
        cat.zPosition = depth(for: cat.position.y)
    }

    private func decideNextBehavior(mood: Mood) {
        let walkChance: Double
        switch mood {
        case .excited: walkChance = 0.8
        case .sleepy: walkChance = 0.15
        case .sad, .hungry, .bored: walkChance = 0.3
        case .happy, .neutral: walkChance = 0.5
        }
        if Double.random(in: 0...1) < walkChance {
            cat.walk(to: randomFloorPoint())
        } else {
            cat.play([.sad, .hungry].contains(mood) ? .sad : .idle)
        }
        nextDecisionAt = lastUpdate + .random(in: 2.5...5.5)
    }

    private func randomFloorPoint() -> CGPoint {
        CGPoint(x: .random(in: Self.walkArea.minX...Self.walkArea.maxX).rounded(),
                y: .random(in: Self.walkArea.minY...Self.walkArea.maxY).rounded())
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let store else { return }
        let point = touch.location(in: world)
        if cat.hitFrame.contains(point) {
            handlePet(store.pet())
        } else if !cat.isScripted, !store.state.cat.isSleeping, Self.walkArea.insetBy(dx: -12, dy: -8).contains(point) {
            let target = CGPoint(x: min(max(point.x, Self.walkArea.minX), Self.walkArea.maxX).rounded(),
                                 y: min(max(point.y, Self.walkArea.minY), Self.walkArea.maxY).rounded())
            cat.walk(to: target)
            nextDecisionAt = lastUpdate + 4
        }
    }

    private func handlePet(_ result: ActionResult) {
        switch result {
        case .ok:
            guard !cat.isScripted else { spawnHearts(); return }
            cat.stopMoving()
            cat.react(.happy, duration: 1.4)
            spawnHearts()
            nextDecisionAt = lastUpdate + 3
        case .noReward:
            guard !cat.isScripted else { return }
            cat.stopMoving()
            cat.react(.happy, duration: 0.6)
        case .sleeping:
            spawnEffect("fx_zzz", offsetY: 18)
        case .busy, .outOfStock, .unknownItem:
            break
        }
    }

    // MARK: Scripted sequences

    /// Runs after `GameStore.feed` succeeded. Stats are already applied, so cancelling this is harmless.
    func playFeeding() {
        cancelScript()
        cat.isScripted = true
        foodBowl.texture = SpriteLibrary.texture("bowl_food")
        cat.walk(to: Spot.eat) { [weak self] in
            guard let self else { return }
            self.cat.face(towardX: Spot.foodBowl.x)
            self.cat.play(.eat)
            self.run(.sequence([.wait(forDuration: 2.4), .run { [weak self] in
                guard let self else { return }
                self.foodBowl.texture = SpriteLibrary.texture("bowl_empty")
                self.cat.isScripted = false
                self.cat.react(.happy, duration: 1)
                self.spawnHearts()
                self.nextDecisionAt = self.lastUpdate + 2
            }]), withKey: "script")
        }
    }

    func setSleeping(_ sleeping: Bool, animated: Bool) {
        cancelScript()
        if sleeping {
            cat.isScripted = true
            nightOverlay.run(.fadeAlpha(to: 0.4, duration: animated ? 1.2 : 0))
            let lieDown = { [weak self] in
                guard let self else { return }
                self.cat.play(.sleep)
                self.run(.repeatForever(.sequence([.run { [weak self] in self?.spawnEffect("fx_zzz", offsetY: 20) },
                                                   .wait(forDuration: 1.6)])), withKey: "script")
            }
            if animated { cat.walk(to: Spot.sleep, completion: lieDown) } else { cat.position = Spot.sleep; lieDown() }
        } else {
            nightOverlay.run(.fadeAlpha(to: 0, duration: animated ? 0.8 : 0))
            cat.isScripted = false
            cat.react(.happy, duration: 0.8)
            nextDecisionAt = lastUpdate + 1.5
        }
    }

    private func cancelScript() {
        removeAction(forKey: "script")
        cat.stopMoving()
        foodBowl.texture = SpriteLibrary.texture("bowl_empty")
        cat.isScripted = false
    }

    // MARK: Effects

    private func spawnHearts() {
        for i in 0..<3 {
            run(.wait(forDuration: Double(i) * 0.18)) { [weak self] in
                self?.spawnEffect("fx_heart", offsetY: 28, dx: CGFloat([-6, 2, 8][i]))
            }
        }
    }

    private func spawnEffect(_ name: String, offsetY: CGFloat, dx: CGFloat = 4) {
        let node = SKSpriteNode(texture: SpriteLibrary.texture(name))
        node.position = CGPoint(x: cat.position.x.rounded() + dx, y: cat.position.y.rounded() + offsetY)
        node.zPosition = 2100
        world.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 12, duration: 1), .fadeOut(withDuration: 1)]), .removeFromParent()]))
    }
}
