import XCTest
@testable import Meowchi

@MainActor
final class GrowthTests: XCTestCase {
    private let balance = Balance.standard
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    func testStageBoundaries() {
        XCTAssertEqual(CatStage(careDays: 0), .kitten)
        XCTAssertEqual(CatStage(careDays: balance.juniorCareDays - 1), .kitten)
        XCTAssertEqual(CatStage(careDays: balance.juniorCareDays), .junior)
        XCTAssertEqual(CatStage(careDays: balance.adultCareDays - 1), .junior)
        XCTAssertEqual(CatStage(careDays: balance.adultCareDays), .adult)
        XCTAssertEqual(CatStage(careDays: 1000), .adult)
    }

    func testStageModifiersApplyToDecay() {
        var cat = CatState(name: "Mochi", stats: CatStats(hunger: 80, energy: 80, happiness: 80, cleanliness: 80, health: 100),
                           adoptedAt: start)
        var care = CareState()
        var kitten = cat, adult = cat
        CatSimulator.applyStep(&cat, care: &care, hours: 1, balance: balance, stage: .junior)
        care = CareState()
        CatSimulator.applyStep(&kitten, care: &care, hours: 1, balance: balance, stage: .kitten)
        care = CareState()
        CatSimulator.applyStep(&adult, care: &care, hours: 1, balance: balance, stage: .adult)
        XCTAssertEqual(80 - kitten.stats.energy, balance.energyDecayPerHour * balance.kittenEnergyDecayMultiplier, accuracy: 0.001)
        XCTAssertEqual(80 - cat.stats.energy, balance.energyDecayPerHour, accuracy: 0.001)
        XCTAssertEqual(80 - adult.stats.happiness, balance.happinessDecayPerHour * balance.adultHappinessDecayMultiplier, accuracy: 0.001)
        XCTAssertEqual(80 - cat.stats.happiness, balance.happinessDecayPerHour, accuracy: 0.001)
    }

    func testOfflineDaysDontCountAndStageNeverGoesBack() {
        var state = GameState.newGame(now: start, balance: balance)
        state.onboardedAt = start
        state.login.days = balance.juniorCareDays - 1
        state.login.dayKey = DailyTasks.dayKey(for: start, calendar: .current)
        let clock = TestClock(start)
        let store = GameStore(saveStore: InMemorySaveStore(state: state), clock: { clock.now })
        XCTAssertEqual(store.stage, .kitten)
        // Two weeks away is a single new care day, not fourteen.
        clock.advance(14 * 86_400)
        store.tick()
        XCTAssertEqual(store.state.login.days, balance.juniorCareDays)
        XCTAssertEqual(store.stage, .junior)
        XCTAssertEqual(store.stageUpCount, 1)
        // A clock set back never lowers the stage.
        clock.advance(-30 * 86_400)
        store.tick()
        XCTAssertEqual(store.stage, .junior)
    }

    func testKittensEarnBonusXP() {
        var balance = Balance.standard
        balance.baseXPPerLevel = 1000
        balance.petXP = 5
        let store = GameStore(saveStore: InMemorySaveStore(), balance: balance, clock: { self.start })
        XCTAssertEqual(store.stage, .kitten)
        store.pet()
        XCTAssertEqual(store.state.progression.xp, Int((5 * balance.kittenXPMultiplier).rounded()))
    }

    func testOnboardingPicksAPersonality() {
        let store = GameStore(saveStore: InMemorySaveStore(), clock: { self.start })
        store.completeOnboarding(name: "Mochi")
        XCTAssertTrue(Personality.allCases.contains(store.state.cat.personality))
        for personality in Personality.allCases {
            XCTAssertNotNil(balance.personalityWalkMultiplier[personality])
            XCTAssertNotNil(balance.personalityScratchMultiplier[personality])
        }
    }
}
