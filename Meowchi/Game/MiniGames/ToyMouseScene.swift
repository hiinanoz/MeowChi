import SpriteKit
import UIKit

/// Toy Mouse: a wind-up mouse scurries around the floor on its own. Tap the floor to send the cat
/// there; catching the mouse scores a point and it pops up somewhere else, a little faster.
final class ToyMouseScene: MiniGameScene {
    static let catchRadius: CGFloat = 14
    static let catSpeed: CGFloat = 135
    static let mouseSpeed: CGFloat = 55
    static let mouseSpeedPerPoint: CGFloat = 4
    static let maxMouseSpeed: CGFloat = 115

    private let mouse = SKSpriteNode(texture: SpriteLibrary.texture("toy_mouse"))
    private var mouseTarget = CGPoint.zero
    private var catTarget: CGPoint?

    override func didBuild() {
        mouse.zPosition = 1500
        world.addChild(mouse)
        resetPlay()
    }

    override func resetPlay() {
        catTarget = nil
        placeMouse()
    }

    private func randomFloorPoint() -> CGPoint {
        CGPoint(x: .random(in: playArea.minX...playArea.maxX), y: .random(in: playArea.minY...playArea.maxY))
    }

    /// Puts the mouse somewhere not too close to the cat.
    private func placeMouse() {
        var p = randomFloorPoint()
        for _ in 0..<8 where hypot(p.x - cat.position.x, p.y - cat.position.y) < 90 { p = randomFloorPoint() }
        mouse.position = p
        mouseTarget = randomFloorPoint()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let touch = touches.first else { return }
        prepareHaptics()
        catTarget = clamped(touch.location(in: world))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let touch = touches.first else { return }
        catTarget = clamped(touch.location(in: world))
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime)
        guard isRunning else { return }
        moveMouse(dt)
        if hypot(mouse.position.x - cat.position.x, mouse.position.y - cat.position.y) <= Self.catchRadius {
            scorePoint()
            catTarget = nil
            placeMouse()
            return
        }
        if let target = catTarget {
            if moveCat(toward: target, speed: Self.catSpeed, dt: dt) <= 0.5 { catTarget = nil }
        } else if cat.animation == .walk {
            cat.play(.idle)
        }
    }

    private func moveMouse(_ dt: CGFloat) {
        let speed = min(Self.maxMouseSpeed, Self.mouseSpeed + CGFloat(score) * Self.mouseSpeedPerPoint)
        let dx = mouseTarget.x - mouse.position.x
        let dy = mouseTarget.y - mouse.position.y
        let distance = hypot(dx, dy)
        if distance < 2 {
            mouseTarget = randomFloorPoint()
            return
        }
        let step = min(distance, speed * dt)
        mouse.position = CGPoint(x: mouse.position.x + dx / distance * step, y: mouse.position.y + dy / distance * step)
        if abs(dx) > 1 { mouse.xScale = dx < 0 ? -1 : 1 }
    }

    override func didFinishUpdate() {
        super.didFinishUpdate()
        mouse.zPosition = 1000 - mouse.position.y + 1
    }
}
