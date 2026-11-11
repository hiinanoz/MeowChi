import XCTest
@testable import Meowchi

@MainActor
final class WishDiaryTests: XCTestCase {
    private final class TestClock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    func testWishAppearsAfterIntervalAndPetGrantsIt() {
        let clock = TestClock()
        let store = GameStore(saveStore: InMemorySaveStore(), clock: { clock.now })
        store.completeOnboarding(name: "Mochi")
        store.tutorialStep = nil
        XCTAssertEqual(store.state.diary.first?.kind, "adopted")
        XCTAssertNil(store.state.wish)
        clock.advance(Balance.standard.wishIntervalHours * 3600 + 1)
        store.debugRefill()
        store.tick()
        // Force a wish we can grant, then grant it.
        var state = store.state
        state.wish = CatWish(kind: .event(.petted), expiresAt: clock.now.addingTimeInterval(3600))
        let wishStore = GameStore(saveStore: InMemorySaveStore(state: state), clock: { clock.now })
        let coins = wishStore.state.coins
        XCTAssertEqual(wishStore.pet(), .ok)
        XCTAssertNil(wishStore.state.wish)
        XCTAssertEqual(wishStore.wishGrantedCount, 1)
        XCTAssertGreaterThanOrEqual(wishStore.state.coins, coins + Balance.standard.wishCoins)
        XCTAssertEqual(wishStore.state.diary.first?.kind, "wish")
    }

    func testExpiredWishGoesAway() {
        let clock = TestClock()
        var state = GameState.newGame(now: clock.now, balance: .standard)
        state.onboardedAt = clock.now
        state.lastWishAt = clock.now
        state.wish = CatWish(kind: .event(.walked), expiresAt: clock.now.addingTimeInterval(60))
        let store = GameStore(saveStore: InMemorySaveStore(state: state), clock: { clock.now })
        clock.advance(120)
        store.tick()
        XCTAssertNil(store.state.wish)
    }

    func testDiaryIsCapped() {
        let store = GameStore(saveStore: InMemorySaveStore())
        for _ in 0..<(Balance.standard.diaryLimit + 10) { store.completeOnboarding(name: "Mochi") }
        XCTAssertEqual(store.state.diary.count, Balance.standard.diaryLimit)
    }
}
