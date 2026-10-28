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

@MainActor
final class CareExtrasTests: XCTestCase {
    private final class TestClock { var now = Date(timeIntervalSince1970: 1_800_000_000) }
    private let clock = TestClock()

    private func makeStore(_ configure: (inout GameState) -> Void = { _ in }) -> GameStore {
        var state = GameState.newGame(now: clock.now, balance: .standard)
        configure(&state)
        let clock = clock
        return GameStore(saveStore: InMemorySaveStore(state: state), clock: { clock.now })
    }

    func testWaterDrainsAndLowWaterCostsHappiness() {
        let b = Balance.standard
        var fresh = GameState.newGame(now: clock.now, balance: b)
        var dry = fresh
        dry.care.water = 0
        let later = clock.now.addingTimeInterval(3600)
        CatSimulator.advance(&fresh, to: later, balance: b)
        CatSimulator.advance(&dry, to: later, balance: b)
        XCTAssertEqual(fresh.care.water, 100 - b.waterDrainPerHour, accuracy: 0.001)
        XCTAssertEqual(fresh.cat.stats.happiness - dry.cat.stats.happiness, b.lowWaterHappinessPenaltyPerHour, accuracy: 0.001)
    }

    func testChangeWaterOnlyWhenNotFresh() {
        let store = makeStore { $0.care.water = 95 }
        XCTAssertEqual(store.changeWater(), .noReward)
        let thirsty = makeStore { $0.care.water = 10 }
        XCTAssertTrue(thirsty.isWaterLow)
        XCTAssertEqual(thirsty.changeWater(), .ok)
        XCTAssertEqual(thirsty.state.care.water, 100)
    }

    func testNailsGrowAndTrimOnce() {
        let store = makeStore()
        XCTAssertFalse(store.canTrimNails, "a new kitten's nails are neat")
        XCTAssertEqual(store.trimNails(), .noReward)
        clock.now = clock.now.addingTimeInterval(86400 * 2)
        XCTAssertTrue(store.canTrimNails)
        XCTAssertEqual(store.trimNails(), .ok)
        XCTAssertFalse(store.canTrimNails)
    }

    func testScratchingIsRewardedWithCooldown() {
        let store = makeStore()
        XCTAssertEqual(store.scratchPost(), .ok)
        XCTAssertEqual(store.scratchPost(), .noReward)
        clock.now = clock.now.addingTimeInterval(Balance.standard.scratchCooldownMinutes * 60)
        XCTAssertEqual(store.scratchPost(), .ok)
    }

    func testSickMoodAndAttention() {
        let store = makeStore { $0.cat.stats.health = 30 }
        XCTAssertEqual(store.mood, .sick)
        XCTAssertEqual(store.attention, .unwell)
        let hungry = makeStore { $0.cat.stats.hunger = 15 }
        XCTAssertEqual(hungry.attention, .needsCare)
        XCTAssertNil(makeStore().attention)
    }

    func testOldCareSaveDecodesWithDefaults() throws {
        let care = try JSONDecoder().decode(CareState.self, from: Data(#"{"litter":42}"#.utf8))
        XCTAssertEqual(care.litter, 42)
        XCTAssertEqual(care.water, 100)
        XCTAssertNil(care.lastNailTrimAt)
    }
}

@MainActor
final class FriendTests: XCTestCase {
    func testFriendVisitHasCooldownAndDiffersFromPlayer() {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = GameStore(saveStore: InMemorySaveStore(), clock: { now })
        let (first, friend) = store.inviteFriend(seed: 3)
        XCTAssertEqual(first, .ok)
        XCTAssertNotEqual(friend?.look.coat, store.state.cat.look.coat)
        now = now.addingTimeInterval(60)
        XCTAssertEqual(store.inviteFriend().0, .tooSoon)
        now = now.addingTimeInterval(Balance.standard.friendVisitCooldownHours * 3600)
        XCTAssertEqual(store.inviteFriend().0, .ok)
    }
}

@MainActor
final class TVTests: XCTestCase {
    func testTVNeedsATelevisionAndHasCooldown() {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = GameStore(saveStore: InMemorySaveStore(), clock: { now })
        XCTAssertFalse(store.hasTV)
        XCTAssertEqual(store.watchTV(), .unknownItem)
        store.debugEquip(["tv_retro"])
        XCTAssertEqual(store.watchTV(), .ok)
        now = now.addingTimeInterval(60)
        XCTAssertEqual(store.watchTV(), .tooSoon)
    }
}
