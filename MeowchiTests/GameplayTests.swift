import XCTest
@testable import Meowchi

@MainActor
final class GameplayTests: XCTestCase {
    private final class TestClock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private let clock = TestClock()
    private let balance = Balance.standard
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func makeStore(_ configure: (inout GameState) -> Void = { _ in }) -> GameStore {
        var state = GameState.newGame(now: clock.now, balance: balance)
        configure(&state)
        let clock = clock, calendar = calendar
        return GameStore(saveStore: InMemorySaveStore(state: state), balance: balance,
                         clock: { clock.now }, calendar: { calendar })
    }

    // MARK: Shop

    func testBuyingIsAtomicAndValidated() {
        let store = makeStore { $0.coins = 12; $0.inventory = [:] }
        XCTAssertEqual(store.buy("food.wet"), .ok)
        XCTAssertEqual(store.state.coins, 2)
        XCTAssertEqual(store.quantity(of: "food.wet"), 1)
        XCTAssertEqual(store.buy("food.wet"), .insufficientCoins)
        XCTAssertEqual(store.state.coins, 2, "no partial charge")
        XCTAssertEqual(store.quantity(of: "food.wet"), 1)
        XCTAssertEqual(store.buy("food.unknown"), .unknownItem)
        XCTAssertEqual(store.buy("food.dry", quantity: 0), .unknownItem)
    }

    // MARK: Mini-games

    func testMiniGamePaysEnergyUpFrontAndCapsReward() {
        let store = makeStore { $0.cat.stats.energy = 50 }
        let config = balance.laserChase
        XCTAssertNil(store.finishMiniGame(points: 10), "no reward without a started round")
        XCTAssertEqual(store.startMiniGame(.laserChase), .ok)
        XCTAssertEqual(store.state.cat.stats.energy, 50 - config.energyCost, accuracy: 0.001)
        clock.advance(config.durationSeconds)
        let coinsBefore = store.state.coins
        let reward = store.finishMiniGame(points: 999)
        XCTAssertEqual(reward?.coins, config.maxRewardedPoints * config.coinsPerPoint)
        XCTAssertEqual(store.state.coins, coinsBefore + config.maxRewardedPoints * config.coinsPerPoint)
        XCTAssertNil(store.finishMiniGame(points: 5), "a round pays out once")
    }

    func testImplausibleScoreIsLimitedByPlayTime() {
        let store = makeStore { $0.cat.stats.energy = 50 }
        store.startMiniGame(.laserChase)
        clock.advance(2)
        let reward = store.finishMiniGame(points: 20)
        XCTAssertEqual(reward?.coins, Int(2 / balance.laserChase.minSecondsPerPoint) * balance.laserChase.coinsPerPoint)
    }

    func testTiredCatCannotPlayAndQuittingForfeits() {
        let tired = makeStore { $0.cat.stats.energy = 5 }
        XCTAssertEqual(tired.startMiniGame(.laserChase), .tooTired)
        let store = makeStore { $0.cat.stats.energy = 50 }
        store.startMiniGame(.laserChase)
        store.cancelMiniGame()
        XCTAssertNil(store.finishMiniGame(points: 10))
    }

    // MARK: Daily tasks

    func testDailyTasksAreDeterministicPerDay() {
        let a = DailyTasks.generate(dayKey: "2026-10-28", count: 4)
        XCTAssertEqual(a, DailyTasks.generate(dayKey: "2026-10-28", count: 4))
        XCTAssertEqual(a.tasks.count, 4)
        XCTAssertEqual(Set(a.tasks.map(\.id)).count, 4, "no duplicates")
    }

    func testTasksResetOnNewDayButNotWhenClockGoesBack() {
        let store = makeStore()
        let firstDay = store.state.daily.dayKey
        XCTAssertFalse(firstDay.isEmpty)
        clock.advance(86400)
        store.tick()
        XCTAssertNotEqual(store.state.daily.dayKey, firstDay)
        let secondDay = store.state.daily
        clock.advance(-2 * 86400)
        store.tick()
        XCTAssertEqual(store.state.daily, secondDay)
    }

    func testTaskProgressClaimOnceAndBonus() {
        let pool = DailyTasks.pool
        let store = makeStore {
            $0.daily = DailyTasks(dayKey: DailyTasks.dayKey(for: Date(timeIntervalSince1970: 1_800_000_000), calendar: self.calendar),
                                  tasks: ["task.feed2", "task.litter1"].map { DailyTaskProgress(id: $0) })
            $0.care.litter = 70
        }
        XCTAssertEqual(store.claimTask("task.feed2"), .noReward, "not done yet")
        store.feed("food.dry")
        clock.advance(balance.feedDurationSeconds)
        store.feed("food.dry")
        store.feed("food.dry") // busy, and progress is capped anyway
        XCTAssertEqual(store.state.daily.tasks[0].progress, 2)
        let coins = store.state.coins
        XCTAssertEqual(store.claimTask("task.feed2"), .ok)
        XCTAssertEqual(store.state.coins, coins + pool.first { $0.id == "task.feed2" }!.coins)
        XCTAssertEqual(store.claimTask("task.feed2"), .noReward, "claim once")
        XCTAssertEqual(store.claimDailyBonus(), .noReward, "not all claimed")
        store.cleanLitter()
        XCTAssertEqual(store.claimTask("task.litter1"), .ok)
        XCTAssertEqual(store.claimDailyBonus(), .ok)
        XCTAssertEqual(store.claimDailyBonus(), .noReward)
    }

    func testDailyCheckInCountsDaysAndPaysOncePerDay() {
        let store = makeStore()
        XCTAssertEqual(store.state.login.days, 1)
        let coins = store.state.coins
        XCTAssertEqual(store.claimLogin()?.coins, balance.loginRewards[0].coins)
        XCTAssertEqual(store.state.coins, coins + balance.loginRewards[0].coins)
        XCTAssertNil(store.claimLogin(), "once per day")
        clock.advance(3 * 86400) // missed days don't reset the cycle
        store.tick()
        XCTAssertEqual(store.state.login.days, 2)
        XCTAssertEqual(store.claimLogin()?.coins, balance.loginRewards[1].coins)
        clock.advance(-5 * 86400) // clock set back: no new day
        store.tick()
        XCTAssertFalse(store.canClaimLogin)
    }

    func testHappinessTaskCompletesWhenThresholdReached() {
        let store = makeStore {
            $0.cat.stats.happiness = 78
            $0.daily = DailyTasks(dayKey: DailyTasks.dayKey(for: Date(timeIntervalSince1970: 1_800_000_000), calendar: self.calendar),
                                  tasks: [DailyTaskProgress(id: "task.happy80")])
        }
        XCTAssertEqual(store.state.daily.tasks[0].progress, 0)
        store.pet(.stroke)
        XCTAssertEqual(store.state.daily.tasks[0].progress, 1)
    }
}

@MainActor
final class WalkTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore(energy: Double = 60) -> GameStore {
        var state = GameState.newGame(now: now, balance: .standard)
        state.cat.stats.energy = energy
        let now = now
        return GameStore(saveStore: InMemorySaveStore(state: state), clock: { now })
    }

    func testWalkGenerationIsDeterministicAndInRange() {
        let balance = Balance.standard
        let a = WalkSession.generate(seed: 42, balance: balance)
        XCTAssertEqual(a, WalkSession.generate(seed: 42, balance: balance))
        XCTAssertEqual(a.finds.count, balance.walkFindCount)
        for find in a.finds {
            XCTAssertTrue((0...1).contains(find.x) && (0...1).contains(find.y))
            let config = balance.walkLocations[.garden]!
            if case .coins(let c) = find.reward { XCTAssertTrue(config.coinRange.contains(c)) }
            if case .item(let id) = find.reward { XCTAssertTrue(config.itemPool.contains(id)) }
        }
    }

    func testLocationsUnlockByLevel() {
        let store = makeStore()
        XCTAssertEqual(store.startWalk(.forest), .locked)
        XCTAssertEqual(store.startWalk(.garden), .ok)
        XCTAssertEqual(store.activeWalk?.location, .garden)
        for location in WalkLocation.allCases { XCTAssertNotNil(UIImage(named: location.background), location.background) }
    }

    func testFindsPayOnceAndWalkNeedsEnergy() {
        XCTAssertEqual(makeStore(energy: 5).startWalk(), .tooTired)
        let store = makeStore()
        XCTAssertNil(store.collectFind(0), "no walk yet")
        XCTAssertEqual(store.startWalk(seed: 1), .ok)
        XCTAssertEqual(store.state.cat.stats.energy, 60 - Balance.standard.walkEnergyCost, accuracy: 0.001)
        let coins = store.state.coins
        let reward = store.collectFind(0)
        XCTAssertNotNil(reward)
        XCTAssertNil(store.collectFind(0), "already dug up")
        XCTAssertNil(store.collectFind(99))
        if case .coins(let c) = reward { XCTAssertEqual(store.state.coins, coins + c) }
        let summary = store.finishWalk()
        XCTAssertEqual(summary?.finds.filter(\.collected).count, 1)
        XCTAssertNil(store.activeWalk)
        XCTAssertNil(store.finishWalk(), "finishes once")
    }
}
