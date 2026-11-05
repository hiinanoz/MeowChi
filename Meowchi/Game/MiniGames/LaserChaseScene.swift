import SpriteKit
import UIKit

/// Laser Chase: drag to move the laser dot; the cat chases it. Reaching the dot scores a point,
/// then the player has to move the dot away again (`rearmDistance`) before the next point counts.
final class LaserChaseScene: MiniGameScene {
    static let catchRadius: CGFloat = 14
    static let rearmDistance: CGFloat = 70
    static let baseSpeed: CGFloat = 120
    static let speedPerPoint: CGFloat = 3
    static let maxSpeed: CGFloat = 200

    private let laser = SKSpriteNode(texture: SpriteLibrary.texture("fx_laser"))
    private var armed = true
    private var lastCatchPoint = CGPoint.zero

    override func didBuild() {
        laser.zPosition = 2000
        laser.isHidden = true
        world.addChild(laser)
        if !Motion.reduced {
            laser.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
        }
    }

    override func resetPlay() {
        armed = true
        laser.isHidden = true
    }

    private func moveLaser(_ touch: UITouch) {
        guard isRunning else { return }
        let p = clamped(touch.location(in: world))
        laser.position = CGPoint(x: p.x.rounded(), y: p.y.rounded())
        laser.isHidden = false
        if !armed, hypot(laser.position.x - lastCatchPoint.x, laser.position.y - lastCatchPoint.y) >= Self.rearmDistance {
            armed = true
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { prepareHaptics(); moveLaser(touch) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { moveLaser(touch) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime)
        guard isRunning, !laser.isHidden, armed else {
            if cat.animation == .walk { cat.play(.idle) }
            return
        }
        if hypot(laser.position.x - cat.position.x, laser.position.y - cat.position.y) <= Self.catchRadius {
            armed = false
            lastCatchPoint = laser.position
            scorePoint()
            return
        }
        let speed = min(Self.maxSpeed, Self.baseSpeed + CGFloat(score) * Self.speedPerPoint)
        moveCat(toward: laser.position, speed: speed, dt: dt)
    }
}
