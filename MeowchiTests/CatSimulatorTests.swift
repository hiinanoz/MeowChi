import XCTest
@testable import Meowchi

final class CatSimulatorTests: XCTestCase {
    private let balance = Balance.standard
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func newState() -> GameState { .newGame(now: start, balance: balance) }

    func testNeedsDecayOverTime() {
        var state = newState()
        CatSimulator.advance(&state, to: start.addingTimeInterval(2 * 3600), balance: balance)
        XCTAssertEqual(state.cat.stats.hunger, balance.startingStats.hunger - 2 * balance.hungerDecayPerHour, accuracy: 0.001)
        XCTAssertEqual(state.cat.stats.energy, balance.startingStats.energy - 2 * balance.energyDecayPerHour, accuracy: 0.001)
        XCTAssertEqual(state.lastSimulatedAt, start.addingTimeInterval(2 * 3600))
    }

    func testClockMovedBackwardsChangesNothing() {
        var state = newState()
        let before = state.cat.stats
        let past = start.addingTimeInterval(-5 * 86400)
        CatSimulator.advance(&state, to: past, balance: balance)
        XCTAssertEqual(state.cat.stats, before)
        XCTAssertEqual(state.lastSimulatedAt, past)
    }

    func testOfflineProgressIsCappedAndFloored() {
        var capped = newState()
        CatSimulator.advance(&capped, to: start.addingTimeInterval(7 * 86400), balance: balance)
        var oneDay = newState()
        CatSimulator.advance(&oneDay, to: start.addingTimeInterval(balance.maxSimulatedHours * 3600), balance: balance)
        XCTAssertEqual(capped.cat.stats, oneDay.cat.stats)
        for kind in [StatKind.hunger, .energy, .happiness, .cleanliness] {
            XCTAssertGreaterThanOrEqual(capped.cat.stats[kind], balance.decayFloor)
        }
        XCTAssertGreaterThanOrEqual(capped.cat.stats.health, balance.healthFloor)
    }

    func testSleepRestoresEnergyAndAutoWakes() {
        var state = newState()
        state.cat.stats.energy = 20
        state.cat.isSleeping = true
        CatSimulator.advance(&state, to: start.addingTimeInterval(1 * 3600), balance: balance)
        XCTAssertEqual(state.cat.stats.energy, 20 + balance.energyRestorePerHourSleeping, accuracy: 0.001)
        XCTAssertTrue(state.cat.isSleeping)
        CatSimulator.advance(&state, to: start.addingTimeInterval(6 * 3600), balance: balance)
        XCTAssertFalse(state.cat.isSleeping)
    }

    func testStatsAreClampedAndRepaired() {
        var stats = CatStats(hunger: 140, energy: -20, happiness: .nan, cleanliness: 50, health: .infinity)
        stats.clamp()
        XCTAssertEqual(stats.hunger, 100)
        XCTAssertEqual(stats.energy, 0)
        XCTAssertEqual(stats.happiness, 50)
        XCTAssertEqual(stats.health, 50)
    }

    func testMoodReflectsNeeds() {
        var cat = newState().cat
        cat.stats.hunger = 10
        XCTAssertEqual(CatSimulator.mood(for: cat), .hungry)
        cat.isSleeping = true
        XCTAssertEqual(CatSimulator.mood(for: cat), .sleepy)
    }
}
