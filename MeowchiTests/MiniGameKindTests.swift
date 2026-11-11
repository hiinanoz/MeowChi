import XCTest
@testable import Meowchi

@MainActor
final class MiniGameKindTests: XCTestCase {
    func testEveryGameHasAPlayableConfig() {
        for kind in MiniGameKind.allCases {
            let config = kind.config(.standard)
            XCTAssertGreaterThan(config.durationSeconds, 0, kind.rawValue)
            XCTAssertGreaterThan(config.energyCost, 0, kind.rawValue)
            XCTAssertGreaterThanOrEqual(config.minimumEnergy, config.energyCost, kind.rawValue)
            XCTAssertGreaterThan(config.maxRewardedPoints, 0, kind.rawValue)
        }
    }

    func testEveryGameStartsAndPaysEnergy() {
        for kind in MiniGameKind.allCases {
            let store = GameStore(saveStore: InMemorySaveStore())
            store.debugRefill()
            XCTAssertEqual(store.startMiniGame(kind), .ok, kind.rawValue)
            XCTAssertEqual(store.state.cat.stats.energy, 100 - kind.config(.standard).energyCost, accuracy: 0.001, kind.rawValue)
        }
    }
}

@MainActor
final class MiniGameRecordTests: XCTestCase {
    func testStarsAndBestScore() {
        let config = Balance.standard.laserChase
        XCTAssertEqual(config.stars(for: 0), 0)
        XCTAssertEqual(config.stars(for: config.starPoints[0]), 1)
        XCTAssertEqual(config.stars(for: config.starPoints[2] + 5), 3)

        let store = GameStore(saveStore: InMemorySaveStore())
        store.debugRefill()
        store.startMiniGame(.laserChase)
        let first = store.finishMiniGame(points: 3)
        XCTAssertEqual(first?.isNewBest, true)
        XCTAssertEqual(store.state.bestScores["laserChase"], 3)
        store.debugRefill()
        store.startMiniGame(.laserChase)
        let second = store.finishMiniGame(points: 1)
        XCTAssertEqual(second?.isNewBest, false)
        XCTAssertEqual(second?.best, 3)
        XCTAssertEqual(store.state.bestScores["laserChase"], 3)
    }
}
