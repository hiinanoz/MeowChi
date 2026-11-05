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
