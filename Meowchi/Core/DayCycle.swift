import Foundation

/// Maps the player's local time to room lighting. Uses the device's current time zone.
enum DayCycle {
    enum Phase: Equatable {
        case day, evening, night, dawn
    }

    static func phase(at date: Date, calendar: Calendar = .current) -> Phase {
        switch calendar.component(.hour, from: date) {
        case 6: .dawn
        case 7..<19: .day
        case 19..<22: .evening
        default: .night
        }
    }

    /// Opacity of the dark overlay (0 = full daylight).
    static func darkness(for phase: Phase) -> Double {
        switch phase {
        case .day: 0
        case .dawn, .evening: 0.15
        case .night: 0.3
        }
    }

    static let sleepingDarkness = 0.4
}
