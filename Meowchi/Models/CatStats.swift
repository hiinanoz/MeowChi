import SwiftUI

struct CatStats: Codable, Equatable {
    var hunger: Double
    var energy: Double
    var happiness: Double
    var cleanliness: Double
    var health: Double

    static let range = 0.0...100.0

    subscript(kind: StatKind) -> Double {
        get {
            switch kind {
            case .hunger: hunger
            case .energy: energy
            case .happiness: happiness
            case .cleanliness: cleanliness
            case .health: health
            }
        }
        set {
            let value = newValue.isFinite ? min(max(newValue, Self.range.lowerBound), Self.range.upperBound) : 50
            switch kind {
            case .hunger: hunger = value
            case .energy: energy = value
            case .happiness: happiness = value
            case .cleanliness: cleanliness = value
            case .health: health = value
            }
        }
    }

    /// Clamps every stat into 0...100 and repairs non-finite values.
    mutating func clamp() {
        for kind in StatKind.allCases { self[kind] = self[kind] }
    }
}

enum StatKind: String, CaseIterable, Identifiable {
    case hunger, energy, happiness, cleanliness, health

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("stat." + rawValue) }
    var iconName: String { "icon_\(rawValue)" }
}
