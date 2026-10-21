import Foundation
import Observation
import SwiftData
import os

enum ActionResult: Equatable {
    case ok
    /// Accepted but no reward (cooldown or hourly limit reached).
    case noReward
    case busy
    case sleeping
    case outOfStock
    case unknownItem
}

/// Single source of truth for game state. All mutations go through here so they are validated and saved.
@Observable
@MainActor
final class GameStore {
    private(set) var state: GameState
    /// Set when the save could not be read; the UI tells the player instead of silently resetting.
    var loadIssue: SaveStoreError?
    /// Increments on every level up so views can react.
    private(set) var levelUpCount = 0
    var tutorialStep: TutorialStep?

    let balance: Balance
    private let saveStore: SaveStore
    private let clock: () -> Date
    @ObservationIgnored private var busyUntil = Date.distantPast
    private let log = Logger(subsystem: "Meowchi", category: "GameStore")

    init(saveStore: SaveStore, balance: Balance = .standard, clock: @escaping () -> Date = Date.init) {
        self.saveStore = saveStore
        self.balance = balance
        self.clock = clock
        let now = clock()
        do {
            state = try saveStore.load() ?? .newGame(now: now, balance: balance)
        } catch {
            state = .newGame(now: now, balance: balance)
            loadIssue = error as? SaveStoreError ?? .corrupted
        }
        CatSimulator.advance(&state, to: now, balance: balance)
        save()
    }

    static func makeDefault() -> GameStore {
        do {
            let container = try ModelContainer(for: SaveRecord.self)
            return GameStore(saveStore: SwiftDataSaveStore(container: container))
        } catch {
            let store = GameStore(saveStore: InMemorySaveStore())
            store.loadIssue = .corrupted
            return store
        }
    }

    var mood: Mood { CatSimulator.mood(for: state.cat) }
    var isBusy: Bool { clock() < busyUntil }

    // MARK: Simulation

    func tick() {
        CatSimulator.advance(&state, to: clock(), balance: balance)
        save()
    }

    // MARK: Actions

    @discardableResult
    func feed(_ itemID: String) -> ActionResult {
        guard let item = ItemCatalog.food(itemID) else { return .unknownItem }
        let now = clock()
        CatSimulator.advance(&state, to: now, balance: balance)
        guard !state.cat.isSleeping else { return .sleeping }
        guard now >= busyUntil else { return .busy }
        guard let count = state.inventory[itemID], count > 0 else { return .outOfStock }

        // Apply atomically before any animation so an interrupted animation cannot double-consume.
        state.inventory[itemID] = count - 1 > 0 ? count - 1 : nil
        state.cat.stats[.hunger] += item.hunger
        state.cat.stats[.happiness] += item.happiness
        busyUntil = now.addingTimeInterval(balance.feedDurationSeconds)
        grantXP(item.xp)
        if tutorialStep == .feed { tutorialStep = .pet }
        save()
        return .ok
    }

    @discardableResult
    func pet(_ kind: PetKind = .tap) -> ActionResult {
        let now = clock()
        CatSimulator.advance(&state, to: now, balance: balance)
        guard !state.cat.isSleeping else { return .sleeping }
        var petLog = state.petLog
        if now.timeIntervalSince(petLog.windowStart) >= 3600 || now < petLog.windowStart {
            petLog.windowStart = now
            petLog.rewardedCount = 0
        }
        let cooledDown = petLog.lastPetAt.map { now.timeIntervalSince($0) >= balance.petCooldownSeconds || now < $0 } ?? true
        petLog.lastPetAt = now
        guard cooledDown, petLog.rewardedCount < balance.maxRewardedPetsPerHour else {
            state.petLog = petLog
            return .noReward
        }
        petLog.rewardedCount += 1
        state.petLog = petLog
        state.cat.stats[.happiness] += kind == .stroke ? balance.petHappiness : balance.tapHappiness
        grantXP(balance.petXP)
        if tutorialStep == .pet { tutorialStep = .done }
        save()
        return .ok
    }

    @discardableResult
    func setSleeping(_ sleeping: Bool) -> ActionResult {
        let now = clock()
        CatSimulator.advance(&state, to: now, balance: balance)
        guard now >= busyUntil else { return .busy }
        guard state.cat.isSleeping != sleeping else { return .ok }
        state.cat.isSleeping = sleeping
        save()
        return .ok
    }

    // MARK: Onboarding

    var needsOnboarding: Bool { state.onboardedAt == nil }

    func completeOnboarding(name: String) {
        state.cat.name = CatState.sanitizedName(name, maxLength: balance.maxNameLength) ?? state.cat.name
        state.onboardedAt = clock()
        tutorialStep = .feed
        save()
    }

    func quantity(of itemID: String) -> Int { state.inventory[itemID] ?? 0 }

    /// First food in catalog order the player owns, if any.
    var firstAvailableFood: FoodItem? { ItemCatalog.foods.first { quantity(of: $0.id) > 0 } }

    // MARK: Progression

    private func grantXP(_ amount: Int) {
        guard amount > 0 else { return }
        state.progression.xp += amount
        while state.progression.xp >= balance.xpRequired(forLevel: state.progression.level) {
            state.progression.xp -= balance.xpRequired(forLevel: state.progression.level)
            state.progression.level += 1
            state.coins += balance.levelUpCoins
            levelUpCount += 1
        }
    }

    // MARK: Persistence

    func save() {
        do {
            try saveStore.save(state)
        } catch {
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
