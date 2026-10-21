import SwiftUI

/// The complete persisted game state. Plain value type so it is trivially testable.
///
/// Versioning rule: adding a field requires either an optional type or a default
/// handled in `SaveCodec.migrate`; bump `GameState.schemaVersion` for breaking changes.
struct GameState: Codable, Equatable {
    static let schemaVersion = 1

    var cat: CatState
    var progression: Progression
    var coins: Int
    var inventory: [String: Int]
    var lastSimulatedAt: Date
    var petLog: PetLog
    var settings: GameSettings
    /// nil until the player has named their kitten. Optional so older saves decode unchanged.
    var onboardedAt: Date?

    static func newGame(now: Date, balance: Balance) -> GameState {
        GameState(
            cat: CatState(name: String(localized: "cat.defaultName"), stats: balance.startingStats, adoptedAt: now),
            progression: Progression(),
            coins: balance.startingCoins,
            inventory: balance.startingInventory,
            lastSimulatedAt: now,
            petLog: PetLog(windowStart: now),
            settings: GameSettings()
        )
    }
}

struct CatState: Codable, Equatable {
    var name: String
    var appearanceID = "orange_white"
    var personality = Personality.playful
    var stats: CatStats
    var isSleeping = false
    var adoptedAt: Date

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

/// Tracks rewarded petting to limit reward farming.
struct PetLog: Codable, Equatable {
    var windowStart: Date
    var rewardedCount = 0
    var lastPetAt: Date?
}

struct GameSettings: Codable, Equatable {
    var soundEnabled = true
    var musicEnabled = true
}

enum Mood: String, CaseIterable {
    case happy, neutral, sleepy, hungry, bored, sad, excited

    var titleKey: LocalizedStringKey { LocalizedStringKey("mood." + rawValue) }
}
