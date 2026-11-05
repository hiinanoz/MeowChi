import Foundation

/// Life stage, derived from care days (`state.login.days`), so it is never saved and never goes back.
/// Days the player is away don't count, so a player taking a break finds the same cat.
enum CatStage: Int, Comparable, CaseIterable {
    case kitten, junior, adult

    init(careDays: Int, balance: Balance = .standard) {
        if careDays >= balance.adultCareDays {
            self = .adult
        } else if careDays >= balance.juniorCareDays {
            self = .junior
        } else {
            self = .kitten
        }
    }

    var nameKey: String { "stage." + String(describing: self) }

    static func < (lhs: CatStage, rhs: CatStage) -> Bool { lhs.rawValue < rhs.rawValue }
}
