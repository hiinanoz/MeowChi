import SwiftData
import XCTest
@testable import Meowchi

@MainActor
final class GameStoreTests: XCTestCase {
    private final class TestClock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var clock = TestClock()

    private func makeStore(_ saveStore: SaveStore = InMemorySaveStore(), balance: Balance = .standard) -> GameStore {
        let clock = clock
        return GameStore(saveStore: saveStore, balance: balance, clock: { clock.now })
    }

    func testFirstLaunchCreatesNewGame() {
        let store = makeStore()
        XCTAssertEqual(store.state.coins, Balance.standard.startingCoins)
        XCTAssertNil(store.loadIssue)
    }

    func testFeedConsumesOneItemAndBlocksRapidRepeats() {
        let store = makeStore()
        let before = store.quantity(of: "food.dry")
        XCTAssertEqual(store.feed("food.dry"), .ok)
        XCTAssertEqual(store.feed("food.dry"), .busy)
        XCTAssertEqual(store.quantity(of: "food.dry"), before - 1)
        clock.advance(Balance.standard.feedDurationSeconds)
        XCTAssertEqual(store.feed("food.dry"), .ok)
        XCTAssertEqual(store.quantity(of: "food.dry"), before - 2)
    }

    func testFeedWithoutInventory() {
        var balance = Balance.standard
        balance.startingInventory = [:]
        let store = makeStore(balance: balance)
        XCTAssertEqual(store.feed("food.dry"), .outOfStock)
        XCTAssertEqual(store.feed("food.unknown"), .unknownItem)
        XCTAssertNil(store.firstAvailableFood)
    }

    func testCannotFeedSleepingCat() {
        let store = makeStore()
        store.setSleeping(true)
        XCTAssertEqual(store.feed("food.dry"), .sleeping)
    }

    func testPetCooldownAndHourlyLimit() {
        let balance = Balance.standard
        let store = makeStore()
        XCTAssertEqual(store.pet(), .ok)
        XCTAssertEqual(store.pet(), .noReward)
        for _ in 1..<balance.maxRewardedPetsPerHour {
            clock.advance(balance.petCooldownSeconds)
            XCTAssertEqual(store.pet(), .ok)
        }
        clock.advance(balance.petCooldownSeconds)
        XCTAssertEqual(store.pet(), .noReward)
        clock.advance(3600)
        XCTAssertEqual(store.pet(), .ok)
    }

    func testLevelUpCarriesOverXPAndGrantsCoins() {
        var balance = Balance.standard
        balance.baseXPPerLevel = 2
        balance.xpGrowthPerLevel = 0
        balance.petXP = 5
        let store = makeStore(balance: balance)
        store.pet()
        XCTAssertEqual(store.state.progression.level, 3)
        XCTAssertEqual(store.state.progression.xp, 1)
        XCTAssertEqual(store.state.coins, balance.startingCoins + 2 * balance.levelUpCoins)
    }

    func testProgressSurvivesRelaunch() {
        let save = InMemorySaveStore()
        let first = makeStore(save)
        first.feed("food.dry")
        let second = makeStore(save)
        XCTAssertEqual(second.state.inventory, first.state.inventory)
        XCTAssertEqual(second.state.progression, first.state.progression)
    }

    func testSwiftDataStoreRecoversFromBackupAndQuarantinesGarbage() throws {
        let container = try ModelContainer(for: SaveRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let saveStore = SwiftDataSaveStore(container: container)
        var state = GameState.newGame(now: clock.now, balance: .standard)
        try saveStore.save(state)
        state.coins = 999
        try saveStore.save(state)

        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<SaveRecord>()).first)
        record.payload = Data("garbage".utf8)
        try context.save()
        // Fresh stores read through new contexts, like a relaunch.
        XCTAssertEqual(try SwiftDataSaveStore(container: container).load()?.coins, Balance.standard.startingCoins, "falls back to backup")

        record.backupPayload = Data("garbage".utf8)
        try context.save()
        XCTAssertThrowsError(try SwiftDataSaveStore(container: container).load()) { XCTAssertEqual($0 as? SaveStoreError, .corrupted) }
        let slots = try ModelContext(container).fetch(FetchDescriptor<SaveRecord>()).map(\.slot)
        XCTAssertTrue(slots.contains { $0.hasPrefix("quarantine.") })
    }

    func testCodecRejectsFutureVersions() throws {
        let data = Data(#"{"version": 99, "state": {}}"#.utf8)
        XCTAssertThrowsError(try SaveCodec.decode(data)) { XCTAssertEqual($0 as? SaveStoreError, .unsupportedVersion(99)) }
    }
}
