import Foundation

/// Every gameplay tuning value lives here. Do not hardcode balancing numbers elsewhere.
struct Balance {
    // MARK: Needs decay (points per real-time hour)
    var hungerDecayPerHour = 6.0
    var hungerDecayPerHourSleeping = 3.0
    var energyDecayPerHour = 5.0
    var energyRestorePerHourSleeping = 30.0
    var cleanlinessDecayPerHour = 3.0
    var happinessDecayPerHour = 2.0
    /// Extra happiness loss while any basic need is below `neglectThreshold`.
    var happinessNeglectPenaltyPerHour = 3.0
    var neglectThreshold = 30.0

    // Water bowl
    var waterDrainPerHour = 4.0
    var waterLowThreshold = 30.0
    var lowWaterHappinessPenaltyPerHour = 1.5
    var waterRefreshHappiness = 3.0
    var waterXP = 2
    /// Changing water that is still this fresh gives no reward.
    var waterFreshThreshold = 90.0
    // Nails
    var nailGrowthDays = 3.0
    /// Trimming is allowed (and rewarded) once nails have grown this much (0...1).
    var nailTrimMinimumGrowth = 0.34
    var nailTrimCleanliness = 5.0
    var nailTrimHealth = 4.0
    var nailTrimXP = 4
    // Scratching post
    var scratchHappiness = 3.0
    var scratchCooldownMinutes = 30.0
    var scratchChance = 0.08

    // MARK: Health
    var healthRecoveryPerHour = 1.0
    var healthDecayPerHour = 1.5
    /// Health drops only while hunger or cleanliness is below this value.
    var healthRiskThreshold = 25.0
    var healthFloor = 30.0

    // MARK: Fairness
    /// Time-based decay never pushes a need below this value. No permanent death, no punishment for absence.
    var decayFloor = 10.0
    /// Offline progression is capped at this many hours.
    var maxSimulatedHours = 24.0
    var simulationStepSeconds = 900.0
    var autoWakeEnergy = 100.0

    // MARK: Interactions
    /// Stroking is the "real" petting; a quick tap gives a smaller boost.
    var petHappiness = 5.0
    var tapHappiness = 2.0
    /// Drag distance (room pixels) over the cat that counts as one stroke.
    var strokeDistance = 80.0
    var maxNameLength = 16
    var petCooldownSeconds = 1.5
    var maxRewardedPetsPerHour = 12
    var petXP = 1
    /// Covers walking to the bowl plus eating; blocks overlapping actions.
    var feedDurationSeconds = 7.0

    // MARK: Cleaning
    var litterFillPerHour = 5.0
    var litterDirtyThreshold = 60.0
    var dirtyLitterCleanlinessPenaltyPerHour = 2.0
    var litterCleanHappiness = 3.0
    var litterCleanXP = 3
    var bathCleanliness = 45.0
    /// Cats aren't big fans of baths.
    var bathHappiness = -4.0
    var bathEnergy = -5.0
    var bathXP = 5
    var bathCooldownHours = 3.0
    /// A bath is pointless (no reward) above this cleanliness.
    var alreadyCleanThreshold = 95.0
    var brushCleanliness = 4.0
    var brushHappiness = 2.0
    var brushCooldownSeconds = 1.0
    var maxRewardedBrushesPerHour = 10
    var brushXP = 1
    var bathDurationSeconds = 6.0

    // MARK: Health
    var vetHealth = 35.0
    var vetHappiness = -2.0
    var vetXP = 2
    var vetCooldownHours = 6.0
    var alreadyHealthyThreshold = 95.0
    /// Below this health the cat is "unwell" (mood, alert bubble) until the vet or good care helps.
    var sickThreshold = 40.0
    /// Any need below this shows an attention bubble over the cat.
    var attentionThreshold = 25.0

    // MARK: Mini-games
    var laserChase = MiniGameConfig(durationSeconds: 45, energyCost: 10, minimumEnergy: 15, happiness: 12,
                                    coinsPerPoint: 2, xpPerPoint: 1, maxRewardedPoints: 30, minSecondsPerPoint: 0.5)

    // MARK: Garden walk
    var walkEnergyCost = 8.0
    var walkMinimumEnergy = 12.0
    var walkHappiness = 8.0
    var walkXP = 3
    var walkFindCount = 5
    var walkCoinRange = 3...8
    var walkItemChance = 0.2
    var walkItemPool = ["food.treat", "food.fish"]

    // MARK: Daily tasks
    var dailyTaskCount = 4
    var allTasksBonusCoins = 40
    var happinessTaskThreshold = 80.0

    // MARK: Progression & economy
    var baseXPPerLevel = 50
    var xpGrowthPerLevel = 25
    var levelUpCoins = 25
    var startingCoins = 100
    var startingInventory: [String: Int] = ["food.dry": 10, "food.wet": 3]
    var startingStats = CatStats(hunger: 70, energy: 80, happiness: 75, cleanliness: 80, health: 100)

    static let standard = Balance()

    func xpRequired(forLevel level: Int) -> Int {
        baseXPPerLevel + xpGrowthPerLevel * max(0, level - 1)
    }
}
