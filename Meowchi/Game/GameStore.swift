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
    case insufficientCoins
    /// Not enough energy for a mini-game.
    case tooTired
    /// Requires a higher level.
    case locked
    case alreadyOwned
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
    /// True once per launch when the player was away for a while (friendly greeting, never guilt).
    var showWelcomeBack = false
    /// The most recently unlocked badge, for a celebration banner.
    private(set) var lastUnlockedBadge: Badge?

    let balance: Balance
    private let saveStore: SaveStore
    private let clock: () -> Date
    /// Read on every use so a time-zone change is picked up.
    private let calendar: () -> Calendar
    /// The mini-game in progress. Not persisted: quitting the app forfeits the round (energy was already paid).
    @ObservationIgnored private var activeGame: (kind: MiniGameKind, startedAt: Date)?
    /// The garden walk in progress (not persisted; collected finds are already paid out).
    private(set) var activeWalk: WalkSession?
    @ObservationIgnored private var busyUntil = Date.distantPast
    private let log = Logger(subsystem: "Meowchi", category: "GameStore")

    init(saveStore: SaveStore, balance: Balance = .standard, clock: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { .current }) {
        self.saveStore = saveStore
        self.balance = balance
        self.clock = clock
        self.calendar = calendar
        let now = clock()
        do {
            let loaded = try saveStore.load()
            state = loaded ?? .newGame(now: now, balance: balance)
            if let loaded, loaded.onboardedAt != nil,
               now.timeIntervalSince(loaded.lastSimulatedAt) >= balance.welcomeBackHours * 3600 {
                showWelcomeBack = true
            }
        } catch {
            state = .newGame(now: now, balance: balance)
            loadIssue = error as? SaveStoreError ?? .corrupted
        }
        simulate(now)
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

    var mood: Mood { CatSimulator.mood(for: state.cat, balance: balance) }

    /// What the cat's thought bubble shows, if anything: unwell beats a low need.
    var attention: Attention? {
        guard !state.cat.isSleeping else { return nil }
        if state.cat.stats.health < balance.sickThreshold { return .unwell }
        let low = [StatKind.hunger, .cleanliness, .energy, .happiness].contains { state.cat.stats[$0] < balance.attentionThreshold }
        return low || isLitterDirty && state.care.litter >= 90 ? .needsCare : nil
    }

    enum Attention { case needsCare, unwell }
    var isBusy: Bool { clock() < busyUntil }

    // MARK: Simulation

    /// Brings needs and daily tasks up to `now`. Every action calls this first.
    private func simulate(_ now: Date) {
        CatSimulator.advance(&state, to: now, balance: balance)
        let today = DailyTasks.dayKey(for: now, calendar: calendar())
        // Only move forward: a clock set back never re-rolls or resets today's tasks.
        if state.daily.dayKey.isEmpty || today > state.daily.dayKey {
            state.daily = .generate(dayKey: today, count: balance.dailyTaskCount)
        }
        if today > state.login.dayKey {
            state.login.dayKey = today
            state.login.days += 1
        }
    }

    func tick() {
        simulate(clock())
        save()
    }

    // MARK: Actions

    @discardableResult
    func feed(_ itemID: String) -> ActionResult {
        guard let item = ItemCatalog.food(itemID) else { return .unknownItem }
        let now = clock()
        simulate(now)
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
        record(.fed)
        save()
        return .ok
    }

    @discardableResult
    func pet(_ kind: PetKind = .tap) -> ActionResult {
        let now = clock()
        simulate(now)
        guard !state.cat.isSleeping else { return .sleeping }
        guard state.petLog.consume(at: now, cooldown: balance.petCooldownSeconds,
                                   maxPerHour: balance.maxRewardedPetsPerHour) else { return .noReward }
        state.cat.stats[.happiness] += kind == .stroke ? balance.petHappiness : balance.tapHappiness
        grantXP(balance.petXP)
        if tutorialStep == .pet { tutorialStep = .done }
        record(.petted)
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
        record(.bathed)
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
        record(.brushed)
        save()
        return .ok
    }

    /// Works while the cat sleeps: you clean the box, not the cat.
    @discardableResult
    func cleanLitter() -> ActionResult {
        simulate(clock())
        guard state.care.litter >= 1 else { return .noReward }
        let wasDirty = state.care.litter >= balance.litterDirtyThreshold
        state.care.litter = 0
        if wasDirty { state.cat.stats[.happiness] += balance.litterCleanHappiness }
        grantXP(wasDirty ? balance.litterCleanXP : 1)
        record(.litterCleaned)
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

    /// When the next bath / vet visit is allowed, or nil if it is allowed now.
    var bathReadyAt: Date? { readyAt(state.care.lastBathAt, hours: balance.bathCooldownHours) }
    var vetReadyAt: Date? { readyAt(state.care.lastVetAt, hours: balance.vetCooldownHours) }

    private func readyAt(_ last: Date?, hours: Double) -> Date? {
        guard let last, last <= clock() else { return nil }
        let ready = last.addingTimeInterval(hours * 3600)
        return ready > clock() ? ready : nil
    }

    // MARK: Water, nails, scratching

    var isWaterLow: Bool { state.care.water < balance.waterLowThreshold }

    @discardableResult
    func changeWater() -> ActionResult {
        simulate(clock())
        guard state.care.water < balance.waterFreshThreshold else { return .noReward }
        state.care.water = 100
        state.cat.stats[.happiness] += balance.waterRefreshHappiness
        grantXP(balance.waterXP)
        record(.waterChanged)
        save()
        return .ok
    }

    /// 0 = freshly trimmed, 1 = fully grown.
    var nailGrowth: Double {
        let since = state.care.lastNailTrimAt ?? state.cat.adoptedAt
        let days = max(0, clock().timeIntervalSince(since)) / 86400
        return min(1, days / balance.nailGrowthDays)
    }

    var canTrimNails: Bool { nailGrowth >= balance.nailTrimMinimumGrowth }

    @discardableResult
    func trimNails() -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        guard canTrimNails else { return .noReward }
        state.care.lastNailTrimAt = now
        state.cat.stats[.cleanliness] += balance.nailTrimCleanliness
        state.cat.stats[.health] += balance.nailTrimHealth
        grantXP(balance.nailTrimXP)
        record(.nailsTrimmed)
        save()
        return .ok
    }

    /// The cat used the scratching post on its own. Rewarded at most every `scratchCooldownMinutes`.
    @discardableResult
    func scratchPost() -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        guard !isOnCooldown(state.care.lastScratchAt, hours: balance.scratchCooldownMinutes / 60, now: now) else { return .noReward }
        state.care.lastScratchAt = now
        state.cat.stats[.happiness] += balance.scratchHappiness
        grantXP(1)
        save()
        return .ok
    }

    // MARK: Friends

    struct FriendCat: Equatable {
        let name: String
        let look: CatLook
    }

    var friendReadyAt: Date? { readyAt(state.care.lastFriendVisitAt, hours: balance.friendVisitCooldownHours) }

    /// A neighbour cat drops by. Returns the result and, on success, who came.
    func inviteFriend(seed: UInt64? = nil) -> (ActionResult, FriendCat?) {
        let now = clock()
        if let result = careGuard(now) { return (result, nil) }
        guard !isOnCooldown(state.care.lastFriendVisitAt, hours: balance.friendVisitCooldownHours, now: now) else { return (.tooSoon, nil) }
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        let names = ["Luna", "Kiki", "Tofu", "Mango", "Sushi", "Pudding", "Miso", "Nori"]
        func pick<T>(_ items: [T]) -> T { items[Int(rng.next() % UInt64(items.count))] }
        var look = CatLook(coat: pick(CatCoat.allCases).rawValue, ears: pick(EarStyle.allCases).rawValue,
                           tail: pick(TailLength.allCases).rawValue)
        if look.coat == state.cat.look.coat { look.coat = (look.coatValue == .smoke ? CatCoat.cream : .smoke).rawValue }
        state.care.lastFriendVisitAt = now
        state.cat.stats[.happiness] += balance.friendVisitHappiness
        grantXP(balance.friendVisitXP)
        record(.friendVisited)
        busyUntil = now.addingTimeInterval(14)
        save()
        return (.ok, FriendCat(name: pick(names), look: look))
    }

    // MARK: TV

    var hasTV: Bool { !state.decor.equipped(.tv).isEmpty }
    var tvReadyAt: Date? { readyAt(state.care.lastTVAt, hours: balance.tvCooldownHours) }

    @discardableResult
    func watchTV() -> ActionResult {
        let now = clock()
        guard hasTV else { return .unknownItem }
        if let result = careGuard(now) { return result }
        guard !isOnCooldown(state.care.lastTVAt, hours: balance.tvCooldownHours, now: now) else { return .tooSoon }
        state.care.lastTVAt = now
        state.cat.stats[.happiness] += balance.tvHappiness
        state.cat.stats[.energy] += balance.tvEnergy
        grantXP(balance.tvXP)
        record(.watchedTV)
        busyUntil = now.addingTimeInterval(14)
        save()
        return .ok
    }

    var isLitterDirty: Bool { state.care.litter >= balance.litterDirtyThreshold }

    /// Shared preconditions for actions that involve the cat.
    private func careGuard(_ now: Date) -> ActionResult? {
        simulate(now)
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
        simulate(now)
        guard now >= busyUntil else { return .busy }
        guard state.cat.isSleeping != sleeping else { return .ok }
        state.cat.isSleeping = sleeping
        save()
        return .ok
    }

    // MARK: Onboarding

    var needsOnboarding: Bool { state.onboardedAt == nil }

    func completeOnboarding(name: String, look: CatLook = CatLook()) {
        state.cat.name = CatState.sanitizedName(name, maxLength: balance.maxNameLength) ?? state.cat.name
        state.cat.look = CatLook(coat: look.coat, ears: look.ears, tail: look.tail).sanitized
        state.onboardedAt = clock()
        tutorialStep = .feed
        save()
    }

    // MARK: Shop

    /// Atomic purchase: validates first, then changes coins and inventory together.
    @discardableResult
    func buy(_ itemID: String, quantity: Int = 1) -> ActionResult {
        guard quantity > 0, let item = ItemCatalog.food(itemID) else { return .unknownItem }
        let cost = item.price * quantity
        guard state.coins >= cost else { return .insufficientCoins }
        state.coins -= cost
        state.inventory[itemID, default: 0] += quantity
        save()
        return .ok
    }

    // MARK: Settings

    func updateSettings(_ settings: GameSettings) {
        state.settings = settings
        state.settings.sfxVolume = min(1, max(0, settings.sfxVolume))
        state.settings.musicVolume = min(1, max(0, settings.musicVolume))
        if MusicTrack(rawValue: settings.musicTrack) == nil { state.settings.musicTrack = MusicTrack.calm.rawValue }
        AudioManager.shared.apply(state.settings)
        save()
    }

    // MARK: Decoration

    /// Buys a decoration and puts it in its slot. Unique items can't be bought twice.
    @discardableResult
    func buyDecor(_ id: String) -> ActionResult {
        guard let item = DecorCatalog.item(id) else { return .unknownItem }
        guard !state.decor.isOwned(item) else { return .alreadyOwned }
        guard state.progression.level >= item.unlockLevel else { return .locked }
        guard state.coins >= item.price else { return .insufficientCoins }
        state.coins -= item.price
        state.decor.owned.insert(id)
        state.decor.equipped[item.slot.rawValue] = id
        save()
        return .ok
    }

    @discardableResult
    func equipDecor(_ id: String) -> ActionResult {
        guard let item = DecorCatalog.item(id) else { return .unknownItem }
        guard state.decor.isOwned(item) else { return .noReward }
        state.decor.equipped[item.slot.rawValue] = id
        save()
        return .ok
    }

    /// Coat, ears and tail are free to change any time. Unknown values fall back to defaults.
    func setLook(_ look: CatLook) {
        var clean = look.sanitized
        if let head = clean.head, !state.wardrobe.contains(head) { clean.head = nil }
        if let neck = clean.neck, !state.wardrobe.contains(neck) { clean.neck = nil }
        state.cat.look = clean
        save()
    }

    /// Buys an accessory and puts it on. Each accessory is bought once.
    @discardableResult
    func buyAccessory(_ item: Accessory) -> ActionResult {
        guard !state.wardrobe.contains(item.rawValue) else { return .alreadyOwned }
        guard state.progression.level >= item.unlockLevel else { return .locked }
        guard state.coins >= item.price else { return .insufficientCoins }
        state.coins -= item.price
        state.wardrobe.insert(item.rawValue)
        wear(item)
        return .ok
    }

    /// Puts an owned accessory on, or takes it off if it is already worn.
    func wear(_ item: Accessory) {
        guard state.wardrobe.contains(item.rawValue) else { return }
        var look = state.cat.look
        switch item.slot {
        case .head: look.head = look.head == item.rawValue ? nil : item.rawValue
        case .neck: look.neck = look.neck == item.rawValue ? nil : item.rawValue
        }
        setLook(look)
    }

    // MARK: Mini-games

    func canStart(_ kind: MiniGameKind) -> Bool {
        !state.cat.isSleeping && state.cat.stats.energy >= kind.config(balance).minimumEnergy
    }

    /// Pays the energy cost up front, so quitting and restarting can't farm rewards.
    @discardableResult
    func startMiniGame(_ kind: MiniGameKind) -> ActionResult {
        let now = clock()
        if let result = careGuard(now) { return result }
        let config = kind.config(balance)
        guard state.cat.stats.energy >= config.minimumEnergy else { return .tooTired }
        state.cat.stats[.energy] -= config.energyCost
        activeGame = (kind, now)
        save()
        return .ok
    }

    /// Ends the running round and pays out. Returns nil if no round was started.
    @discardableResult
    func finishMiniGame(points: Int) -> MiniGameReward? {
        guard let game = activeGame else { return nil }
        activeGame = nil
        let now = clock()
        simulate(now)
        let config = game.kind.config(balance)
        let elapsed = max(0, now.timeIntervalSince(game.startedAt))
        let plausible = Int(elapsed / config.minSecondsPerPoint)
        let rewarded = max(0, min(points, config.maxRewardedPoints, plausible))
        let reward = MiniGameReward(points: max(0, points), coins: rewarded * config.coinsPerPoint, xp: rewarded * config.xpPerPoint)
        state.cat.stats[.happiness] += config.happiness
        state.coins += reward.coins
        grantXP(reward.xp)
        record(.played)
        save()
        return reward
    }

    func cancelMiniGame() { activeGame = nil }

    // MARK: Garden walk

    @discardableResult
    func startWalk(_ location: WalkLocation = .garden, seed: UInt64? = nil) -> ActionResult {
        let now = clock()
        guard isUnlocked(location) else { return .locked }
        if let result = careGuard(now) { return result }
        guard state.cat.stats.energy >= balance.walkMinimumEnergy else { return .tooTired }
        state.cat.stats[.energy] -= balance.walkEnergyCost
        activeWalk = .generate(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970 * 1000)), balance: balance,
                               location: location)
        save()
        return .ok
    }

    func isUnlocked(_ location: WalkLocation) -> Bool {
        state.progression.level >= (balance.walkLocations[location]?.unlockLevel ?? 1)
    }

    /// Pays out one find. Returns nil for an invalid index or a find that was already collected.
    @discardableResult
    func collectFind(_ index: Int) -> FindReward? {
        guard var walk = activeWalk, walk.finds.indices.contains(index), !walk.finds[index].collected else { return nil }
        walk.finds[index].collected = true
        let reward = walk.finds[index].reward
        switch reward {
        case .coins(let amount):
            state.coins += amount
            walk.coinsFound += amount
        case .item(let id):
            state.inventory[id, default: 0] += 1
            walk.itemsFound += 1
        }
        activeWalk = walk
        save()
        return reward
    }

    /// Ends the walk: a happier cat and a little XP. Returns the summary, or nil if no walk was running.
    @discardableResult
    func finishWalk() -> WalkSession? {
        guard let walk = activeWalk else { return nil }
        activeWalk = nil
        simulate(clock())
        state.cat.stats[.happiness] += balance.walkHappiness
        grantXP(balance.walkXP)
        record(.walked)
        save()
        return walk
    }

    // MARK: Daily check-in

    var canClaimLogin: Bool { state.login.days > 0 && state.login.claimedDayKey != state.login.dayKey }
    /// 0...6 position of today in the 7-day reward cycle.
    var loginCycleIndex: Int { max(0, state.login.days - 1) % balance.loginRewards.count }

    @discardableResult
    func claimLogin() -> LoginReward? {
        simulate(clock())
        guard canClaimLogin else { return nil }
        let reward = balance.loginRewards[loginCycleIndex]
        state.login.claimedDayKey = state.login.dayKey
        state.coins += reward.coins
        if let item = reward.item { state.inventory[item, default: 0] += reward.itemCount }
        save()
        return reward
    }

    // MARK: Daily tasks

    func definition(for task: DailyTaskProgress) -> DailyTaskDefinition? { DailyTasks.definition(task.id) }

    @discardableResult
    func claimTask(_ id: String) -> ActionResult {
        simulate(clock())
        guard let index = state.daily.tasks.firstIndex(where: { $0.id == id }),
              let definition = DailyTasks.definition(id) else { return .unknownItem }
        let task = state.daily.tasks[index]
        guard !task.claimed, task.progress >= definition.target else { return .noReward }
        state.daily.tasks[index].claimed = true
        state.coins += definition.coins
        grantXP(definition.xp)
        save()
        return .ok
    }

    @discardableResult
    func claimDailyBonus() -> ActionResult {
        simulate(clock())
        guard state.daily.allClaimed, !state.daily.bonusClaimed else { return .noReward }
        state.daily.bonusClaimed = true
        state.coins += balance.allTasksBonusCoins
        save()
        return .ok
    }

    private func record(_ event: TaskEvent) {
        state.lifetime[event.rawValue, default: 0] += 1
        for i in state.daily.tasks.indices {
            guard let definition = DailyTasks.definition(state.daily.tasks[i].id),
                  definition.event == event, !state.daily.tasks[i].claimed else { continue }
            state.daily.tasks[i].progress = min(definition.target, state.daily.tasks[i].progress + 1)
        }
    }

    // MARK: Tips

    func hasSeenTip(_ id: String) -> Bool { state.seenTips.contains(id) }

    func markTipSeen(_ id: String) {
        guard state.seenTips.insert(id).inserted else { return }
        save()
    }

    // MARK: Collection

    func recordPhoto() {
        state.lifetime["photos", default: 0] += 1
        save()
    }

    func progress(of badge: Badge) -> Int {
        switch badge.metric {
        case .event(let event): state.lifetime[event.rawValue] ?? 0
        case .photos: state.lifetime["photos"] ?? 0
        case .level: state.progression.level
        case .checkInDays: state.login.days
        case .decorOwned: state.decor.owned.count
        case .accessoriesOwned: state.wardrobe.count
        }
    }

    /// Unlocks every badge whose target is reached and pays its coins once.
    private func unlockBadges() {
        for badge in Badge.all where state.badges[badge.id] == nil && progress(of: badge) >= badge.target {
            state.badges[badge.id] = clock()
            state.coins += badge.coins
            lastUnlockedBadge = badge
        }
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

    #if DEBUG
    /// QA helper (`-refillStats`): full needs and an awake cat.
    /// QA helper (`-debugDecor id,id`): owns and equips the given decorations.
    func debugEquip(_ ids: [String]) {
        for id in ids where DecorCatalog.item(id) != nil {
            state.decor.owned.insert(id)
            state.decor.equipped[DecorCatalog.item(id)!.slot.rawValue] = id
        }
        save()
    }

    /// QA helper (`-debugWear bow,collar`): owns and wears accessories.
    func debugWear(_ ids: [String]) {
        for item in ids.compactMap(Accessory.init(rawValue:)) {
            state.wardrobe.insert(item.rawValue)
            if item.slot == .head ? state.cat.look.head != item.rawValue : state.cat.look.neck != item.rawValue { wear(item) }
        }
    }

    func debugRefill() {
        state.cat.stats = CatStats(hunger: 100, energy: 100, happiness: 100, cleanliness: 100, health: 100)
        state.cat.isSleeping = false
        save()
    }
    #endif

    // MARK: Persistence

    func save() {
        unlockBadges()
        if state.cat.stats.happiness >= balance.happinessTaskThreshold,
           state.daily.tasks.contains(where: { DailyTasks.definition($0.id)?.event == .reachedHappiness && $0.progress == 0 }) {
            record(.reachedHappiness)
        }
        do {
            try saveStore.save(state)
        } catch {
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
