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

    enum Weather: Equatable { case clear, rain, snow }

    /// Offline "weather" for the window: the same for a 4-hour block, wet about a third of the time,
    /// snow in December to February. Pure so it is testable and identical everywhere in the app.
    static func weather(at date: Date, calendar: Calendar = .current) -> Weather {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let block = calendar.component(.hour, from: date) / 4
        let year = calendar.component(.year, from: date)
        var seed = UInt64(year * 1000 + day * 6 + block) &* 0x9E37_79B9_7F4A_7C15
        seed ^= seed >> 29
        guard seed % 100 < 33 else { return .clear }
        return [12, 1, 2].contains(calendar.component(.month, from: date)) ? .snow : .rain
    }
}
