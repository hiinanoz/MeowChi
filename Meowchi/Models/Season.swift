import SwiftUI

/// Calendar seasons with limited shop items. Works offline from the device date.
enum Season: String, CaseIterable {
    case winter, spring, summer

    var nameKey: LocalizedStringKey { LocalizedStringKey("season." + rawValue) }

    /// Winter: Dec 15 – Jan 15, spring: Mar 15 – Apr 30, summer: Jul 1 – Aug 31; nil the rest of the year.
    static func current(at date: Date = .now, calendar: Calendar = .current) -> Season? {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        switch (month, day) {
        case (12, 15...), (1, ...15): return .winter
        case (3, 15...), (4, _): return .spring
        case (7, _), (8, _): return .summer
        default: return nil
        }
    }
}

extension DecorItem {
    /// Buyable right now: not seasonal, or its season is on.
    func isAvailable(at date: Date = .now) -> Bool { season == nil || season == Season.current(at: date) }
}
