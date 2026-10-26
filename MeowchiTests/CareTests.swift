import XCTest
@testable import Meowchi

@MainActor
final class CareTests: XCTestCase {
    private final class TestClock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private let clock = TestClock()
    private let balance = Balance.standard

    private func makeStore(_ configure: (inout GameState) -> Void = { _ in }) -> GameStore {
        var state = GameState.newGame(now: clock.now, balance: balance)
        configure(&state)
        let clock = clock
        return GameStore(saveStore: InMemorySaveStore(state: state), balance: balance, clock: { clock.now })
    }

    func testLitterFillsAndDirtyLitterLowersCleanlinessFaster() {
        var clean = GameState.newGame(now: clock.now, balance: balance)
        var dirty = clean
        dirty.care.litter = 100
        let later = clock.now.addingTimeInterval(3600)
        CatSimulator.advance(&clean, to: later, balance: balance)
        CatSimulator.advance(&dirty, to: later, balance: balance)
        XCTAssertEqual(clean.care.litter, balance.litterFillPerHour, accuracy: 0.001)
        XCTAssertEqual(clean.cat.stats.cleanliness - dirty.cat.stats.cleanliness,
                       balance.dirtyLitterCleanlinessPenaltyPerHour, accuracy: 0.001)
    }

    func testCleaningLitterEmptiesItEvenWhileSleeping() {
        let store = makeStore { $0.care.litter = 80; $0.cat.isSleeping = true; $0.cat.stats.energy = 10 }
        XCTAssertTrue(store.isLitterDirty)
        XCTAssertEqual(store.cleanLitter(), .ok)
        XCTAssertEqual(store.state.care.litter, 0)
        XCTAssertEqual(store.cleanLitter(), .noReward)
    }

    func testBathCooldownAndAlreadyClean() {
        let store = makeStore { $0.cat.stats.cleanliness = 30 }
        XCTAssertEqual(store.bathe(), .ok)
        XCTAssertEqual(store.state.cat.stats.cleanliness, 30 + balance.bathCleanliness, accuracy: 0.001)
        clock.advance(balance.bathDurationSeconds)
        XCTAssertEqual(store.bathe(), .tooSoon)

        let shiny = makeStore { $0.cat.stats.cleanliness = 99 }
        XCTAssertEqual(shiny.bathe(), .noReward)
    }

    func testBrushingIsRateLimited() {
        let store = makeStore { $0.cat.stats.cleanliness = 20 }
        XCTAssertEqual(store.brush(), .ok)
        XCTAssertEqual(store.brush(), .noReward, "cooldown between strokes")
        for _ in 1..<balance.maxRewardedBrushesPerHour {
            clock.advance(balance.brushCooldownSeconds)
            XCTAssertEqual(store.brush(), .ok)
        }
        clock.advance(balance.brushCooldownSeconds)
        XCTAssertEqual(store.brush(), .noReward, "hourly cap")
    }

    func testVetRestoresHealthWithCooldown() {
        let store = makeStore { $0.cat.stats.health = 40 }
        XCTAssertEqual(store.visitVet(), .ok)
        XCTAssertEqual(store.state.cat.stats.health, 40 + balance.vetHealth, accuracy: 0.001)
        XCTAssertEqual(store.visitVet(), .tooSoon)
        clock.advance(balance.vetCooldownHours * 3600)
        store.tick()
        XCTAssertNotEqual(store.visitVet(), .tooSoon)
    }

    func testCooldownIgnoresFutureTimestampsAfterClockRollback() {
        let store = makeStore { $0.cat.stats.health = 40; $0.care.lastVetAt = Date(timeIntervalSince1970: 1_900_000_000) }
        XCTAssertEqual(store.visitVet(), .ok)
    }

    func testCareActionsNeedAnAwakeCat() {
        let store = makeStore { $0.cat.isSleeping = true; $0.cat.stats.energy = 10 }
        XCTAssertEqual(store.bathe(), .sleeping)
        XCTAssertEqual(store.brush(), .sleeping)
        XCTAssertEqual(store.visitVet(), .sleeping)
    }

    func testSaveWithoutCareFieldStillLoads() throws {
        let data = try SaveCodec.encode(GameState.newGame(now: clock.now, balance: balance))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var inner = try XCTUnwrap(json["state"] as? [String: Any])
        inner.removeValue(forKey: "care")
        json["state"] = inner
        let state = try SaveCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(state.care, CareState())
    }
}
