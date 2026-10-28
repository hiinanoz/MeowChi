import SwiftUI

/// Things the player does that can advance a daily task.
enum TaskEvent: String, Codable {
    case fed, petted, played, litterCleaned, brushed, bathed, reachedHappiness, walked, waterChanged, nailsTrimmed, friendVisited, watchedTV
}

struct DailyTaskDefinition: Identifiable, Equatable {
    let id: String
    let event: TaskEvent
    let target: Int
    let coins: Int
    let xp: Int

    var titleKey: LocalizedStringKey { LocalizedStringKey(id) }
}

struct DailyTaskProgress: Codable, Equatable, Identifiable {
    let id: String
    var progress = 0
    var claimed = false
}

/// Today's tasks. `dayKey` is the local calendar day (yyyy-MM-dd) they belong to.
struct DailyTasks: Codable, Equatable {
    var dayKey = ""
    var tasks: [DailyTaskProgress] = []
    var bonusClaimed = false

    static let pool: [DailyTaskDefinition] = [
        DailyTaskDefinition(id: "task.feed2", event: .fed, target: 2, coins: 15, xp: 5),
        DailyTaskDefinition(id: "task.pet3", event: .petted, target: 3, coins: 10, xp: 3),
        DailyTaskDefinition(id: "task.play1", event: .played, target: 1, coins: 20, xp: 5),
        DailyTaskDefinition(id: "task.litter1", event: .litterCleaned, target: 1, coins: 15, xp: 4),
        DailyTaskDefinition(id: "task.brush3", event: .brushed, target: 3, coins: 15, xp: 4),
        DailyTaskDefinition(id: "task.bath1", event: .bathed, target: 1, coins: 15, xp: 4),
        DailyTaskDefinition(id: "task.happy80", event: .reachedHappiness, target: 1, coins: 20, xp: 5),
        DailyTaskDefinition(id: "task.walk1", event: .walked, target: 1, coins: 20, xp: 5),
        DailyTaskDefinition(id: "task.water1", event: .waterChanged, target: 1, coins: 10, xp: 3),
    ]

    static func definition(_ id: String) -> DailyTaskDefinition? { pool.first { $0.id == id } }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Same day → same tasks on every device and relaunch (no randomness that depends on the process).
    static func generate(dayKey: String, count: Int) -> DailyTasks {
        var seed = dayKey.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        var ids = pool.map(\.id)
        for i in stride(from: ids.count - 1, to: 0, by: -1) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            ids.swapAt(i, Int((seed >> 33) % UInt64(i + 1)))
        }
        return DailyTasks(dayKey: dayKey, tasks: ids.prefix(count).map { DailyTaskProgress(id: $0) })
    }

    var allClaimed: Bool { !tasks.isEmpty && tasks.allSatisfy(\.claimed) }
}
