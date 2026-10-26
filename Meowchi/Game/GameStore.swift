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
    /// On cooldown (bath, vet), try again later.
    case tooSoon
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
        guard state.petLog.consume(at: now, cooldown: balance.petCooldownSeconds,
                                   maxPerHour: balance.maxRewardedPetsPerHour) else { return .noReward }
        state.cat.stats[.happiness] += kind == .stroke ? balance.petHappiness : balance.tapHappiness
        grantXP(balance.petXP)
        if tutorialStep == .pet { tutorialStep = .done }
        save()
        return .ok
    }

    // MARK: Care

    @discardableResult
    func bathe() -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        guard !isOnCooldown(state.care.lastBathAt, hours: balance.bathCooldownHours, now: now) else { return .tooSoon }
        guard state.cat.stats.cleanliness < balance.alreadyCleanThreshold else { return .noReward }
        state.cat.stats[.cleanliness] += balance.bathCleanliness
        state.cat.stats[.happiness] += balance.bathHappiness
        state.cat.stats[.energy] += balance.bathEnergy
        state.care.lastBathAt = now
        busyUntil = now.addingTimeInterval(balance.bathDurationSeconds)
        grantXP(balance.bathXP)
        save()
        return .ok
    }

    /// One brush stroke. Rate-limited like petting.
    @discardableResult
    func brush() -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        guard state.care.brushLog.consume(at: now, cooldown: balance.brushCooldownSeconds,
                                          maxPerHour: balance.maxRewardedBrushesPerHour) else { return .noReward }
        state.cat.stats[.cleanliness] += balance.brushCleanliness
        state.cat.stats[.happiness] += balance.brushHappiness
        grantXP(balance.brushXP)
        save()
        return .ok
    }

    /// Works while the cat sleeps: you clean the box, not the cat.
    @discardableResult
    func cleanLitter() -> ActionResult {
        CatSimulator.advance(&state, to: clock(), balance: balance)
        guard state.care.litter >= 1 else { return .noReward }
        let wasDirty = state.care.litter >= balance.litterDirtyThreshold
        state.care.litter = 0
        if wasDirty { state.cat.stats[.happiness] += balance.litterCleanHappiness }
        grantXP(wasDirty ? balance.litterCleanXP : 1)
        save()
        return .ok
    }

    @discardableResult
    func visitVet() -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        guard !isOnCooldown(state.care.lastVetAt, hours: balance.vetCooldownHours, now: now) else { return .tooSoon }
        guard state.cat.stats.health < balance.alreadyHealthyThreshold else { return .noReward }
        state.cat.stats[.health] += balance.vetHealth
        state.cat.stats[.happiness] += balance.vetHappiness
        state.care.lastVetAt = now
        grantXP(balance.vetXP)
        save()
        return .ok
    }

    var isLitterDirty: Bool { state.care.litter >= balance.litterDirtyThreshold }

    /// Shared preconditions for actions that involve the cat.
    private func careGuard(_ now: Date) -> ActionResult? {
        CatSimulator.advance(&state, to: now, balance: balance)
        if state.cat.isSleeping { return .sleeping }
        if now < busyUntil { return .busy }
        return nil
    }

    /// A timestamp in the future (clock moved back) never blocks the player.
    private func isOnCooldown(_ last: Date?, hours: Double, now: Date) -> Bool {
        guard let last, last <= now else { return false }
        return now.timeIntervalSince(last) < hours * 3600
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
