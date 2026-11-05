import SpriteKit
import UIKit

/// Yarn Ball: swipe the ball to toss it across the floor; it rolls, slows down and bounces off the
/// edges while the cat chases it. The cat scores when it catches the ball once it has slowed down;
/// then the ball has to be tossed again before the next point counts.
final class YarnBallScene: MiniGameScene {
    static let catchRadius: CGFloat = 16
    static let catchableSpeed: CGFloat = 60
    static let friction: CGFloat = 1.6        // fraction of speed lost per second
    static let maxThrowSpeed: CGFloat = 420
    static let catSpeed: CGFloat = 115
    static let catSpeedPerPoint: CGFloat = 2

    private let ball = SKSpriteNode(texture: SpriteLibrary.texture("toy_yarn"))
    private var velocity = CGVector.zero
    private var thrown = false
    private var touchSamples: [(point: CGPoint, time: TimeInterval)] = []

    override func didBuild() {
        ball.zPosition = 1500
        world.addChild(ball)
        resetPlay()
    }

    override func resetPlay() {
        velocity = .zero
        thrown = false
        ball.position = CGPoint(x: catStart.x, y: playArea.midY)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let touch = touches.first else { return }
        prepareHaptics()
        touchSamples = [(touch.location(in: world), touch.timestamp)]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let touch = touches.first else { return }
        touchSamples.append((touch.location(in: world), touch.timestamp))
        if touchSamples.count > 6 { touchSamples.removeFirst() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let first = touchSamples.first, let last = touchSamples.last else { return }
        touchSamples = []
        let dt = max(0.016, last.time - first.time)
        var vx = (last.point.x - first.point.x) / dt
        var vy = (last.point.y - first.point.y) / dt
        let speed = hypot(vx, vy)
        guard speed > 80 else { return }
        if speed > Self.maxThrowSpeed {
            vx *= Self.maxThrowSpeed / speed
            vy *= Self.maxThrowSpeed / speed
        }
        velocity = CGVector(dx: vx, dy: vy)
        thrown = true
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime)
        guard isRunning else { return }
        rollBall(dt)
        guard thrown else {
            if cat.animation == .walk { cat.play(.idle) }
            return
        }
        let speed = hypot(velocity.dx, velocity.dy)
        let distance = hypot(ball.position.x - cat.position.x, ball.position.y - cat.position.y)
        if distance <= Self.catchRadius, speed <= Self.catchableSpeed {
            thrown = false
            velocity = .zero
            scorePoint()
            return
        }
        moveCat(toward: ball.position, speed: Self.catSpeed + CGFloat(score) * Self.catSpeedPerPoint, dt: dt)
    }

    private func rollBall(_ dt: CGFloat) {
        guard velocity.dx != 0 || velocity.dy != 0 else { return }
        var p = CGPoint(x: ball.position.x + velocity.dx * dt, y: ball.position.y + velocity.dy * dt)
        if p.x < playArea.minX || p.x > playArea.maxX { velocity.dx = -velocity.dx * 0.7 }
        if p.y < playArea.minY || p.y > playArea.maxY { velocity.dy = -velocity.dy * 0.7 }
        p = clamped(p)
        ball.position = p
        let keep = max(0, 1 - Self.friction * dt)
        velocity = CGVector(dx: velocity.dx * keep, dy: velocity.dy * keep)
        if hypot(velocity.dx, velocity.dy) < 4 { velocity = .zero }
    }

    override func didFinishUpdate() {
        super.didFinishUpdate()
        ball.position = CGPoint(x: ball.position.x.rounded(), y: ball.position.y.rounded())
        ball.zPosition = 1000 - ball.position.y + 1
    }
}
