import SwiftUI

/// The complete persisted game state. Plain value type so it is trivially testable.
///
/// Versioning rule: a new field gets a default in `init(from:)` (decodeIfPresent), so older saves
/// keep loading. Bump `GameState.schemaVersion` only for breaking changes.
struct GameState: Codable, Equatable {
    static let schemaVersion = 1

    var cat: CatState
    var progression: Progression
    var coins: Int
    var inventory: [String: Int]
    var lastSimulatedAt: Date
    var petLog: RewardLog
    var settings: GameSettings
    /// nil until the player has named their kitten. Optional so older saves decode unchanged.
    var onboardedAt: Date?
    var care = CareState()
    var daily = DailyTasks()
    var decor = DecorState()

    static func newGame(now: Date, balance: Balance) -> GameState {
        GameState(
            cat: CatState(name: String(localized: "cat.defaultName"), stats: balance.startingStats, adoptedAt: now),
            progression: Progression(),
            coins: balance.startingCoins,
            inventory: balance.startingInventory,
            lastSimulatedAt: now,
            petLog: RewardLog(windowStart: now),
            settings: GameSettings()
        )
    }
}

struct CatState: Codable, Equatable {
    var name: String
    var look = CatLook()
    var personality = Personality.playful
    var stats: CatStats
    var isSleeping = false
    var adoptedAt: Date

    private enum CodingKeys: String, CodingKey { case name, look, personality, stats, isSleeping, adoptedAt }
    /// Pre-customization saves stored only a coat id.
    private enum LegacyKeys: String, CodingKey { case appearanceID }

    init(name: String, look: CatLook = CatLook(), personality: Personality = .playful, stats: CatStats,
         isSleeping: Bool = false, adoptedAt: Date) {
        self.name = name
        self.look = look
        self.personality = personality
        self.stats = stats
        self.isSleeping = isSleeping
        self.adoptedAt = adoptedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        personality = try c.decodeIfPresent(Personality.self, forKey: .personality) ?? .playful
        stats = try c.decode(CatStats.self, forKey: .stats)
        isSleeping = try c.decodeIfPresent(Bool.self, forKey: .isSleeping) ?? false
        adoptedAt = try c.decode(Date.self, forKey: .adoptedAt)
        if let look = try c.decodeIfPresent(CatLook.self, forKey: .look) {
            self.look = look
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let coat = try legacy.decodeIfPresent(String.self, forKey: .appearanceID)
            self.look = CatLook(coat: ["gray_white": "silver", "cream": "cream"][coat ?? ""] ?? CatCoat.ginger.rawValue)
        }
    }

    /// Trims whitespace, limits length; returns nil if nothing usable is left.
    static func sanitizedName(_ raw: String, maxLength: Int) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxLength))
    }
}

enum PetKind {
    case tap, stroke
}

/// In-room tutorial hints shown right after onboarding. Not persisted: they are optional help.
enum TutorialStep {
    case feed, pet, done
}

enum Personality: String, Codable, CaseIterable {
    case playful, lazy, curious, affectionate, adventurous, calm
}

struct Progression: Codable, Equatable {
    var level = 1
    var xp = 0
}

extension GameState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cat = try c.decode(CatState.self, forKey: .cat)
        progression = try c.decode(Progression.self, forKey: .progression)
        coins = try c.decode(Int.self, forKey: .coins)
        inventory = try c.decode([String: Int].self, forKey: .inventory)
        lastSimulatedAt = try c.decode(Date.self, forKey: .lastSimulatedAt)
        petLog = try c.decode(RewardLog.self, forKey: .petLog)
        settings = try c.decode(GameSettings.self, forKey: .settings)
        // Added after schema v1 shipped internally: default when missing.
        onboardedAt = try c.decodeIfPresent(Date.self, forKey: .onboardedAt)
        care = try c.decodeIfPresent(CareState.self, forKey: .care) ?? CareState()
        daily = try c.decodeIfPresent(DailyTasks.self, forKey: .daily) ?? DailyTasks()
        decor = try c.decodeIfPresent(DecorState.self, forKey: .decor) ?? DecorState()
    }
}

/// Cleaning and vet bookkeeping.
struct CareState: Codable, Equatable {
    /// 0 = fresh, 100 = full. Fills over time; above the dirty threshold it lowers cleanliness.
    var litter = 0.0
    /// 100 = fresh water. Drains over time; low water makes the cat less happy.
    var water = 100.0
    var lastBathAt: Date?
    var lastVetAt: Date?
    var lastNailTrimAt: Date?
    var lastScratchAt: Date?
    var lastFriendVisitAt: Date?
    var lastTVAt: Date?
    var brushLog = RewardLog(windowStart: .distantPast)

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        litter = try c.decodeIfPresent(Double.self, forKey: .litter) ?? 0
        water = try c.decodeIfPresent(Double.self, forKey: .water) ?? 100
        lastBathAt = try c.decodeIfPresent(Date.self, forKey: .lastBathAt)
        lastVetAt = try c.decodeIfPresent(Date.self, forKey: .lastVetAt)
        lastNailTrimAt = try c.decodeIfPresent(Date.self, forKey: .lastNailTrimAt)
        lastScratchAt = try c.decodeIfPresent(Date.self, forKey: .lastScratchAt)
        lastFriendVisitAt = try c.decodeIfPresent(Date.self, forKey: .lastFriendVisitAt)
        lastTVAt = try c.decodeIfPresent(Date.self, forKey: .lastTVAt)
        brushLog = try c.decodeIfPresent(RewardLog.self, forKey: .brushLog) ?? RewardLog(windowStart: .distantPast)
    }
}

/// Rate-limits a repeatable reward (petting, brushing) to stop farming.
struct RewardLog: Codable, Equatable {
    var windowStart: Date
    var rewardedCount = 0
    var lastAt: Date?

    private enum CodingKeys: String, CodingKey {
        case windowStart, rewardedCount
        case lastAt = "lastPetAt" // original key from schema v1
    }

    /// Records an attempt; true if it earns a reward (cooldown passed and hourly cap not reached).
    /// Clock changes backwards reset the window instead of blocking rewards.
    mutating func consume(at now: Date, cooldown: TimeInterval, maxPerHour: Int) -> Bool {
        if now.timeIntervalSince(windowStart) >= 3600 || now < windowStart {
            windowStart = now
            rewardedCount = 0
        }
        let cooledDown = lastAt.map { now.timeIntervalSince($0) >= cooldown || now < $0 } ?? true
        lastAt = now
        guard cooledDown, rewardedCount < maxPerHour else { return false }
        rewardedCount += 1
        return true
    }
}

struct GameSettings: Codable, Equatable {
    var soundEnabled = true
    var musicEnabled = true
    var sfxVolume = 0.8
    var musicVolume = 0.5
    var musicTrack = MusicTrack.calm.rawValue

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        musicEnabled = try c.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? true
        sfxVolume = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .sfxVolume) ?? 0.8))
        musicVolume = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .musicVolume) ?? 0.5))
        musicTrack = try c.decodeIfPresent(String.self, forKey: .musicTrack) ?? MusicTrack.calm.rawValue
    }
}

enum MusicTrack: String, CaseIterable, Identifiable {
    case calm, upbeat, retro8, retro16

    var id: String { rawValue }
    var fileName: String { "music_" + rawValue }
    var nameKey: LocalizedStringKey { LocalizedStringKey("music." + rawValue) }
}

enum Mood: String, CaseIterable {
    case happy, neutral, sleepy, hungry, bored, sad, excited, sick

    var titleKey: LocalizedStringKey { LocalizedStringKey("mood." + rawValue) }
}
