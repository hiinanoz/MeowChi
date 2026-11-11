import XCTest
@testable import Meowchi

@MainActor
final class SeasonAlbumTests: XCTestCase {
    private func date(_ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    func testSeasonsFollowTheCalendar() {
        XCTAssertEqual(Season.current(at: date(12, 20)), .winter)
        XCTAssertEqual(Season.current(at: date(1, 10)), .winter)
        XCTAssertNil(Season.current(at: date(1, 20)))
        XCTAssertEqual(Season.current(at: date(3, 15)), .spring)
        XCTAssertEqual(Season.current(at: date(4, 30)), .spring)
        XCTAssertEqual(Season.current(at: date(8, 1)), .summer)
        XCTAssertNil(Season.current(at: date(10, 1)))
    }

    func testSeasonalDecorOnlySellsInSeason() {
        var state = GameState.newGame(now: date(10, 1), balance: .standard)
        state.coins = 1000
        let october = GameStore(saveStore: InMemorySaveStore(state: state), clock: { self.date(10, 1) })
        XCTAssertEqual(october.buyDecor("plant_xmas"), .locked)
        let december = GameStore(saveStore: InMemorySaveStore(state: state), clock: { self.date(12, 24) })
        XCTAssertEqual(december.buyDecor("plant_xmas"), .ok)
    }

    func testKeepsakeGoesToAlbumAndDuplicatePaysCoins() {
        var balance = Balance.standard
        balance.collectibleChance = 1
        let store = GameStore(saveStore: InMemorySaveStore(), balance: balance)
        store.debugRefill()
        XCTAssertEqual(store.startWalk(.garden, seed: 7), .ok)
        guard case .collectible(let id)? = store.activeWalk?.finds.first?.reward else { return XCTFail("No keepsake") }
        store.collectFind(0)
        XCTAssertTrue(store.state.collectibles.contains(id))
        XCTAssertEqual(store.state.diary.first?.kind, "found")
        let duplicateIndex = store.activeWalk?.finds.firstIndex { $0.reward == .collectible(id) && !$0.collected }
        if let duplicateIndex {
            let coins = store.state.coins
            store.collectFind(duplicateIndex)
            XCTAssertEqual(store.state.coins, coins + balance.duplicateCollectibleCoins)
        }
    }
}
