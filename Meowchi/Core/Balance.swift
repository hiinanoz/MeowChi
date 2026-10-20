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
    var petHappiness = 4.0
    var petCooldownSeconds = 1.5
    var maxRewardedPetsPerHour = 12
    var petXP = 1
    /// Covers walking to the bowl plus eating; blocks overlapping actions.
    var feedDurationSeconds = 7.0

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
