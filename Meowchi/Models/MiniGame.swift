import SwiftUI

/// Mini-game catalogue. Each game is a SpriteKit scene that reports a score; rules and rewards live here.
enum MiniGameKind: String, CaseIterable, Identifiable {
    case laserChase
    // Next: yarnBall, toyMouse (Phase 5).

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("game." + rawValue + ".title") }
    var hintKey: LocalizedStringKey { LocalizedStringKey("game." + rawValue + ".hint") }

    func config(_ balance: Balance) -> MiniGameConfig {
        switch self {
        case .laserChase: balance.laserChase
        }
    }
}

struct MiniGameConfig {
    var durationSeconds: Double
    var energyCost: Double
    var minimumEnergy: Double
    var happiness: Double
    var coinsPerPoint: Int
    var xpPerPoint: Int
    /// Points above this still count for fun but give no extra reward.
    var maxRewardedPoints: Int
    /// Plausibility limit: at most one point per this many seconds of play.
    var minSecondsPerPoint: Double
}

struct MiniGameReward: Equatable {
    var points: Int
    var coins: Int
    var xp: Int
}
