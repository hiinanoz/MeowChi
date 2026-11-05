import UIKit

/// Data the app shares with the home-screen widget through the App Group container.
/// The app pre-computes an hourly forecast with the real simulation, so the widget needs no game logic.
/// This file is compiled into both the app and the widget extension.
struct WidgetSnapshot: Codable, Equatable {
    struct Point: Codable, Equatable {
        var date: Date
        var hunger: Double
        var energy: Double
        var happiness: Double
        var cleanliness: Double
        var health: Double
        var sleeping: Bool

        /// The need that most wants attention (lowest of the four basics).
        var lowestNeed: String {
            [("hunger", hunger), ("energy", energy), ("happiness", happiness), ("cleanliness", cleanliness)]
                .min { $0.1 < $1.1 }?.0 ?? "hunger"
        }
    }

    var name: String
    var points: [Point]

    static let appGroup = "group.com.othinks.Meowchi"
    private static let dataFile = "widget-snapshot.json"
    private static let imageFile = "widget-cat.png"

    /// nil when the App Group isn't available (e.g. an unsigned simulator build).
    static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) }

    static func load() -> (snapshot: WidgetSnapshot, image: UIImage?)? {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent(dataFile)),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return nil }
        return (snapshot, UIImage(contentsOfFile: folder.appendingPathComponent(imageFile).path))
    }

    @discardableResult
    func write(image: UIImage?) -> Bool {
        guard let folder = Self.folder, let data = try? JSONEncoder().encode(self) else { return false }
        do {
            try data.write(to: folder.appendingPathComponent(Self.dataFile), options: .atomic)
            if let png = image?.pngData() { try png.write(to: folder.appendingPathComponent(Self.imageFile), options: .atomic) }
            return true
        } catch {
            return false
        }
    }

    /// The forecast point closest to (but not after) `date`, or the first one.
    func point(at date: Date) -> Point? {
        points.last { $0.date <= date } ?? points.first
    }
}

/// Taps made on the widget's "Pet" button, waiting for the app to apply them through `GameStore`.
/// The widget only records the tap (it has no game logic); the app turns it into a real, rewarded pet.
struct WidgetActions: Codable, Equatable {
    var pendingPets = 0
    var lastPetAt: Date?

    private static let file = "widget-actions.json"

    static func load() -> WidgetActions {
        guard let folder = WidgetSnapshot.folder,
              let data = try? Data(contentsOf: folder.appendingPathComponent(file)),
              let actions = try? JSONDecoder().decode(WidgetActions.self, from: data) else { return WidgetActions() }
        return actions
    }

    func save() {
        guard let folder = WidgetSnapshot.folder, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: folder.appendingPathComponent(Self.file), options: .atomic)
    }

    /// Called by the widget's intent.
    static func recordPet(at date: Date = .now) {
        var actions = load()
        actions.pendingPets += 1
        actions.lastPetAt = date
        actions.save()
    }

    /// Called by the app: returns the pending pets and clears them (keeps `lastPetAt` for the widget's heart).
    static func takePendingPets() -> Int {
        var actions = load()
        let count = actions.pendingPets
        guard count > 0 else { return 0 }
        actions.pendingPets = 0
        actions.save()
        return count
    }
}
