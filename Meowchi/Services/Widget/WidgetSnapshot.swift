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

    static let appGroup = "group.com.meowchi.game"
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
