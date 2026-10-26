import Foundation

/// Pure, deterministic need simulation. No timers: elapsed time is applied on demand.
enum CatSimulator {
    /// Advances the state from `state.lastSimulatedAt` to `now`.
    /// - Clock moved backwards: no stat change, the reference point is reset.
    /// - Long absence: capped at `balance.maxSimulatedHours`.
    static func advance(_ state: inout GameState, to now: Date, balance: Balance) {
        let elapsed = now.timeIntervalSince(state.lastSimulatedAt)
        guard elapsed.isFinite, elapsed > 0 else {
            state.lastSimulatedAt = now
            return
        }
        var remaining = min(elapsed, balance.maxSimulatedHours * 3600)
        while remaining > 0 {
            let step = min(remaining, balance.simulationStepSeconds)
            applyStep(&state.cat, care: &state.care, hours: step / 3600, balance: balance)
            remaining -= step
        }
        state.lastSimulatedAt = now
    }

    static func applyStep(_ cat: inout CatState, care: inout CareState, hours h: Double, balance b: Balance) {
        var s = cat.stats
        let floor = b.decayFloor
        care.litter = min(100, care.litter + b.litterFillPerHour * h)
        let litterPenalty = care.litter >= b.litterDirtyThreshold ? b.dirtyLitterCleanlinessPenaltyPerHour : 0
        if cat.isSleeping {
            s.energy += b.energyRestorePerHourSleeping * h
            s.hunger = decay(s.hunger, by: b.hungerDecayPerHourSleeping * h, floor: floor)
        } else {
            s.energy = decay(s.energy, by: b.energyDecayPerHour * h, floor: floor)
            s.hunger = decay(s.hunger, by: b.hungerDecayPerHour * h, floor: floor)
        }
        s.cleanliness = decay(s.cleanliness, by: (b.cleanlinessDecayPerHour + litterPenalty) * h, floor: floor)

        let neglected = min(s.hunger, s.cleanliness, s.energy) < b.neglectThreshold
        let happinessLoss = b.happinessDecayPerHour + (neglected ? b.happinessNeglectPenaltyPerHour : 0)
        s.happiness = decay(s.happiness, by: happinessLoss * h, floor: floor)

        if min(s.hunger, s.cleanliness) < b.healthRiskThreshold {
            s.health = decay(s.health, by: b.healthDecayPerHour * h, floor: b.healthFloor)
        } else {
            s.health += b.healthRecoveryPerHour * h
        }
        s.clamp()
        if cat.isSleeping && s.energy >= b.autoWakeEnergy {
            cat.isSleeping = false
        }
        cat.stats = s
    }

    /// Lowers a value but never below `floor` (and never raises a value already under it).
    static func decay(_ value: Double, by amount: Double, floor: Double) -> Double {
        value <= floor ? value : max(floor, value - amount)
    }

    static func mood(for cat: CatState) -> Mood {
        let s = cat.stats
        if cat.isSleeping || s.energy < 20 { return .sleepy }
        if s.hunger < 30 { return .hungry }
        if s.happiness < 30 { return .sad }
        if s.happiness < 50 { return .bored }
        if s.happiness >= 90 && s.energy >= 60 { return .excited }
        if (s.hunger + s.happiness + s.cleanliness + s.energy) / 4 >= 65 { return .happy }
        return .neutral
    }
}
