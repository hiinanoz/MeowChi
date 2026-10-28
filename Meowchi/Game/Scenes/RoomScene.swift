import SpriteKit
import UIKit

/// The cat's home. Art is authored at a fixed logical resolution (`roomSize`) and scaled
/// by a whole-number factor so every art pixel maps to an integer number of screen points.
final class RoomScene: SKScene {
    static let roomSize = CGSize(width: 360, height: 400)
    /// Area that must always be visible; it sets the whole-number scale. Edges outside it may be cropped on narrow phones.
    static let safeVisibleSize = CGSize(width: 320, height: 400)
    /// Extra background art around the core room (see Tools/gen_sprites.py ROOM_PAD_X/Y).
    static let artPadding = CGSize(width: 40, height: 160)
    /// Walkable floor area in room coordinates (origin bottom-left).
    static let walkArea = CGRect(x: 60, y: 16, width: 240, height: 104)

    private enum Spot {
        static let catStart = CGPoint(x: 180, y: 56)
        static let foodBowl = CGPoint(x: 88, y: 88)
        static let waterBowl = CGPoint(x: 52, y: 92)
        static let eat = CGPoint(x: 120, y: 84)
        static let drink = CGPoint(x: 76, y: 88)
        static let scratch = CGPoint(x: 296, y: 122)
        static let tv = CGPoint(x: 180, y: 128)
        static let watchTV = CGPoint(x: 180, y: 78)
        static let bed = CGPoint(x: 272, y: 32)
        static let sleep = CGPoint(x: 272, y: 36)
        static let scratchingPost = CGPoint(x: 320, y: 124)
        static let plant = CGPoint(x: 40, y: 128)
        static let yarn = CGPoint(x: 208, y: 44)
        static let litter = CGPoint(x: 330, y: 36)
        static let bath = CGPoint(x: 180, y: 64)
    }

    /// Set by the hosting view; may arrive after `didMove`, so it re-applies saved decor.
    weak var store: GameStore? {
        didSet {
            guard isBuilt else { return }
            applyDecor()
            refreshLitter()
            refreshWater()
            if store?.state.cat.isSleeping == true, cat.animation != .sleep { setSleeping(true, animated: false) }
            refreshLighting(animated: false)
        }
    }
    /// While true, strokes over the cat brush it instead of petting.
    var isBrushing = false

    private let world = SKNode()
    private let cat = CatNode()
    private let foodBowl = SKSpriteNode(texture: SpriteLibrary.texture("bowl_empty"))
    private let litterBox = SKSpriteNode(texture: SpriteLibrary.texture("litter_clean"))
    private let waterBowl = SKSpriteNode(texture: SpriteLibrary.texture("bowl_water"))
    private let backdrop = RoomBackdrop()
    private let attentionBubble = SKSpriteNode()
    private let tvScreen = SKSpriteNode()
    private weak var friendNode: CatNode?
    /// Furniture nodes driven by decoration slots.
    private var furniture: [DecorSlot: SKSpriteNode] = [:]
    private let nightOverlay = SKSpriteNode(color: SKColor(red: 0.08, green: 0.07, blue: 0.25, alpha: 1), size: RoomScene.roomSize)
    private var isBuilt = false
    private var lastUpdate: TimeInterval = 0
    private var nextDecisionAt: TimeInterval = 0
    private var nextLightingCheck: TimeInterval = 0
    /// Touch tracking for tap vs. stroke petting.
    private var touchStartedOnCat = false
    private var strokeTravel: CGFloat = 0
    private var didStroke = false
    private var lastTouchPoint: CGPoint = .zero
    private let haptics = UIImpactFeedbackGenerator(style: .soft)

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

        place(foodBowl, at: Spot.foodBowl)
        place(waterBowl, at: Spot.waterBowl)
        tvScreen.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tvScreen.position = CGPoint(x: Spot.tv.x, y: Spot.tv.y + 44) // screen center: 22 logical px above the TV's base
        tvScreen.zPosition = depth(for: Spot.tv.y) - 0.5
        world.addChild(tvScreen)
        for (slot, spot) in [(DecorSlot.bed, Spot.bed), (.post, Spot.scratchingPost), (.plant, Spot.plant), (.toy, Spot.yarn), (.tv, Spot.tv)] {
            let node = SKSpriteNode()
            furniture[slot] = node
            place(node, at: spot)
        }
        place(litterBox, at: Spot.litter)
        refreshLitter()
        refreshWater()
        applyDecor()

        cat.position = Spot.catStart
        cat.look = store?.state.cat.look ?? CatLook()
        world.addChild(cat)

        nightOverlay.anchorPoint = .zero
        nightOverlay.size = CGSize(width: Self.roomSize.width + 2 * Self.artPadding.width,
                                   height: Self.roomSize.height + 2 * Self.artPadding.height)
        nightOverlay.position = CGPoint(x: -Self.artPadding.width, y: -Self.artPadding.height)
        nightOverlay.alpha = 0
        nightOverlay.zPosition = 2000
        world.addChild(nightOverlay)

        layoutWorld()
        if store?.state.cat.isSleeping == true { setSleeping(true, animated: false) }
        refreshLighting(animated: false)
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
        if currentTime >= nextLightingCheck {
            nextLightingCheck = currentTime + 30
            refreshLighting(animated: true)
        }
        guard let store, !cat.isScripted, !store.state.cat.isSleeping,
              cat.action(forKey: "move") == nil, currentTime >= nextDecisionAt else { return }
        decideNextBehavior(mood: store.mood)
    }

    override func didFinishUpdate() {
        // Keep the moving container smooth but draw the sprite on whole art pixels.
        cat.sprite.position = CGPoint(x: cat.position.x.rounded() - cat.position.x,
                                      y: cat.position.y.rounded() - cat.position.y)
        cat.zPosition = depth(for: cat.position.y)
        if let friend = friendNode {
            friend.sprite.position = CGPoint(x: friend.position.x.rounded() - friend.position.x,
                                             y: friend.position.y.rounded() - friend.position.y)
            friend.zPosition = depth(for: friend.position.y)
        }
    }

    private func decideNextBehavior(mood: Mood) {
        let walkChance: Double
        switch mood {
        case .excited: walkChance = 0.8
        case .sleepy: walkChance = 0.15
        case .sad, .hungry, .bored: walkChance = 0.3
        case .sick: walkChance = 0.05
        case .happy, .neutral: walkChance = 0.5
        }
        cat.setTailMood(TailMood(mood))
        if mood != .sleepy, mood != .sick, Double.random(in: 0...1) < store?.balance.scratchChance ?? 0 {
            goScratch()
        } else if Double.random(in: 0...1) < walkChance {
            cat.walk(to: randomFloorPoint())
        } else {
            cat.play([.sad, .hungry, .sick].contains(mood) ? .sad : .idle)
        }
        refreshAttention()
        nextDecisionAt = lastUpdate + .random(in: 2.5...5.5)
    }

    private func randomFloorPoint() -> CGPoint {
        CGPoint(x: .random(in: Self.walkArea.minX...Self.walkArea.maxX).rounded(),
                y: .random(in: Self.walkArea.minY...Self.walkArea.maxY).rounded())
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchPoint = touch.location(in: world)
        touchStartedOnCat = cat.hitFrame.contains(lastTouchPoint)
        strokeTravel = 0
        didStroke = false
        if touchStartedOnCat { haptics.prepare() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchStartedOnCat, let touch = touches.first, let store else { return }
        let point = touch.location(in: world)
        defer { lastTouchPoint = point }
        // Only movement over the cat counts as stroking.
        guard cat.hitFrame.insetBy(dx: -16, dy: -16).contains(point) else { return }
        strokeTravel += hypot(point.x - lastTouchPoint.x, point.y - lastTouchPoint.y)
        if strokeTravel >= CGFloat(store.balance.strokeDistance) {
            strokeTravel = 0
            didStroke = true
            if isBrushing { handleBrush(store.brush()) } else { handlePet(store.pet(.stroke), stroke: true) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let store else { return }
        let point = touch.location(in: world)
        if touchStartedOnCat {
            if !didStroke && !isBrushing { handlePet(store.pet(.tap), stroke: false) }
        } else if !cat.isScripted, !store.state.cat.isSleeping, postFrame.contains(point) {
            goScratch()
        } else if !cat.isScripted, !store.state.cat.isSleeping, Self.walkArea.insetBy(dx: -24, dy: -16).contains(point) {
            let target = CGPoint(x: min(max(point.x, Self.walkArea.minX), Self.walkArea.maxX).rounded(),
                                 y: min(max(point.y, Self.walkArea.minY), Self.walkArea.maxY).rounded())
            cat.walk(to: target)
            nextDecisionAt = lastUpdate + 4
        }
        touchStartedOnCat = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartedOnCat = false
    }

    private func handlePet(_ result: ActionResult, stroke: Bool) {
        switch result {
        case .ok:
            if stroke { haptics.impactOccurred(intensity: 0.6) }
            AudioManager.shared.play(stroke ? .purr : .meow)
            guard !cat.isScripted else { spawnHearts(); return }
            cat.stopMoving()
            cat.react(.happy, duration: stroke ? 2 : 1)
            if stroke { spawnHearts() } else { spawnEffect("fx_heart", offsetY: 56) }
            nextDecisionAt = lastUpdate + 3
        case .noReward:
            // Too much petting at once: a short, annoyed tail flick.
            cat.flashTail(.annoyed, duration: 1.2)
        case .sleeping:
            spawnEffect("fx_zzz", offsetY: 36)
        case .busy, .outOfStock, .unknownItem, .tooSoon, .insufficientCoins, .tooTired, .locked, .alreadyOwned:
            break
        }
    }

    private func handleBrush(_ result: ActionResult) {
        switch result {
        case .ok:
            haptics.impactOccurred(intensity: 0.4)
            AudioManager.shared.play(.purr)
            cat.stopMoving()
            cat.react(.happy, duration: 1.2)
            spawnEffect("fx_sparkle", offsetY: 40, dx: .random(in: -16...16))
            nextDecisionAt = lastUpdate + 3
        case .noReward:
            cat.react(.happy, duration: 0.6)
        default:
            break
        }
    }

    // MARK: Scripted sequences

    /// Runs after `GameStore.bathe` succeeded: walk to the tub spot, splash, sparkle.
    func playBath() {
        cancelScript()
        cat.isScripted = true
        cat.walk(to: Spot.bath) { [weak self] in
            guard let self else { return }
            let tub = SKSpriteNode(texture: SpriteLibrary.texture("bath_tub"))
            tub.anchorPoint = CGPoint(x: 0.5, y: 0)
            tub.position = CGPoint(x: Spot.bath.x, y: Spot.bath.y - 6)
            tub.zPosition = self.depth(for: Spot.bath.y) + 1 // in front of the cat
            tub.name = "tub"
            self.world.addChild(tub)
            self.cat.play(.happy)
            self.cat.flashTail(.annoyed, duration: 3.5) // cats tolerate baths, they don't love them
            AudioManager.shared.play(.splash)
            let bubbles = SKAction.repeat(.sequence([.run { [weak self] in
                self?.spawnEffect("fx_bubble", offsetY: .random(in: 24...48), dx: .random(in: -24...24))
            }, .wait(forDuration: 0.25)]), count: 14)
            self.run(.sequence([bubbles, .run { [weak self] in
                guard let self else { return }
                tub.removeFromParent()
                self.cat.isScripted = false
                self.cat.react(.happy, duration: 1)
                for i in 0..<3 { self.spawnEffect("fx_sparkle", offsetY: 30 + CGFloat(i) * 8, dx: CGFloat([-14, 0, 14][i])) }
                self.nextDecisionAt = self.lastUpdate + 2
            }]), withKey: "script")
        }
    }

    func playVet() {
        AudioManager.shared.play(.meow)
        cat.stopMoving()
        cat.react(.happy, duration: 1.5)
        spawnHearts()
        nextDecisionAt = lastUpdate + 3
    }

    /// Re-reads equipped decorations and the cat's coat. Slots are fixed, so the walk area never changes.
    func applyDecor() {
        guard let store else { return }
        let decor = store.state.decor
        backdrop.apply(decor)
        for (slot, node) in furniture {
            let item = decor.equipped(slot)
            node.isHidden = item.isEmpty
            guard !item.isEmpty else { continue }
            let texture = SpriteLibrary.texture(item.id)
            node.texture = texture
            node.size = texture.size()
        }
        tvScreen.isHidden = decor.equipped(.tv).isEmpty
        if tvScreen.action(forKey: "channel") == nil { tvScreen.texture = SpriteLibrary.texture("tv_off"); tvScreen.size = CGSize(width: 48, height: 32) }
        cat.look = store.state.cat.look
    }

    private var postFrame: CGRect { furniture[.post]?.frame.insetBy(dx: -8, dy: -8) ?? .null }

    /// Walk to the post and scratch it for a few seconds. Purely cosmetic if the reward is on cooldown.
    func goScratch() {
        guard let store, !cat.isScripted, !store.state.cat.isSleeping else { return }
        cat.isScripted = true
        cat.walk(to: Spot.scratch) { [weak self] in
            guard let self else { return }
            self.cat.face(towardX: Spot.scratchingPost.x)
            self.cat.play(.scratch)
            self.cat.flashTail(.happy, duration: 2.5)
            let rewarded = self.store?.scratchPost() == .ok
            self.run(.sequence([.wait(forDuration: 2.5), .run { [weak self] in
                guard let self else { return }
                self.cat.isScripted = false
                self.cat.play(.idle)
                if rewarded { self.spawnHearts() }
                self.nextDecisionAt = self.lastUpdate + 3
            }]), withKey: "script")
        }
    }

    /// A friend walks in, the cats greet and chase a little, then the friend leaves. ~14 s.
    func playFriendVisit(look: CatLook) {
        cancelScript()
        cat.isScripted = true
        let friend = CatNode()
        friend.look = look
        friend.setTailMood(.happy)
        friend.position = CGPoint(x: -40, y: 70)
        world.addChild(friend)
        let meet = CGPoint(x: 150, y: 70)
        friend.walk(to: meet)
        cat.walk(to: CGPoint(x: meet.x + 44, y: meet.y)) { [weak self] in
            guard let self else { return }
            self.cat.face(towardX: meet.x)
            friend.face(towardX: self.cat.position.x)
        }
        let greet = SKAction.run { [weak self] in
            self?.cat.react(.happy, duration: 2)
            friend.react(.happy, duration: 2)
            self?.spawnHearts()
            AudioManager.shared.play(.meow)
        }
        let chase = SKAction.run { [weak self] in
            guard let self else { return }
            let spot = self.randomFloorPoint()
            friend.walk(to: spot)
            self.cat.walk(to: CGPoint(x: spot.x + 36, y: spot.y))
        }
        let leave = SKAction.run { friend.walk(to: CGPoint(x: -60, y: 70)) { friend.removeFromParent() } }
        let done = SKAction.run { [weak self] in
            self?.cat.isScripted = false
            self?.cat.play(.idle)
        }
        run(.sequence([.wait(forDuration: 3.5), greet, .wait(forDuration: 2.5), chase, .wait(forDuration: 3),
                       chase, .wait(forDuration: 3), leave, .wait(forDuration: 2), done]), withKey: "script")
        friendNode = friend
    }

    /// The cat sits in front of the TV while a channel plays (~12 s).
    func playTV(channel: String) {
        cancelScript()
        cat.isScripted = true
        let frames = SpriteLibrary.textures((0..<4).map { "tv_\(channel)_\($0)" })
        tvScreen.run(.repeatForever(.animate(with: frames, timePerFrame: 0.25)), withKey: "channel")
        cat.walk(to: Spot.watchTV) { [weak self] in
            guard let self else { return }
            self.cat.play(.idle)
            self.cat.setTailMood(.happy)
            let cheer = SKAction.run { [weak self] in self?.cat.react(.happy, duration: 1.2); AudioManager.shared.play(.meow) }
            self.run(.sequence([.wait(forDuration: 3), cheer, .wait(forDuration: 4), cheer, .wait(forDuration: 4), .run { [weak self] in
                guard let self else { return }
                self.tvScreen.removeAction(forKey: "channel")
                self.tvScreen.texture = SpriteLibrary.texture("tv_off")
                self.cat.isScripted = false
                self.spawnHearts()
            }]), withKey: "script")
        }
    }

    /// Bowl art follows the water level; after a refresh the cat comes for a drink.
    func refreshWater(drink: Bool = false) {
        waterBowl.texture = SpriteLibrary.texture(store?.isWaterLow == true ? "bowl_empty" : "bowl_water")
        guard drink, !cat.isScripted, store?.state.cat.isSleeping == false else { return }
        cat.isScripted = true
        cat.walk(to: Spot.drink) { [weak self] in
            guard let self else { return }
            self.cat.face(towardX: Spot.waterBowl.x)
            self.cat.play(.eat)
            self.run(.sequence([.wait(forDuration: 2), .run { [weak self] in
                self?.cat.isScripted = false
                self?.cat.react(.happy, duration: 1)
            }]), withKey: "script")
        }
    }

    /// Renders the room (without the HUD) as a crisp image, upscaled 3x with nearest-neighbor.
    func snapshot() -> UIImage? {
        guard let view, let texture = view.texture(from: self) else { return nil }
        let cg = texture.cgImage()
        let size = CGSize(width: cg.width * 3, height: cg.height * 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: size))
        }
    }

    /// Thought bubble over the cat: "!" for a low need, a red cross when unwell.
    func refreshAttention() {
        let name: String?
        switch store?.attention {
        case .needsCare: name = "fx_alert"
        case .unwell: name = "fx_sick"
        case nil: name = nil
        }
        if let name {
            if attentionBubble.parent == nil {
                attentionBubble.position = CGPoint(x: 18, y: 62)
                attentionBubble.zPosition = 10
                cat.addChild(attentionBubble)
                attentionBubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.6), .moveBy(x: 0, y: -3, duration: 0.6)])))
            }
            attentionBubble.texture = SpriteLibrary.texture(name)
            attentionBubble.size = attentionBubble.texture?.size() ?? .zero
        } else {
            attentionBubble.removeFromParent()
        }
    }

    func refreshLitter(sparkle: Bool = false) {
        litterBox.texture = SpriteLibrary.texture(store?.isLitterDirty == true ? "litter_dirty" : "litter_clean")
        guard sparkle else { return }
        AudioManager.shared.play(.find)
        let node = SKSpriteNode(texture: SpriteLibrary.texture("fx_sparkle"))
        node.position = CGPoint(x: Spot.litter.x, y: Spot.litter.y + 28)
        node.zPosition = 2100
        world.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 16, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
    }

    /// Runs after `GameStore.feed` succeeded. Stats are already applied, so cancelling this is harmless.
    func playFeeding() {
        cancelScript()
        cat.isScripted = true
        foodBowl.texture = SpriteLibrary.texture("bowl_food")
        cat.walk(to: Spot.eat) { [weak self] in
            guard let self else { return }
            self.cat.face(towardX: Spot.foodBowl.x)
            self.cat.play(.eat)
            AudioManager.shared.play(.eat)
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
            refreshLighting(animated: animated, sleeping: true)
            let lieDown = { [weak self] in
                guard let self else { return }
                self.cat.play(.sleep)
                self.run(.repeatForever(.sequence([.run { [weak self] in self?.spawnEffect("fx_zzz", offsetY: 40) },
                                                   .wait(forDuration: 1.6)])), withKey: "script")
            }
            if animated { cat.walk(to: Spot.sleep, completion: lieDown) } else { cat.position = Spot.sleep; lieDown() }
        } else {
            refreshLighting(animated: animated, sleeping: false)
            cat.isScripted = false
            cat.react(.happy, duration: 0.8)
            nextDecisionAt = lastUpdate + 1.5
        }
    }

    /// Room light follows the local clock; a sleeping cat dims it further.
    private func refreshLighting(animated: Bool, sleeping: Bool? = nil) {
        let isSleeping = sleeping ?? store?.state.cat.isSleeping ?? false
        let ambient = DayCycle.darkness(for: DayCycle.phase(at: Date()))
        let target = CGFloat(isSleeping ? max(ambient, DayCycle.sleepingDarkness) : ambient)
        guard abs(nightOverlay.alpha - target) > 0.01 else { return }
        nightOverlay.removeAction(forKey: "light")
        nightOverlay.run(.fadeAlpha(to: target, duration: animated ? 1.2 : 0), withKey: "light")
    }

    private func cancelScript() {
        removeAction(forKey: "script")
        friendNode?.removeFromParent()
        world.childNode(withName: "tub")?.removeFromParent()
        cat.stopMoving()
        foodBowl.texture = SpriteLibrary.texture("bowl_empty")
        cat.isScripted = false
    }

    // MARK: Effects

    private func spawnHearts() {
        for i in 0..<3 {
            run(.wait(forDuration: Double(i) * 0.18)) { [weak self] in
                self?.spawnEffect("fx_heart", offsetY: 56, dx: CGFloat([-12, 4, 16][i]))
            }
        }
    }

    private func spawnEffect(_ name: String, offsetY: CGFloat, dx: CGFloat = 8) {
        let node = SKSpriteNode(texture: SpriteLibrary.texture(name))
        node.position = CGPoint(x: cat.position.x.rounded() + dx, y: cat.position.y.rounded() + offsetY)
        node.zPosition = 2100
        world.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 1), .fadeOut(withDuration: 1)]), .removeFromParent()]))
    }
}
