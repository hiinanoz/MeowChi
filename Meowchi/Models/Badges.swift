import SwiftUI

/// Collectible achievements. Progress comes from lifetime counters, so they can't be lost.
struct Badge: Identifiable, Equatable {
    enum Metric: Equatable {
        case event(TaskEvent)
        case level, checkInDays, photos, decorOwned, accessoriesOwned
    }

    enum Tier { case bronze, silver, gold }

    let id: String
    let metric: Metric
    let target: Int
    let coins: Int
    let tier: Tier

    var nameKey: LocalizedStringKey { LocalizedStringKey("badge." + id) }
    var detailKey: LocalizedStringKey { LocalizedStringKey("badge." + id + ".detail") }
    var icon: String {
        switch tier {
        case .bronze: "icon_badge_bronze"
        case .silver: "icon_badge_silver"
        case .gold: "icon_badge_gold"
        }
    }

    static let all: [Badge] = [
        Badge(id: "firstMeal", metric: .event(.fed), target: 1, coins: 10, tier: .bronze),
        Badge(id: "gourmet", metric: .event(.fed), target: 50, coins: 50, tier: .silver),
        Badge(id: "cuddles", metric: .event(.petted), target: 25, coins: 20, tier: .bronze),
        Badge(id: "bestFriend", metric: .event(.petted), target: 200, coins: 80, tier: .gold),
        Badge(id: "squeaky", metric: .event(.bathed), target: 5, coins: 30, tier: .bronze),
        Badge(id: "explorer", metric: .event(.walked), target: 5, coins: 30, tier: .bronze),
        Badge(id: "traveler", metric: .event(.walked), target: 25, coins: 80, tier: .gold),
        Badge(id: "player", metric: .event(.played), target: 10, coins: 40, tier: .silver),
        Badge(id: "social", metric: .event(.friendVisited), target: 5, coins: 40, tier: .silver),
        Badge(id: "photographer", metric: .photos, target: 5, coins: 30, tier: .bronze),
        Badge(id: "loyal", metric: .checkInDays, target: 7, coins: 50, tier: .silver),
        Badge(id: "devoted", metric: .checkInDays, target: 30, coins: 150, tier: .gold),
        Badge(id: "level5", metric: .level, target: 5, coins: 50, tier: .silver),
        Badge(id: "level10", metric: .level, target: 10, coins: 100, tier: .gold),
        Badge(id: "decorator", metric: .decorOwned, target: 5, coins: 50, tier: .silver),
        Badge(id: "stylish", metric: .accessoriesOwned, target: 3, coins: 40, tier: .silver),
    ]
}

/// Saved photos of the room, stored as PNG files in Documents/Photos (not in the save file).
enum PhotoAlbum {
    static var folder: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Photos")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = folder.appendingPathComponent("meowchi-\(Int(Date().timeIntervalSince1970 * 1000)).png")
        return (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    static func all() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func delete(_ url: URL) { try? FileManager.default.removeItem(at: url) }
}
