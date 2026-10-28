import SwiftUI

/// Places to walk. Each unlocks at a level and has its own finds.
enum WalkLocation: String, CaseIterable, Identifiable {
    case garden, park, beach, forest

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("walk." + rawValue) }
    var background: String { rawValue + "_background" }
}

/// Balancing for one walk location (lives in `Balance.walkLocations`).
struct WalkLocationConfig {
    var unlockLevel: Int
    var coinRange: ClosedRange<Int>
    var itemChance: Double
    var itemPool: [String]
}

enum FindReward: Equatable {
    case coins(Int)
    case item(String)
}

struct WalkFind: Equatable {
    /// Normalized position on the path: x 0...1 along the garden, y 0...1 across the path.
    var x: Double
    var y: Double
    var reward: FindReward
    var collected = false
}

/// One garden walk. Rewards are paid when a find is collected, so ending the walk early loses nothing.
struct WalkSession: Equatable {
    var finds: [WalkFind]
    var coinsFound = 0
    var itemsFound = 0

    var location = WalkLocation.garden

    static func generate(seed: UInt64, balance: Balance, location: WalkLocation = .garden) -> WalkSession {
        var rng = SplitMix64(seed: seed)
        let config = balance.walkLocations[location] ?? balance.walkLocations[.garden]!
        let count = balance.walkFindCount
        let finds = (0..<count).map { i -> WalkFind in
            // Spread finds evenly with some jitter so the whole garden is worth exploring.
            let slot = (Double(i) + 0.2 + rng.unit() * 0.6) / Double(count)
            let reward: FindReward = rng.unit() < config.itemChance
                ? .item(config.itemPool[Int(rng.next() % UInt64(config.itemPool.count))])
                : .coins(config.coinRange.lowerBound + Int(rng.next() % UInt64(config.coinRange.count)))
            return WalkFind(x: 0.06 + slot * 0.88, y: 0.15 + rng.unit() * 0.7, reward: reward)
        }
        return WalkSession(finds: finds, location: location)
    }
}

/// Small deterministic RNG so walks are reproducible in tests.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
